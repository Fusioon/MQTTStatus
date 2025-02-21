using System;
using System.Threading;

namespace MQTTStatus;

abstract class MQTTComponent
{
	protected readonly String _name ~ delete:append _;
	protected readonly String _topic ~ delete:append _;

	public StringView Name
	{
		get => _name;
	}

	public StringView Topic
	{
		get => _topic;
	}

	[AllowAppend]
	public this(StringView name, StringView topic)
	{
		String nameTmp = append String(name);
		String topicTmp = append String(topic);

		_name = nameTmp;
		_topic = topicTmp;
	}

	public abstract Result<void> Publish(MQTTHandler mqtt);
}

class MQTTSensor : MQTTComponent
{
	const int MAX_RETRIES = 4;

	append String _value = .(16);
	volatile bool _isDirty;
	int32 _remainingRetries;
	append Monitor _monitor;

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
	public this(StringView name, StringView topic) : base(name, topic)
	{
		
	}

	public void MarkDirty()
	{
		_remainingRetries = MAX_RETRIES;
		_isDirty = true;
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