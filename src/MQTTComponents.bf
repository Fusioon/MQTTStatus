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
	}

	public virtual StringView Topic_GET => Topic;
	public virtual StringView Topic_SET => Topic;

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

	public virtual void SetTopic(StringView topicBasePath)
	{
		_topic.Set(topicBasePath);
	}
}

abstract class MQTTPublishComponent : MQTTComponent
{
	public override bool CanPublish => true;

	const int MAX_RETRIES = 4;

	protected volatile bool _isDirty;
	protected int32 _remainingRetries;
	protected append Monitor _monitor;

	public override bool IsDirty => _isDirty;

	[AllowAppend]
	public this(StringView name) : base(name)
	{

	}

	public void MarkDirty()
	{
		_remainingRetries = MAX_RETRIES;
		_isDirty = true;
	}

	protected Result<void> CheckSendMessageResult(MQTTHandler mqtt, Result<MQTTHandler.DeliveryToken> result)
	{
		switch (result)
		{
		case .Ok(let token):
			{
				if (mqtt.WaitToken(token, .FromMilliseconds(1000)))
				{
					_isDirty = false;
					return .Ok;
				}
				else
				{
					Log.Error(scope $"Failed to deliver message on topic '{Topic_GET}'");
				}
			}
		case .Err:
			Log.Error(scope $"Failed to send message on topic '{Topic_GET}'");
		}

		_remainingRetries--;
		if (_remainingRetries == 0)
		{
			Log.Error(scope $"Failed to send message on topic '{Topic_GET}'");
			_isDirty = false;
		}

		return .Err;
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

class MQTTNumber<T> : MQTTPublishComponent
	where T : struct, INumeric
	where int : operator T <=> T
{
	public enum eMode
	{
		Auto,
		Box,
		Slider
	}

	T _min;
	T _max;
	bool _hasMinMax;

	public eMode mode;

	public override System.StringView Topic_GET => _getTopic;
	public override System.StringView Topic_SET => _setTopic;

	append String _getTopic;
	append String _setTopic;

	public Event<delegate void(T newValue)> onValueChangeRequest ~ _.Dispose();

	[AllowAppend]
	public this(StringView name) : base(name)
	{

	}

	T _value;
	public T Value
	{
		get
		{
			using (_monitor.Enter())
				return _value;
		}
		set
		{
			using (_monitor.Enter())
			{
				if (_value == value)
					return;

				_value = _hasMinMax ? Math.Clamp(value, _min, _max) : value;
				MarkDirty();
			}
		}
	}

	public override StringView Kind => "number";
	public override bool CanPublish => true;

	public void SetMinMax(T min, T max)
	{
		Runtime.Assert(min <= max);
		_hasMinMax = true;
		_min = min;
		_max = max;
	}

	protected static extern void WriteValue(JSONWriter writer, StringView key, T value);
	protected static extern Result<T> Parse(StringView value);

	public override void WriteDiscoveryPayload(JSONWriter writer)
	{
		writer.WriteValueStr("command_topic", Topic_SET);
		writer.WriteValueStr("state_topic", Topic_GET);

		String modeString;
		switch (mode)
		{
		case .Auto: modeString = "auto";
		case .Box: modeString = "box";
		case .Slider: modeString = "slider";
		}

		writer.WriteValueStr("mode", modeString);

		if (_hasMinMax)
		{
			WriteValue(writer, "min", _min);
			WriteValue(writer, "max", _max);
		}

		base.WriteDiscoveryPayload(writer);
	}

	public override void SetTopic(System.StringView topicBasePath)
	{
		base.SetTopic(topicBasePath);
		_getTopic..Clear().AppendF($"{topicBasePath}/get");
		_setTopic..Clear().AppendF($"{topicBasePath}/set");
	}

	public override void SubscribeTopic(SubscribeTopicDelegate subscribe)
	{
		subscribe(this, Topic_SET);
		base.SubscribeTopic(subscribe);
	}

	public override Result<void> Publish(MQTTStatus.MQTTHandler mqtt)
	{
		if (!_isDirty)
			return .Ok;

		String buffer = scope .(64);
		using (_monitor.Enter())
		{
			_value.ToString(buffer);
		}
		let result = mqtt.SendMessage(Topic_GET, buffer);

		return CheckSendMessageResult(mqtt, result);
	}

	public override Result<void> Receive(System.Span<uint8> data)
	{
		if (onValueChangeRequest.HasListeners)
		{
			String buffer = scope .(128);
			System.Text.Encoding.UTF8.DecodeToUTF8(data, buffer).IgnoreError();
			if (Parse(buffer) case .Ok(let val))
			{
				onValueChangeRequest(val);
			}
		}

		return base.Receive(data);
	}
}

extension MQTTNumber<T>
	where T : struct, IInteger, ISigned, IMinMaxValue<T>
	where int64 : operator explicit T
	where T : operator explicit int64
{
	override protected static void WriteValue(JSONWriter writer, StringView key, T value)
	{
		writer.WriteValueI64(key, (int64)value);
	}

	override protected static Result<T> Parse(StringView value)
	{
		if (int64.Parse(value) case .Ok(let val))
		{
			if ((val <= (int64)T.MaxValue) && (val >= (int64)T.MinValue))
			{
				return (T)val;
			}
		}

		return .Err;
	}

}

extension MQTTNumber<T>
	where T : struct, IInteger, IUnsigned, IMinMaxValue<T>
	where uint64 : operator explicit T
	where T : operator explicit uint64
{
	override protected static void WriteValue(JSONWriter writer, StringView key, T value)
	{
		writer.WriteValueU64(key, (uint64)value);
	}

	override protected static Result<T> Parse(StringView value)
	{
		if (uint64.Parse(value) case .Ok(let val))
		{
			if (val <= (uint64)T.MaxValue)
			{
				return (T)val;
			}
		}

		return .Err;
	}

}

extension MQTTNumber<T>
	where T : struct, float
{
	override protected static void WriteValue(JSONWriter writer, StringView key, T value)
	{
		writer.WriteValueF(key, value);
	}

	override protected static Result<T> Parse(StringView value)
	{
		return Try!(float.Parse(value));
	}

}



class MQTTSensor : MQTTPublishComponent
{
	public override StringView Kind => "sensor";

	append String _value = .(16);

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

		return CheckSendMessageResult(mqtt, result);
	}
}