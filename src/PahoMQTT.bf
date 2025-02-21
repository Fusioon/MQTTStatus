using System;
using System.Interop;

namespace PahoMQTT;

[CallingConvention(.Cdecl)]
public function c_int Persistence_open(void** handle, c_char* clientID, c_char* serverURI, void* context);
[CallingConvention(.Cdecl)]
public function c_int Persistence_close(void* handle);
[CallingConvention(.Cdecl)]
public function c_int Persistence_put(void* handle, c_char* key, c_int bufcount, c_char** buffers, c_int* buflens);
[CallingConvention(.Cdecl)]
public function c_int Persistence_get(void* handle, c_char* key, c_char** buffer, c_int* buflen);
[CallingConvention(.Cdecl)]
public function c_int Persistence_remove(void* handle, c_char* key);
[CallingConvention(.Cdecl)]
public function c_int Persistence_keys(void* handle, c_char*** keys, c_int* nkeys);
[CallingConvention(.Cdecl)]
public function c_int Persistence_clear(void* handle);
[CallingConvention(.Cdecl)]
public function c_int Persistence_containskey(void* handle, c_char* key);
[CallingConvention(.Cdecl)]
public function c_int MQTTPersistence_beforeWrite(void* context, c_int bufcount, c_char** buffers, c_int* buflens);
[CallingConvention(.Cdecl)]
public function c_int MQTTPersistence_afterRead(void* context, c_char** buffer, c_int* buflen);
public typealias MQTTClient = void*;
[CallingConvention(.Cdecl)]
public function c_int MQTTClient_messageArrived(void* context, c_char* topicName, c_int topicLen, MQTTClient_message* message);
[CallingConvention(.Cdecl)]
public function void MQTTClient_deliveryComplete(void* context, c_int dt);
[CallingConvention(.Cdecl)]
public function void MQTTClient_connectionLost(void* context, c_char* cause);
[CallingConvention(.Cdecl)]
public function void MQTTClient_disconnected(void* context, MQTTProperties* properties, MQTTReasonCodes reasonCode);
[CallingConvention(.Cdecl)]
public function void MQTTClient_published(void* context, c_int dt, c_int packet_type, MQTTProperties* properties, MQTTReasonCodes reasonCode);
[CallingConvention(.Cdecl)]
public function void MQTTClient_traceCallback(MQTTCLIENT_TRACE_LEVELS level, c_char* message);

[AllowDuplicates]
public enum MQTTPropertyCodes : c_int
{
	MQTTPROPERTY_CODE_PAYLOAD_FORMAT_INDICATOR = 1,
	MQTTPROPERTY_CODE_MESSAGE_EXPIRY_INTERVAL,
	MQTTPROPERTY_CODE_CONTENT_TYPE,
	MQTTPROPERTY_CODE_RESPONSE_TOPIC = 8,
	MQTTPROPERTY_CODE_CORRELATION_DATA,
	MQTTPROPERTY_CODE_SUBSCRIPTION_IDENTIFIER = 11,
	MQTTPROPERTY_CODE_SESSION_EXPIRY_INTERVAL = 17,
	MQTTPROPERTY_CODE_ASSIGNED_CLIENT_IDENTIFIER,
	MQTTPROPERTY_CODE_ASSIGNED_CLIENT_IDENTIFER = 18,
	MQTTPROPERTY_CODE_SERVER_KEEP_ALIVE,
	MQTTPROPERTY_CODE_AUTHENTICATION_METHOD = 21,
	MQTTPROPERTY_CODE_AUTHENTICATION_DATA,
	MQTTPROPERTY_CODE_REQUEST_PROBLEM_INFORMATION,
	MQTTPROPERTY_CODE_WILL_DELAY_INTERVAL,
	MQTTPROPERTY_CODE_REQUEST_RESPONSE_INFORMATION,
	MQTTPROPERTY_CODE_RESPONSE_INFORMATION,
	MQTTPROPERTY_CODE_SERVER_REFERENCE = 28,
	MQTTPROPERTY_CODE_REASON_STRING = 31,
	MQTTPROPERTY_CODE_RECEIVE_MAXIMUM = 33,
	MQTTPROPERTY_CODE_TOPIC_ALIAS_MAXIMUM,
	MQTTPROPERTY_CODE_TOPIC_ALIAS,
	MQTTPROPERTY_CODE_MAXIMUM_QOS,
	MQTTPROPERTY_CODE_RETAIN_AVAILABLE,
	MQTTPROPERTY_CODE_USER_PROPERTY,
	MQTTPROPERTY_CODE_MAXIMUM_PACKET_SIZE,
	MQTTPROPERTY_CODE_WILDCARD_SUBSCRIPTION_AVAILABLE,
	MQTTPROPERTY_CODE_SUBSCRIPTION_IDENTIFIERS_AVAILABLE,
	MQTTPROPERTY_CODE_SHARED_SUBSCRIPTION_AVAILABLE,
}

public enum MQTTPropertyTypes : c_int
{
	MQTTPROPERTY_TYPE_BYTE,
	MQTTPROPERTY_TYPE_TWO_BYTE_INTEGER,
	MQTTPROPERTY_TYPE_FOUR_BYTE_INTEGER,
	MQTTPROPERTY_TYPE_VARIABLE_BYTE_INTEGER,
	MQTTPROPERTY_TYPE_BINARY_DATA,
	MQTTPROPERTY_TYPE_UTF_8_ENCODED_STRING,
	MQTTPROPERTY_TYPE_UTF_8_STRING_PAIR,
}

[AllowDuplicates]
public enum MQTTReasonCodes : c_int
{
	MQTTREASONCODE_SUCCESS,
	MQTTREASONCODE_NORMAL_DISCONNECTION = 0,
	MQTTREASONCODE_GRANTED_QOS_0 = 0,
	MQTTREASONCODE_GRANTED_QOS_1,
	MQTTREASONCODE_GRANTED_QOS_2,
	MQTTREASONCODE_DISCONNECT_WITH_WILL_MESSAGE = 4,
	MQTTREASONCODE_NO_MATCHING_SUBSCRIBERS = 16,
	MQTTREASONCODE_NO_SUBSCRIPTION_FOUND,
	MQTTREASONCODE_CONTINUE_AUTHENTICATION = 24,
	MQTTREASONCODE_RE_AUTHENTICATE,
	MQTTREASONCODE_UNSPECIFIED_ERROR = 128,
	MQTTREASONCODE_MALFORMED_PACKET,
	MQTTREASONCODE_PROTOCOL_ERROR,
	MQTTREASONCODE_IMPLEMENTATION_SPECIFIC_ERROR,
	MQTTREASONCODE_UNSUPPORTED_PROTOCOL_VERSION,
	MQTTREASONCODE_CLIENT_IDENTIFIER_NOT_VALID,
	MQTTREASONCODE_BAD_USER_NAME_OR_PASSWORD,
	MQTTREASONCODE_NOT_AUTHORIZED,
	MQTTREASONCODE_SERVER_UNAVAILABLE,
	MQTTREASONCODE_SERVER_BUSY,
	MQTTREASONCODE_BANNED,
	MQTTREASONCODE_SERVER_SHUTTING_DOWN,
	MQTTREASONCODE_BAD_AUTHENTICATION_METHOD,
	MQTTREASONCODE_KEEP_ALIVE_TIMEOUT,
	MQTTREASONCODE_SESSION_TAKEN_OVER,
	MQTTREASONCODE_TOPIC_FILTER_INVALID,
	MQTTREASONCODE_TOPIC_NAME_INVALID,
	MQTTREASONCODE_PACKET_IDENTIFIER_IN_USE,
	MQTTREASONCODE_PACKET_IDENTIFIER_NOT_FOUND,
	MQTTREASONCODE_RECEIVE_MAXIMUM_EXCEEDED,
	MQTTREASONCODE_TOPIC_ALIAS_INVALID,
	MQTTREASONCODE_PACKET_TOO_LARGE,
	MQTTREASONCODE_MESSAGE_RATE_TOO_HIGH,
	MQTTREASONCODE_QUOTA_EXCEEDED,
	MQTTREASONCODE_ADMINISTRATIVE_ACTION,
	MQTTREASONCODE_PAYLOAD_FORMAT_INVALID,
	MQTTREASONCODE_RETAIN_NOT_SUPPORTED,
	MQTTREASONCODE_QOS_NOT_SUPPORTED,
	MQTTREASONCODE_USE_ANOTHER_SERVER,
	MQTTREASONCODE_SERVER_MOVED,
	MQTTREASONCODE_SHARED_SUBSCRIPTIONS_NOT_SUPPORTED,
	MQTTREASONCODE_CONNECTION_RATE_EXCEEDED,
	MQTTREASONCODE_MAXIMUM_CONNECT_TIME,
	MQTTREASONCODE_SUBSCRIPTION_IDENTIFIERS_NOT_SUPPORTED,
	MQTTREASONCODE_WILDCARD_SUBSCRIPTIONS_NOT_SUPPORTED,
}

public enum MQTTCLIENT_TRACE_LEVELS : c_int
{
	MQTTCLIENT_TRACE_MAXIMUM = 1,
	MQTTCLIENT_TRACE_MEDIUM,
	MQTTCLIENT_TRACE_MINIMUM,
	MQTTCLIENT_TRACE_PROTOCOL,
	MQTTCLIENT_TRACE_ERROR,
	MQTTCLIENT_TRACE_SEVERE,
	MQTTCLIENT_TRACE_FATAL,
}

[CRepr]
public struct MQTTLenString
{
	public c_int len;
	public c_char* data;
}

[CRepr]
public struct MQTTProperty
{
	public MQTTPropertyCodes identifier;
	[CRepr, Union]
	public struct 
	{
		public c_uchar byte;
		public c_ushort integer2;
		public c_uint integer4;
		[CRepr]
		public using struct 
		{
			public MQTTLenString data;
			public MQTTLenString value;
		};
	} value;
}

[CRepr]
public struct MQTTProperties
{
	public c_int count;
	public c_int max_count;
	public c_int length;
	public MQTTProperty* array;
}

[CRepr]
public struct MQTTSubscribe_options
{
	public c_char[4] struct_id;
	public c_int struct_version;
	public c_uchar noLocal;
	public c_uchar retainAsPublished;
	public c_uchar retainHandling;
}

[CRepr]
public struct MQTTClient_persistence
{
	public void* context;
	public Persistence_open popen;
	public Persistence_close pclose;
	public Persistence_put pput;
	public Persistence_get pget;
	public Persistence_remove premove;
	public Persistence_keys pkeys;
	public Persistence_clear pclear;
	public Persistence_containskey pcontainskey;
}

[CRepr]
public struct MQTTClient_init_options
{
	public c_char[4] struct_id;
	public c_int struct_version;
	public c_int do_openssl_init;
}

[CRepr]
public struct MQTTClient_message
{
	public c_char[4] struct_id;
	public c_int struct_version;
	public c_int payloadlen;
	public void* payload;
	public c_int qos;
	public c_int retained;
	public c_int dup;
	public c_int msgid;
	public MQTTProperties properties;
}

[CRepr]
public struct MQTTClient_createOptions
{
	public c_char[4] struct_id;
	public c_int struct_version;
	public c_int MQTTVersion;
}

[CRepr]
public struct MQTTClient_willOptions
{
	public c_char[4] struct_id;
	public c_int struct_version;
	public c_char* topicName;
	public c_char* message;
	public c_int retained;
	public c_int qos;
	[CRepr]
	public struct 
	{
		public c_int len;
		public void* data;
	} payload;
}

[CRepr]
public struct MQTTClient_SSLOptions
{
	public c_char[4] struct_id;
	public c_int struct_version;
	public c_char* trustStore;
	public c_char* keyStore;
	public c_char* privateKey;
	public c_char* privateKeyPassword;
	public c_char* enabledCipherSuites;
	public c_int enableServerCertAuth;
	public c_int sslVersion;
	public c_int verify;
	public c_char* CApath;
	public function [CallingConvention(.Cdecl)] c_int (c_char* str, c_ulonglong len, void* u) ssl_error_cb;
	public void* ssl_error_context;
	public function [CallingConvention(.Cdecl)] c_uint (c_char* hint, c_char* identity, c_uint max_identity_len, c_uchar* psk, c_uint max_psk_len, void* u) ssl_psk_cb;
	public void* ssl_psk_context;
	public c_int disableDefaultTrustStore;
	public c_uchar* protos;
	public c_uint protos_len;
}

[CRepr]
public struct MQTTClient_nameValue
{
	public c_char* name;
	public c_char* value;
}

[CRepr]
public struct MQTTClient_connectOptions
{
	public c_char[4] struct_id;
	public c_int struct_version;
	public c_int keepAliveInterval;
	public c_int cleansession;
	public c_int reliable;
	public MQTTClient_willOptions* will;
	public c_char* username;
	public c_char* password;
	public c_int connectTimeout;
	public c_int retryInterval;
	public MQTTClient_SSLOptions* ssl;
	public c_int serverURIcount;
	public c_char** serverURIs;
	public c_int MQTTVersion;
	[CRepr]
	public struct 
	{
		public c_char* serverURI;
		public c_int MQTTVersion;
		public c_int sessionPresent;
	} returned;
	[CRepr]
	public struct 
	{
		public c_int len;
		public void* data;
	} binarypwd;
	public c_int maxInflightMessages;
	public c_int cleanstart;
	public MQTTClient_nameValue* httpHeaders;
	public c_char* httpProxy;
	public c_char* httpsProxy;
}

[CRepr]
public struct MQTTResponse
{
	public c_int version;
	public MQTTReasonCodes reasonCode;
	public c_int reasonCodeCount;
	public MQTTReasonCodes* reasonCodes;
	public MQTTProperties* properties;
}

public static
{
	public const int32 MQTT_INVALID_PROPERTY_ID =  - 2;
	public const int32 MQTTCLIENT_PERSISTENCE_DEFAULT = 0;
	public const int32 MQTTCLIENT_PERSISTENCE_NONE = 1;
	public const int32 MQTTCLIENT_PERSISTENCE_USER = 2;
	public const int32 MQTTCLIENT_PERSISTENCE_ERROR =  - 2;
	public const int32 MQTTCLIENT_SUCCESS = 0;
	public const int32 MQTTCLIENT_FAILURE =  - 1;
	public const int32 MQTTCLIENT_DISCONNECTED =  - 3;
	public const int32 MQTTCLIENT_MAX_MESSAGES_INFLIGHT =  - 4;
	public const int32 MQTTCLIENT_BAD_UTF8_STRING =  - 5;
	public const int32 MQTTCLIENT_NULL_PARAMETER =  - 6;
	public const int32 MQTTCLIENT_TOPICNAME_TRUNCATED =  - 7;
	public const int32 MQTTCLIENT_BAD_STRUCTURE =  - 8;
	public const int32 MQTTCLIENT_BAD_QOS =  - 9;
	public const int32 MQTTCLIENT_SSL_NOT_SUPPORTED =  - 10;
	public const int32 MQTTCLIENT_BAD_MQTT_VERSION =  - 11;
	public const int32 MQTTCLIENT_BAD_PROTOCOL =  - 14;
	public const int32 MQTTCLIENT_BAD_MQTT_OPTION =  - 15;
	public const int32 MQTTCLIENT_WRONG_MQTT_VERSION =  - 16;
	public const int32 MQTTCLIENT_0_LEN_WILL_TOPIC =  - 17;
	public const int32 MQTTVERSION_DEFAULT = 0;
	public const int32 MQTTVERSION_3_1 = 3;
	public const int32 MQTTVERSION_3_1_1 = 4;
	public const int32 MQTTVERSION_5 = 5;
	public const int32 MQTT_BAD_SUBSCRIBE = 0x80;
	public const int32 MQTT_SSL_VERSION_DEFAULT = 0;
	public const int32 MQTT_SSL_VERSION_TLS_1_0 = 1;
	public const int32 MQTT_SSL_VERSION_TLS_1_1 = 2;
	public const int32 MQTT_SSL_VERSION_TLS_1_2 = 3;

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_char* MQTTPropertyName(MQTTPropertyCodes value);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTProperty_getType(MQTTPropertyCodes value);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTProperties_len(MQTTProperties* props);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTProperties_add(MQTTProperties* props, MQTTProperty* prop);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTProperties_write(c_char** pptr, MQTTProperties* properties);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTProperties_read(MQTTProperties* properties, c_char** pptr, c_char* enddata);

	[CLink, CallingConvention(.Cdecl)]
	public static extern void MQTTProperties_free(MQTTProperties* properties);

	[CLink, CallingConvention(.Cdecl)]
	public static extern MQTTProperties MQTTProperties_copy(MQTTProperties* props);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTProperties_hasProperty(MQTTProperties* props, MQTTPropertyCodes propid);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTProperties_propertyCount(MQTTProperties* props, MQTTPropertyCodes propid);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_longlong MQTTProperties_getNumericValue(MQTTProperties* props, MQTTPropertyCodes propid);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_longlong MQTTProperties_getNumericValueAt(MQTTProperties* props, MQTTPropertyCodes propid, c_int index);

	[CLink, CallingConvention(.Cdecl)]
	public static extern MQTTProperty* MQTTProperties_getProperty(MQTTProperties* props, MQTTPropertyCodes propid);

	[CLink, CallingConvention(.Cdecl)]
	public static extern MQTTProperty* MQTTProperties_getPropertyAt(MQTTProperties* props, MQTTPropertyCodes propid, c_int index);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_char* MQTTReasonCode_toString(MQTTReasonCodes value);

	[CLink, CallingConvention(.Cdecl)]
	public static extern void MQTTClient_global_init(MQTTClient_init_options* inits);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_setCallbacks(MQTTClient handle, void* context, MQTTClient_connectionLost cl, MQTTClient_messageArrived ma, MQTTClient_deliveryComplete dc);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_setDisconnected(MQTTClient handle, void* context, MQTTClient_disconnected co);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_setPublished(MQTTClient handle, void* context, MQTTClient_published co);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_create(MQTTClient* handle, c_char* serverURI, c_char* clientId, c_int persistence_type, void* persistence_context);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_createWithOptions(MQTTClient* handle, c_char* serverURI, c_char* clientId, c_int persistence_type, void* persistence_context, MQTTClient_createOptions* options);

	[CLink, CallingConvention(.Cdecl)]
	public static extern MQTTClient_nameValue* MQTTClient_getVersionInfo();

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_connect(MQTTClient handle, MQTTClient_connectOptions* options);

	[CLink, CallingConvention(.Cdecl)]
	public static extern void MQTTResponse_free(MQTTResponse response);

	[CLink, CallingConvention(.Cdecl)]
	public static extern MQTTResponse MQTTClient_connect5(MQTTClient handle, MQTTClient_connectOptions* options, MQTTProperties* connectProperties, MQTTProperties* willProperties);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_disconnect(MQTTClient handle, c_int timeout);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_disconnect5(MQTTClient handle, c_int timeout, MQTTReasonCodes reason, MQTTProperties* props);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_isConnected(MQTTClient handle);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_subscribe(MQTTClient handle, c_char* topic, c_int qos);

	[CLink, CallingConvention(.Cdecl)]
	public static extern MQTTResponse MQTTClient_subscribe5(MQTTClient handle, c_char* topic, c_int qos, MQTTSubscribe_options* opts, MQTTProperties* props);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_subscribeMany(MQTTClient handle, c_int count, c_char** topic, c_int* qos);

	[CLink, CallingConvention(.Cdecl)]
	public static extern MQTTResponse MQTTClient_subscribeMany5(MQTTClient handle, c_int count, c_char** topic, c_int* qos, MQTTSubscribe_options* opts, MQTTProperties* props);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_unsubscribe(MQTTClient handle, c_char* topic);

	[CLink, CallingConvention(.Cdecl)]
	public static extern MQTTResponse MQTTClient_unsubscribe5(MQTTClient handle, c_char* topic, MQTTProperties* props);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_unsubscribeMany(MQTTClient handle, c_int count, c_char** topic);

	[CLink, CallingConvention(.Cdecl)]
	public static extern MQTTResponse MQTTClient_unsubscribeMany5(MQTTClient handle, c_int count, c_char** topic, MQTTProperties* props);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_publish(MQTTClient handle, c_char* topicName, c_int payloadlen, void* payload, c_int qos, c_int retained, c_int* dt);

	[CLink, CallingConvention(.Cdecl)]
	public static extern MQTTResponse MQTTClient_publish5(MQTTClient handle, c_char* topicName, c_int payloadlen, void* payload, c_int qos, c_int retained, MQTTProperties* properties, c_int* dt);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_publishMessage(MQTTClient handle, c_char* topicName, MQTTClient_message* msg, c_int* dt);

	[CLink, CallingConvention(.Cdecl)]
	public static extern MQTTResponse MQTTClient_publishMessage5(MQTTClient handle, c_char* topicName, MQTTClient_message* msg, c_int* dt);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_waitForCompletion(MQTTClient handle, c_int dt, c_ulong timeout);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_getPendingDeliveryTokens(MQTTClient handle, c_int** tokens);

	[CLink, CallingConvention(.Cdecl)]
	public static extern void MQTTClient_yield();

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_receive(MQTTClient handle, c_char** topicName, c_int* topicLen, MQTTClient_message** message, c_ulong timeout);

	[CLink, CallingConvention(.Cdecl)]
	public static extern void MQTTClient_freeMessage(MQTTClient_message** msg);

	[CLink, CallingConvention(.Cdecl)]
	public static extern void MQTTClient_free(void* ptr);

	[CLink, CallingConvention(.Cdecl)]
	public static extern void* MQTTClient_malloc(c_ulonglong size);

	[CLink, CallingConvention(.Cdecl)]
	public static extern void MQTTClient_destroy(MQTTClient* handle);

	[CLink, CallingConvention(.Cdecl)]
	public static extern void MQTTClient_setTraceLevel(MQTTCLIENT_TRACE_LEVELS level);

	[CLink, CallingConvention(.Cdecl)]
	public static extern void MQTTClient_setTraceCallback(MQTTClient_traceCallback callback);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_int MQTTClient_setCommandTimeout(MQTTClient handle, c_ulong milliSeconds);

	[CLink, CallingConvention(.Cdecl)]
	public static extern c_char* MQTTClient_strerror(c_int code);

}

