using System;
using System.Threading;
using System.Collections;
using System.IO;

using MQTTCommon;

namespace MQTTStatus;

abstract class MQTTComponent
{
	public delegate void SubscribeTopicDelegate(MQTTComponent component, StringView topic);

	protected readonly String _name ~ delete:append _;
	protected append String _topic = .(64);

	public StringView Name
	{
		get => _name;
	}

	public StringView Topic
	{
		get => _topic;
		internal set => _topic.Set(value);
	}

	public abstract StringView Kind { get; }
	public virtual bool IsDirty => false;
	public virtual bool CanPublish => false;

	public Event<delegate void(Span<uint8> data)> onReceive ~ _.Dispose();

	[AllowAppend]
	public this(StringView name)
	{
		String nameTmp = append String(name);

		_name = nameTmp;
	}

	public virtual Result<void> Publish(MQTTHandler mqtt) => .Ok;

	public virtual Result<void> Receive(Span<uint8> data)
	{
		if (onReceive.HasListeners)
			onReceive(data);

		return .Ok;
	}

	public virtual void WriteDiscoveryPayload(JSONWriter writer)
	{

	}

	public virtual void SubscribeTopic(SubscribeTopicDelegate subscribe)
	{

	}
}

class MQTTButton : MQTTComponent
{
	public override StringView Kind => "button";

	[AllowAppend]
	public this(StringView name) : base(name)
	{

	}

	public override void WriteDiscoveryPayload(JSONWriter writer)
	{
		writer.WriteValueStr("command_topic", Topic);
		base.WriteDiscoveryPayload(writer);
	}

	public override void SubscribeTopic(SubscribeTopicDelegate subscribe)
	{
		subscribe(this, Topic);
		base.SubscribeTopic(subscribe);
	}
}

class MQTTNotify : MQTTComponent
{
	public override StringView Kind => "notify";


	[AllowAppend]
	public this(StringView name) : base(name)
	{

	}

	public override void WriteDiscoveryPayload(JSONWriter writer)
	{
		writer.WriteValueStr("command_topic", Topic);
		base.WriteDiscoveryPayload(writer);
	}

	public override void SubscribeTopic(SubscribeTopicDelegate subscribe)
	{
		subscribe(this, Topic);
		base.SubscribeTopic(subscribe);
	}
}

class MQTTText : MQTTComponent
{
	public override StringView Kind => "text";

	public readonly bool password;

	[AllowAppend]
	public this(StringView name, bool password) : base(name)
	{
		this.password = password;
	}

	public override void WriteDiscoveryPayload(JSONWriter writer)
	{
		writer.WriteValueStr("command_topic", Topic);
		writer.WriteValueStr("mode", password ? "password" : "text");
		base.WriteDiscoveryPayload(writer);
	}

	public override void SubscribeTopic(SubscribeTopicDelegate subscribe)
	{
		subscribe(this, Topic);
		base.SubscribeTopic(subscribe);
	}
}

class MQTTSensor : MQTTComponent
{
	public override StringView Kind => "sensor";
	public override bool CanPublish => true;

	const int MAX_RETRIES = 4;

	append String _value = .(16);
	volatile bool _isDirty;
	int32 _remainingRetries;
	append Monitor _monitor;

	public override bool IsDirty => _isDirty;

	public StringView Value
	{
		get => _value;
		set
		{
			if (_value == value)
				return;

			using (_monitor.Enter())
			{
				_value.Set(value);
				MarkDirty();
			}
		}
	}

	[AllowAppend]
	public this(StringView name) : base(name)
	{
		
	}

	public void MarkDirty()
	{
		_remainingRetries = MAX_RETRIES;
		_isDirty = true;
	}

	public override void WriteDiscoveryPayload(JSONWriter writer)
	{
		writer.WriteValueStr("state_topic", Topic);

		base.WriteDiscoveryPayload(writer);
	}

	public override Result<void> Publish(MQTTHandler mqtt)
	{
		if (!_isDirty)
			return .Ok;

		_monitor.Enter();
		let result = mqtt.SendMessage(_topic, _value);
		_monitor.Exit();

		switch (result)
		{
		case .Ok(let token):
			{
				if (mqtt.WaitToken(token, .FromMilliseconds(500)))
				{
					_isDirty = false;
					return .Ok;
				}
				else
				{
					Log.Error(scope $"Failed to send deliver messageon topic '{Topic}'");
				}
			}
		case .Err:
			Log.Error(scope $"Failed to send message on topic '{Topic}'");
		}

		_remainingRetries--;
		if (_remainingRetries == 0)
		{
			Log.Error(scope $"Failed to send message on topic '{Topic}'");
			_isDirty = false;
		}

		return .Err;
	}
}