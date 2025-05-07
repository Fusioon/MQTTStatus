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
			comp.Topic = topic;

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

	append List<MQTTComponent> _mqttComponents ~ ClearAndDeleteItems!(_);
	append List<MQTTComponent> _mqttDirtyComponents;
	append Dictionary<String, List<MQTTComponent>> _mqttTopicSubComponents ~ DeleteKeysAndValues!(_);

	append Monitor _dirtyComponentMonitor;

	append IPCManager _ipcManager;

	public abstract bool Update(double deltaTime);

	public abstract int32 Start(EServiceOptions serviceOpts, bool debug, Config cfg);

	protected virtual void QueryMonitorState() { }

	protected virtual void QueryUserState() { }

	protected void SendEvent(EPlatformEvent event)
	{
		if (onEvent.HasListeners)
			onEvent(event);
	}

	void AddComponent(MQTTComponent component)
	{
		_mqttComponents.Add(component);
	}

	bool HandleMsg(String msg)
	{
		return false;
	}

	protected virtual Result<void> Run(Config cfg)
	{
		MQTTHandler mqtt = scope .();

		MQTTHandler.ECredentials credentials;

		if (cfg.BinaryPwdPath.IsEmpty)
		{
			if (cfg.Username.IsEmpty && cfg.Password.IsEmpty)
				credentials = .None;
			else
				credentials = .Pwd(cfg.Username, cfg.Password);
		}
		else
		{
			List<uint8> buffer = scope:: .();
			if (System.IO.File.ReadAll(cfg.BinaryPwdPath, buffer) case .Err(let err))
			{
				Log.Error(scope $"Failed to read BinaryPwd ({err}) path: '{cfg.BinaryPwdPath}'");
				return .Err;
			}
			credentials = .Binary(cfg.Username, buffer);
		}

		if (mqtt.Init(cfg.Address, cfg.ClientId, credentials) case .Err)
		{
			Log.Error("Failed to init MQTT");
			return .Err;
		}
		Log.Success("MQTT Initialized");

		Try!(_ipcManager.Init(true));

		_monitorState = AddComponent(.. new MQTTSensor("Monitor State"));
		_loginState = AddComponent(.. new MQTTSensor("Current User"));
		_powerState = AddComponent(.. new MQTTSensor("System State"));

		let minitorOffBtn = AddComponent(.. new MQTTButton("Monitor Powersave"));
		minitorOffBtn.onReceive.Add(new (data) => { TrySilent!(_ipcManager.Send(Client_IPCCommands.MONITOR_POWERSAVE + Client_IPCCommands.COMMAND_SEPARATOR)); });

		let locKWorkstation = AddComponent(.. new MQTTButton("Lock Workstation"));
		locKWorkstation.onReceive.Add(new (data) => { TrySilent!(_ipcManager.Send(Client_IPCCommands.LOCK_WORKSTATION + Client_IPCCommands.COMMAND_SEPARATOR)); });

		let deviceNotification = AddComponent(.. new MQTTNotify("Notifications"));
		deviceNotification.onReceive.Add(new (data) => {

			let command = new:ScopedAlloc! String(Client_IPCCommands.NOTIFICATION.Length + data.Length + 4);
			command.Append(Client_IPCCommands.NOTIFICATION);
			command.Append('|');
			System.Text.Encoding.UTF8.DecodeToUTF8(data, command).IgnoreError();
			command.Replace("\n", "\\\n");
			command.Append(Client_IPCCommands.COMMAND_SEPARATOR);

			TrySilent!(_ipcManager.Send(command));
		});

		String componentsString = scope .();
		GenerateComponentsString(componentsString, cfg, _mqttComponents);

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

			let topic = FormatPayloadsString(.. scope .(DISCOVERY_TOPIC), cfg, null);
			let payload = FormatPayloadsString(.. scope .(DISCOVERY_PAYLOAD), cfg, componentsString);

			switch (mqtt.SendMessage(topic, payload))
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

			if (updatedComponent != null && updatedComponent.IsDirty)
			{
				using (_dirtyComponentMonitor.Enter())
				{
					if (_mqttDirtyComponents.IndexOf(updatedComponent) == -1)
						_mqttDirtyComponents.Add(updatedComponent);
				}
			}	

		});

		Stopwatch sw = scope .(true);

		bool running = true;

		List<MQTTComponent> remainingDirtyComponents = scope .();
		while (running)
		{
			let deltaTime = sw.ElapsedMilliseconds;
			sw.Restart();

			running = Update(deltaTime);

			_ipcManager.Update();
			String msg;
			while((msg = _ipcManager.PopMessage()) != null)
			{
				if (!HandleMsg(msg))
				{
					Log.Warning(scope $"Unhandled IPC message:\n------\n{msg}\n------");
				}
				delete msg;
			}

			mqtt.Update(deltaTime, cfg);

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
		}

		return .Ok;
	}
}