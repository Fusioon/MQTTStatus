using System;
using System.Interop;
using System.Threading;
using System.Collections;

using PahoMQTT;
using MQTTCommon;

namespace MQTTStatus;

class MQTTHandler
{
	public delegate void MessageReceivedDelegate(StringView topic, MQTTClient_message msg);
	public delegate void ConnectionLostDelegate(StringView reason);
	public delegate void ConnectDelegate();


	public enum ECredentials
	{
		case None;
		case Pwd(StringView username, StringView password);
		case Binary(StringView username, Span<uint8> data);
	}

	public enum EConnectError
	{
		Generic,
		BadAuth,
		NotFound
	}

	public struct TokenId : this(uint16 index, uint16 version) { }

	public struct DeliveryToken
	{
		public c_int token;
		public TokenId id;

		public this(c_int token, TokenId index)
		{
			this.token = token;
			this.id = index;
		}

		public void SetUnused() mut
		{
			token = -1;
			id.index = uint16.MaxValue;
			id.version++;
		}

		public bool IsUnused => token == -1 && id.index == uint16.MaxValue;
	}

	MQTTClient _client;

	append Monitor _tokenMonitor;
	append List<DeliveryToken> _deliveryTokens;
	append List<DateTime> _deliverySendTime;
	append List<WaitEvent> _deliveryEvent;
	
	append String _credentialsUsername;
	append String _credentialsPassword;
	append List<uint8> _credentialsBinaryPwd;

	MQTTClient_connectOptions _connOpts;

	public Event<MessageReceivedDelegate> onMessageReceived ~ _.Dispose();
	public Event<ConnectionLostDelegate> onConnectionLost ~ _.Dispose();
	public Event<ConnectDelegate> onConnect ~ _.Dispose();

	volatile bool _isConnected;
	int64 _connectionRetryTimer;
	int64 _retryTime;
	int32 _connectionRetryCount;
	public bool IsConnected => _isConnected;

	static void MQTT_ConnectionLost(void* context, c_char* cause)
	{
		((Self)Internal.UnsafeCastToObject(context)).ConnectionLost(StringView(cause));
	}

	static c_int MQTT_MessageArrived(void* context, c_char* topicName, c_int topicLen, MQTTClient_message* msg)
	{
		StringView topic;
		if (topicLen == 0)
		{
			topic = .(topicName);
		}
		else
		{
			topic = .(topicName, topicLen);
		}
		
		let result = ((Self)Internal.UnsafeCastToObject(context)).Arrived(topic, msg);

		var msg;
		MQTTClient_freeMessage(&msg);
		MQTTClient_free(topicName);
		return result;
	}

	static void MQTT_MessageDelivered(void* context, c_int deliveryToken)
	{
		((Self)Internal.UnsafeCastToObject(context)).Delivered(deliveryToken);
	}


	c_int Arrived(StringView topic, MQTTClient_message* msg)
	{
		if (onMessageReceived.HasListeners)
			onMessageReceived(topic, *msg);

		return 1;
	}

	void Delivered(c_int deliveryToken)
	{
		int index;

		using (_tokenMonitor.Enter())
		{
			FIND_TOKEN:
			do
			{
				for (var token in ref _deliveryTokens)
				{
					if (token.token == deliveryToken)
					{
						index = @token.Index;
						break FIND_TOKEN;
					}
				}
				return;
			}
			
			_deliveryEvent[index].Set(true);
			_deliveryTokens[index].SetUnused(); 
		}
		
	}

	void ConnectionLost(StringView cause)
	{
		if (_isConnected && onConnectionLost.HasListeners)
			onConnectionLost(cause);

		_connectionRetryTimer = _retryTime;
		_isConnected = false;
	}

	public ~this()
	{
		if (_client != null)
		{
			MQTTClient_disconnect(_client, 10000);
			MQTTClient_destroy(&_client);
		}
	}

	public Result<void> Init(StringView address, StringView clientId, ECredentials credentials = default)
	{
		_connOpts = .() {
			struct_id = "MQTC",
			struct_version = 6,
			keepAliveInterval = 60,
			cleansession = 1,
			reliable = 1,
			will = null,
			username = null,
			password = null,
			connectTimeout = 30,
			retryInterval = 0,
			ssl = null,
			serverURIcount = 0,
			serverURIs = null,
			MQTTVersion = MQTTVERSION_DEFAULT,
			maxInflightMessages = -1,
			cleanstart = 0
		};

		switch (credentials)
		{
		case .None:
		case .Pwd(let username, let password):
			{
				_credentialsUsername.Set(username);
				_credentialsPassword.Set(password);

				_connOpts.username = _credentialsUsername.CStr();
				_connOpts.password = _credentialsPassword.CStr();
			}
		case .Binary(let username, let data):
			{
				_credentialsUsername.Set(username);
				_credentialsBinaryPwd.AddRange(data);

				_connOpts.username = _credentialsUsername.CStr();
				_connOpts.binarypwd = .(){
					len = (.)_credentialsBinaryPwd.Count,
					data = _credentialsBinaryPwd.Ptr
				};
			}
		}

		{
			let rc = MQTTClient_create(&_client, address.ToScopeCStr!(), clientId.ToScopeCStr!(), MQTTCLIENT_PERSISTENCE_NONE, null);
			if (rc != MQTTCLIENT_SUCCESS)
				return .Err;
		}

		_connOpts.keepAliveInterval = 20;
		_connOpts.cleansession = 1;
		
		MQTTClient_setCallbacks(_client, Internal.UnsafeCastToPtr(this), => MQTT_ConnectionLost, => MQTT_MessageArrived, => MQTT_MessageDelivered);
		_isConnected = false;

		return .Ok;
	}

	public Result<void, EConnectError> Connect()
	{
		let rc = MQTTClient_connect(_client, &_connOpts);
		if (rc != MQTTCLIENT_SUCCESS)
		{
			return .Err(.Generic);
		}

		_isConnected = true;
		return .Ok;
	}

	public void Update(double dt, Config cfg)
	{
		if (!_isConnected)
		{
			_connectionRetryTimer -= (.)dt;
			if (_connectionRetryTimer <= 0)
			{
				_connectionRetryCount++;
				_retryTime = Math.Min(_retryTime * (int64)cfg.RetryDelayMult, cfg.RetryDelayMax);
				if (Connect() case .Ok)
				{
					_connectionRetryCount = 0;
					_retryTime = cfg.RetryDelayStart;
					if (onConnect.HasListeners)
						onConnect();
				}

				MQTTClient_yield();
			}
		}
	}

	public Result<DeliveryToken> SendMessage(StringView topic, StringView msg, int32 qos = 1, bool retained = false)
	{
		MQTTClient_message pubmsg = .() {
			struct_id = "MQTM",
			struct_version = 1,
			
			payloadlen = (.)msg.Length,
			payload = msg.Ptr,

			qos = qos,
			retained = retained ? 1 : 0,
		};

		int32 token = 0;
		let rc = MQTTClient_publishMessage(_client, topic.ToScopeCStr!(), &pubmsg, &token);
		if (rc != MQTTCLIENT_SUCCESS)
			return .Err;

		using (_tokenMonitor.Enter())
		{
			for (var tok in ref _deliveryTokens)
			{
				if (tok.IsUnused)
				{
					tok.token = token;
					tok.id.index = (.)@tok.Index;
					_deliverySendTime[tok.id.index] = DateTime.Now;
					_deliveryEvent[tok.id.index].Reset();
					return tok;
				}
			}
			
			let deliveryToken = DeliveryToken(token, .((.)_deliveryTokens.Count, 1));
			_deliveryTokens.Add(deliveryToken);
			_deliverySendTime.Add(DateTime.Now);
			_deliveryEvent.Add(new .(false));
			return deliveryToken;
		}
	}
	
	public bool WaitToken(DeliveryToken token, TimeSpan timeout = .MinValue)
	{
		if (token.id.index >= _deliveryTokens.Count)
			return false;

		WaitEvent event;
		using (_tokenMonitor.Enter())
		{
			let storedToken = _deliveryTokens[token.id.index];
			Runtime.Assert(storedToken.id.index == token.id.index);

			if (storedToken.id.version != token.id.version)
				return true;

			event = _deliveryEvent[token.id.index];
		}

		return (event.WaitFor((.)timeout.TotalMilliseconds));
	}

	public Result<void> SubscribeTopic(StringView topic, int32 qos = 1)
	{
		let rc = MQTTClient_subscribe(_client, topic.ToScopeCStr!(), qos);
		if (rc != MQTTCLIENT_SUCCESS)
			return .Err;

		return .Ok;
	}
}