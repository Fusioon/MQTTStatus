using System;
using System.Interop;

using PahoMQTT;
using System.Threading;
using System.Collections;

namespace MQTTStatus;

class MQTTHandler
{
	public delegate void MessageReceivedDelegate(StringView topic, MQTTClient_message msg);
	public delegate void ConnectionLostDelegate(StringView reason);

	public enum ECredentials
	{
		case None;
		case Pwd(StringView username, StringView password);
		case Binary(StringView username, Span<uint8> data);
	}

	public struct DeliveryToken
	{
		public c_int token;
		public uint32 index;

		public this(c_int token, uint32 index)
		{
			this.token = token;
			this.index = index;
		}
	}

	MQTTClient _client;

	append WaitEvent _tokenReceiveEvent;
	DeliveryToken _lastSentToken;
	volatile DeliveryToken _lastDeliveredToken;

	public Event<MessageReceivedDelegate> onMessageReceived ~ _.Dispose();
	public Event<ConnectionLostDelegate> onConnectionLost ~ _.Dispose();

	static void MQTT_ConnectionLost(void* context, c_char* cause)
	{
		((Self)Internal.UnsafeCastToObject(context)).ConnectionLost(StringView(cause));
	}

	static c_int MQTT_MessageArrived(void* context, c_char* topicName, c_int topicLen, MQTTClient_message* msg)
	{
		let result = ((Self)Internal.UnsafeCastToObject(context)).Arrived(StringView(topicName, topicLen), msg);

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
		_lastDeliveredToken = .(deliveryToken, 0);
		_tokenReceiveEvent.Set(true);
	}

	void ConnectionLost(StringView cause)
	{
		if (onConnectionLost.HasListeners)
			onConnectionLost(cause);
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
		MQTTClient_connectOptions conn_opts = .() {
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
				conn_opts.username = username.ToScopeCStr!::();
				conn_opts.password = password.ToScopeCStr!::();
			}
		case .Binary(let username, let data):
			{
				conn_opts.username = username.ToScopeCStr!::();
				conn_opts.binarypwd = .(){
					len = (.)data.Length,
					data = data.Ptr
				};
			}
		}

		{
			let rc = MQTTClient_create(&_client, address.ToScopeCStr!(), clientId.ToScopeCStr!(), MQTTCLIENT_PERSISTENCE_NONE, null);
			if (rc != MQTTCLIENT_SUCCESS)
				return .Err;
		}

		conn_opts.keepAliveInterval = 20;
		conn_opts.cleansession = 1;

		MQTTClient_setCallbacks(_client, Internal.UnsafeCastToPtr(this), => MQTT_ConnectionLost, => MQTT_MessageArrived, => MQTT_MessageDelivered);

		{
			let rc = MQTTClient_connect(_client, &conn_opts);
			if (rc != MQTTCLIENT_SUCCESS)
				return .Err;
		}

		return .Ok;
	}

	public void Update()
	{
		
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
		_tokenReceiveEvent.Reset();
		let rc = MQTTClient_publishMessage(_client, topic.ToScopeCStr!(), &pubmsg, &token);
		if (rc != MQTTCLIENT_SUCCESS)
			return .Err;

		_lastSentToken = .(token, 0);
		return _lastSentToken;
	}
	
	public bool WaitToken(DeliveryToken token, TimeSpan timeout = .MinValue)
	{
		if (_lastSentToken != token)
			return false;

		if (_lastDeliveredToken == token)
			return true;

		if (_tokenReceiveEvent.WaitFor((.)timeout.TotalMilliseconds))
			return _lastDeliveredToken == token;

		return false;
	}

}