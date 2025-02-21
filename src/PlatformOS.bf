using System;
using System.Threading;
using System.Diagnostics;
using System.Collections;
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
	const String MONITOR_STATE_TOPIC = "@{CLIENT_ID}/sensor/monitorState";
	const String SYSTEM_STATE_TOPIC = "@{CLIENT_ID}/sensor/systemState";
	const String CURRENT_USER_TOPIC = "@{CLIENT_ID}/sensor/currentUser";

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
		"monitorState": {
			"name": "Monitor State",
			"p": "sensor",
			"state_topic": "@{MONITOR_STATE_TOPIC}",
			"unique_id": "monitorState_sensor001"
		},
		"systemState": {
			"name": "System State",
			"p": "sensor",
			"state_topic": "@{SYSTEM_STATE_TOPIC}",
			"unique_id": "systemState_sensor002"
		},
		"currentUser": {
			"name": "Current User",
			"p": "sensor",
			"state_topic": "@{CURRENT_USER_TOPIC}",
			"unique_id": "currentUser_sensor003"
		}
	}
}
""";

	

	[Comptime(ConstEval=true)]
	static String Fmt(String b)
	{
		return new $"@{{{b}}}";
	}

	void FormatPayloadsString(String buffer, Config cfg, bool allowComponents)
	{
		(String find, StringView replace)[?] replace = .(
			(Fmt("CLIENT_ID"), cfg.ClientId),
			(Fmt("DEVICE_NAME"), cfg.DeviceName)
		);
		for (let f in replace)
			buffer.Replace(f.find, f.replace);

		if (allowComponents && _mqttComponents != null)
		{
			int pos = 0;
			repeat
			{
				pos = buffer.IndexOf("@{", pos);
				if (pos == -1)
					break;

				let end = buffer.IndexOf('}', pos);
				if (end == -1)
					break;

				let name = buffer[pos + 2..<end];

				for (let cmp in _mqttComponents)
				{
					if (name == cmp.Name)
					{
						buffer.Replace(pos, end + 1 - pos, cmp.Topic);
						break;
					}
				}
			}
			while (pos != -1);
		}
	}

	public delegate void OnEventDelegate(EPlatformEvent event);

	public Event<OnEventDelegate> onEvent ~ _.Dispose();

	MQTTSensor _monitorState ~ delete _;
	MQTTSensor _loginState ~ delete _;
	MQTTSensor _powerState ~ delete _;
	append List<MQTTComponent> _mqttComponents;

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

	protected virtual Result<void> Run(Config cfg)
	{
		MQTTHandler mqtt = scope .();

		INIT:
		do
		{
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

			int32 retries = (.)cfg.RetryCount;
			while (retries > 0)
			{
				if (mqtt.Init(cfg.Address, cfg.ClientId, credentials) case .Ok)
				{
					break INIT;
				}
				retries--;
				System.Threading.Thread.Sleep((.)cfg.RetryDelay);
			}

			Log.Error("Failed to init MQTT");
			return .Err;
		}
		Log.Success("MQTT Initialized");

		_monitorState = AddComponent(.. new MQTTSensor(nameof(MONITOR_STATE_TOPIC), FormatPayloadsString(.. scope .(MONITOR_STATE_TOPIC), cfg, false)));
		_loginState = AddComponent(.. new MQTTSensor(nameof(CURRENT_USER_TOPIC), FormatPayloadsString(.. scope .(CURRENT_USER_TOPIC), cfg, false)));
		_powerState = AddComponent(.. new MQTTSensor(nameof(SYSTEM_STATE_TOPIC), FormatPayloadsString(.. scope .(SYSTEM_STATE_TOPIC), cfg, false)));
		{
			let topic = FormatPayloadsString(.. scope .(DISCOVERY_TOPIC), cfg, false);
			let payload = FormatPayloadsString(.. scope .(DISCOVERY_PAYLOAD), cfg, true);

			switch (mqtt.SendMessage(topic, payload))
			{
			case .Ok(let token):
				{
					if (mqtt.WaitToken(token, .FromSeconds(1)))
					{
						Log.Success("MQTT Discovery sent and received.");
					}
				}
			case .Err:
				{
					Log.Error($"Failed to send discovery message");
					return .Err;
				}
			}
		}

		mqtt.onConnectionLost.Add(new (reason) => {
			Log.Error(scope $"MQTT Connection lost '{reason}'");
		});

		onEvent.Add(new (event) => {

			static StringView UsernameOrUnknown(StringView user)
			{
				if (user.IsEmpty || user.IsWhiteSpace)
					return "Unknown";

				return user;
			}

			switch (event)
			{
			case .MonitorPower(let on):
				{
					_monitorState.Value = on ? "on" : "off";
				}
			case .Login(let user):
				{
					_loginState.Value = UsernameOrUnknown(user);
				}
			case .Locked:
				{
					_loginState.Value = "locked";
				}
			case .Unlocked(let user):
				{
					_loginState.Value = UsernameOrUnknown(user);
				}
			case .Logout:
				{
					_loginState.Value = "none";
				}
			case .PowerOn:
				{
					_powerState.Value = "on";
				}
			case .Shutdown:
				{
					_powerState.Value = "off";
				}
			case .AppFocus, .Battery:
				
			}

		});

		SendEvent(.PowerOn);
		QueryMonitorState();
		QueryUserState();

		Stopwatch sw = scope .(true);

		bool running = true;
		while (running)
		{
			let deltaTime = sw.ElapsedMilliseconds;
			sw.Restart();

			running = Update(deltaTime);

			mqtt.Update(deltaTime);

			if (mqtt.IsConnected)
			{
				for (let component in _mqttComponents)
				{
					component.Publish(mqtt).IgnoreError();
				}
			}
		}

		return .Ok;
	}
}