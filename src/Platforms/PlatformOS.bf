using System;
using System.Threading;
using System.Diagnostics;
using System.Collections;

using MQTTCommon;

using internal MQTTStatus;

namespace MQTTStatus;

enum EPlatformEvent
{
	case MonitorPower(bool on);
	case Login(StringView user);
	case Logout;
	case Locked;
	case Unlocked(StringView user);
	case PowerOn;
	case Shutdown;

	case AppFocus(StringView title);
	case Battery(float value);
}

enum EServiceOptions
{
	case None;
	case Install;
	case Uninstall;
}

abstract class PlatformOS
{
	const String DISCOVERY_TOPIC = "homeassistant/device/@{CLIENT_ID}/config";
	const String DISCOVERY_PAYLOAD =
"""
{
	"device": {
		"identifiers": "@{CLIENT_ID}",
		"name": "@{DEVICE_NAME}",
		"mf": "Fusion",
		"mdl": "custom"
	},
	"o": {
		"name": "@{DEVICE_NAME}"
	},
	"cmps": {
		@{COMPONENTS}
	}
}
""";

	static void FormatPayloadsString(String buffer, Config cfg, String componentsString)
	{
		(String find, StringView replace)[?] replace = .(
			("@{CLIENT_ID}", cfg.ClientId),
			("@{DEVICE_NAME}", cfg.DeviceName),
			("@{COMPONENTS}", componentsString)
		);

		for (let f in replace)
			if (!f.replace.IsNull)
			buffer.Replace(f.find, f.replace);
	}

	static void GenerateComponentsString(String buffer, Config cfg, Span<MQTTComponent> components)
	{
		String keyName = scope .();
		String topic = scope .();
		String uniqueId = scope .();

		System.IO.StringStream ss = scope .(buffer, .Reference);
		JSONWriter writer = scope .(ss);

		for (let comp in components)
		{
			let name = comp.Name;
			if (name.IsEmpty)
				continue;

			keyName..Set(name)..Replace(" ", "_");
			keyName[0] = keyName[0].ToLower;

			topic..Clear().AppendF($"{cfg.ClientId}/{comp.Kind}/{keyName}");
			comp.SetTopic(topic);

			uniqueId..Clear().AppendF($"{keyName}_{comp.Kind}");

			using(writer.BeginObject(keyName))
			{
				writer.WriteValueStr("name", name);
				writer.WriteValueStr("p", comp.Kind);
				writer.WriteValueStr("unique_id", uniqueId);

				comp.WriteDiscoveryPayload(writer);
			}
		}
	}

	public delegate void OnEventDelegate(EPlatformEvent event);

	public Event<OnEventDelegate> onEvent ~ _.Dispose();

	MQTTSensor _monitorState ~ delete _;
	MQTTSensor _loginState ~ delete _;
	MQTTSensor _powerState ~ delete _;

	MQTTNumber<uint32> _audioVolume ~ delete _;

	append List<MQTTComponent> _mqttComponents ~ ClearAndDeleteItems!(_);
	append List<MQTTComponent> _mqttDirtyComponents;
	append Dictionary<String, List<MQTTComponent>> _mqttTopicSubComponents ~ DeleteKeysAndValues!(_);

	append Monitor _dirtyComponentMonitor;

	volatile bool _running;

	Config _cfg;
	public void AssignConfig(Config cfg) => _cfg = cfg;

	public abstract void Update(double deltaTime);

	public abstract int32 Start(EServiceOptions serviceOpts, bool debug);

	protected virtual void QueryMonitorState() { }

	protected virtual void QueryUserState() { }

	public void Shutdown()
	{
		if (_cfg.ShutdownOnExit)
			SendEvent(.Shutdown);

		_running = false;
	}

	protected void SendEvent(EPlatformEvent event)
	{
		if (onEvent.HasListeners)
			onEvent(event);
	}

	void AddComponent(MQTTComponent component)
	{
		_mqttComponents.Add(component);
	}

	void MarkComponentDirty(MQTTComponent component, bool force = false)
	{
		using (_dirtyComponentMonitor.Enter())
		{
			if (!force && !component.IsDirty)
				return;

			if (_mqttDirtyComponents.IndexOf(component) == -1)
				_mqttDirtyComponents.Add(component);
		}
	}

	protected virtual Result<void> Run()
	{
		Runtime.Assert(!_running);

		_running = true;
		MQTTHandler mqtt = scope .();

		MQTTHandler.ECredentials credentials;

		if (_cfg.BinaryPwdPath.IsEmpty)
		{
			if (_cfg.Username.IsEmpty && _cfg.Password.IsEmpty)
				credentials = .None;
			else
				credentials = .Pwd(_cfg.Username, _cfg.Password);
		}
		else
		{
			List<uint8> buffer = scope:: .();
			if (System.IO.File.ReadAll(_cfg.BinaryPwdPath, buffer) case .Err(let err))
			{
				Log.Error(scope $"Failed to read BinaryPwd ({err}) path: '{_cfg.BinaryPwdPath}'");
				return .Err;
			}
			credentials = .Binary(_cfg.Username, buffer);
		}

		if (mqtt.Init(_cfg.Address, _cfg.ClientId, credentials) case .Err)
		{
			Log.Error("Failed to init MQTT");
			return .Err;
		}
		Log.Success("MQTT Initialized");

		_monitorState = AddComponent(.. new MQTTSensor("Monitor State"));
		_loginState = AddComponent(.. new MQTTSensor("Current User"));
		_powerState = AddComponent(.. new MQTTSensor("System State"));

		let minitorOffBtn = AddComponent(.. new MQTTButton("Monitor Powersave"));
		minitorOffBtn.onReceive.Add(new (data) => { TrySilent!(HandleClientCommand(.MonitorPowersave)); });

		let locKWorkstation = AddComponent(.. new MQTTButton("Lock Workstation"));
		locKWorkstation.onReceive.Add(new (data) => { TrySilent!(HandleClientCommand(.LockWorkstation)); });

		let mediaStop = AddComponent(.. new MQTTButton("Media Stop"));
		mediaStop.onReceive.Add(new (data) => { TrySilent!(HandleClientCommand(.MediaStop)); });

		let mediaNext = AddComponent(.. new MQTTButton("Media Prev"));
		mediaNext.onReceive.Add(new (data) => { TrySilent!(HandleClientCommand(.MediaPrev)); });

		let mediaPrev = AddComponent(.. new MQTTButton("Media Next"));
		mediaPrev.onReceive.Add(new (data) => { TrySilent!(HandleClientCommand(.MediaNext)); });

		let audioMuteToggle = AddComponent(.. new MQTTButton("Toggle Mute"));
		audioMuteToggle.onReceive.Add(new (data) => { TrySilent!(HandleClientCommand(.AudioMute)); });

		_audioVolume = AddComponent(.. new MQTTNumber<uint32>("Volume"));
		_audioVolume.SetMinMax(0, 100);
		_audioVolume.onValueChangeRequest.Add(new (newValue) => {
			TrySilent!(HandleClientCommand(.AudioSetVolume(newValue)));
		});

		let deviceNotification = AddComponent(.. new MQTTNotify("Notifications"));
		deviceNotification.onReceive.Add(new (data) => {
			let text = new:ScopedAlloc! String(data.Length + 4);
			System.Text.Encoding.UTF8.DecodeToUTF8(data, text).IgnoreError();
			text.Replace("\n", "\\\n");
			TrySilent!(HandleClientCommand(.Notification(default, text)));
		});

		String componentsString = scope .();
		GenerateComponentsString(componentsString, _cfg, _mqttComponents);

		bool? failedDiscovery = null;
		mqtt.onConnect.Add(new [?]() => {

			defer
			{
				SendEvent(.PowerOn);
				QueryMonitorState();
				QueryUserState();

				for (let (topic, _) in _mqttTopicSubComponents)
				{
					if (mqtt.SubscribeTopic(topic) case .Err)
					{
						Log.Error(scope $"Failed to subscribe to topic '{topic}'");
					}
				}
			}

			if (failedDiscovery != null)
			{
				return;
			}

			MQTTComponent.SubscribeTopicDelegate subscribe = scope (component, topic) => {

				if (_mqttTopicSubComponents.TryAddAlt(topic, let keyPtr, let valPtr))
				{
					*keyPtr = new String(topic);
					*valPtr = new .();
				}
				
				(*valPtr).Add(component);
			};
			for (let comp in _mqttComponents)
			{
				comp.SubscribeTopic(subscribe);
			}

			let topicString = FormatPayloadsString(.. scope .(DISCOVERY_TOPIC), _cfg, null);
			let payloadString = FormatPayloadsString(.. scope .(DISCOVERY_PAYLOAD), _cfg, componentsString);

			switch (mqtt.SendMessage(topicString, payloadString))
			{
			case .Ok(let token):
				{
					if (mqtt.WaitToken(token, .FromSeconds(2)))
					{
						Log.Success("MQTT Discovery sent and received.");
						failedDiscovery = false;
						break;
					}
					
					failedDiscovery = null;
				}
			case .Err:
				{
					Log.Error($"Failed to send discovery message");
					failedDiscovery = true;
				}
			}
		});

		mqtt.onConnectionLost.Add(new (reason) => {
			Log.Error(scope $"MQTT Connection lost '{reason}'");
		});

		mqtt.onMessageReceived.Add(new (topic, msg) => {

			Log.Trace(scope $"[MQTT] Message received on topic '{topic}' payload length: {msg.payloadlen}");
			if (!_mqttTopicSubComponents.TryGetValueAlt(topic, let components))
				return;

			for (let comp in components)
			{
				Span<uint8> payload = .((uint8*)msg.payload, msg.payloadlen);
				comp.Receive(payload);
			}
		});

		onEvent.Add(new (event) => {

			static StringView UsernameOrUnknown(StringView user)
			{
				if (user.IsEmpty || user.IsWhiteSpace)
					return "Unknown";

				return user;
			}

			MQTTComponent updatedComponent = null;

			switch (event)
			{
			case .MonitorPower(let on):
				{
					_monitorState.Value = on ? "on" : "off";
					updatedComponent = _monitorState;
				}
			case .Login(let user):
				{
					_loginState.Value = UsernameOrUnknown(user);
					updatedComponent = _loginState;
				}
			case .Locked:
				{
					_loginState.Value = "locked";
					updatedComponent = _loginState;
				}
			case .Unlocked(let user):
				{
					_loginState.Value = UsernameOrUnknown(user);
					updatedComponent = _loginState;
				}
			case .Logout:
				{
					_loginState.Value = "none";
					updatedComponent = _loginState;
				}
			case .PowerOn:
				{
					_powerState.Value = "on";
					updatedComponent = _powerState;
				}
			case .Shutdown:
				{
					_powerState.Value = "off";
					updatedComponent = _powerState;
				}
			case .AppFocus, .Battery:
				
			}

			if (updatedComponent != null)
			{
				MarkComponentDirty(updatedComponent);
			}	

		});

		Stopwatch sw = scope .(true);


		List<MQTTComponent> remainingDirtyComponents = scope .();

		bool lastUpdate = false;
		while (_running || lastUpdate)
		{
			let deltaTime = sw.ElapsedMilliseconds;
			sw.Restart();

			Update(deltaTime);

			mqtt.Update(deltaTime, _cfg);

			if (mqtt.IsConnected)
			{
				HANDLE_DIRTY_COMPONENTS:
				while (true)
				{
					MQTTComponent component;
					using (_dirtyComponentMonitor.Enter())
					{
						if (_mqttDirtyComponents.IsEmpty)
							break HANDLE_DIRTY_COMPONENTS;

						component = _mqttDirtyComponents.PopBack();
					}
					component.Publish(mqtt).IgnoreError();
					if (component.IsDirty)
					{
						remainingDirtyComponents.Add(component);
					}
				}

				if (remainingDirtyComponents.Count > 0)
				{
					using (_dirtyComponentMonitor.Enter())
					{
						for (let comp in remainingDirtyComponents)
						{
							if (_mqttDirtyComponents.IndexOf(comp) == -1)
								_mqttDirtyComponents.Add(comp);
						}
					}

					remainingDirtyComponents.Clear();
				}
			}

			if (lastUpdate)
				break;

			lastUpdate = !_running;
		}

		return .Ok;
	}

	public abstract Result<void> HandleClientCommand(eClientCommand cmd);

	public virtual Result<void> HandleServerCommand(eServerCommand cmd)
	{
		switch(cmd)
		{
		case .AudioVolumeChanged(let volume):
			{
				_audioVolume.Value = volume;
				MarkComponentDirty(_audioVolume);
				return .Ok;
			}
		}
		#unwarn
		return .Err;
	}
}