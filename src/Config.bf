using System;

using Fusion.TOML;

namespace MQTTStatus;

class Config
{
	const String HEADER_CONNECTION = "Connection";
	const String HEADER_DEVICE = "Device";
	const String HEADER_LOGGING = "Logging";

	append String _address;
	append String _username;
	append String _password;
	String _binaryPwdPath = null ~ delete _;

	protected int32 _retryDelayStart = 2000;
	protected int32 _retryDelayMax = 45000;
	protected float _retryDelayMult = 1.5f;

	public int32 RetryDelayStart
	{
		get => _retryDelayStart;
	}

	public int32 RetryDelayMax
	{
		get => _retryDelayMax;
	}

	public float RetryDelayMult
	{
		get => _retryDelayMult;
	}

	append String _clientID;
	append String _deviceName;

	public StringView Address
	{
		get => _address;
		protected set => _address.Set(value);
	}

	public StringView Username
	{
		get => _username;
		protected set => _username.Set(value);
	}

	public StringView Password
	{
		get => _password;
		protected set => _password.Set(value);
	}

	public StringView BinaryPwdPath
	{
		get => _binaryPwdPath;
	}

	public StringView ClientId
	{
		get => _clientID;
		protected set => _clientID.Set(value);
	}
	public StringView DeviceName
	{
		get => _deviceName;
		protected set => _deviceName.Set(value);
	}

	public void SetDefault()
	{
		Address = "mqtt://127.0.0.1:1883";
		Username = "username";
		Password = "password";

		_retryDelayStart = 2000;
		_retryDelayMax = 45000;
		_retryDelayMult = 1.5f;

		ClientId = "0AB10FU0";
		DeviceName = "Puter";
	}

	public Result<void> Load(StringView path)
	{
		TomlDocument doc = scope .();
		switch (doc.ReadFromFile(path))
		{
		case .Err(let err):
			{
				Log.Error(scope $"[TOML] Failed to read file ({err}).");
				return .Err;
			}
		case .Ok:
		}

		if (let conn = doc[HEADER_CONNECTION].GetValueOrDefault().AsObject())
		{
			_address.Set(conn[nameof(Address)].GetValueOrDefault().AsString().GetValueOrDefault());
			_username.Set(conn[nameof(Username)].GetValueOrDefault().AsString().GetValueOrDefault());
			_password.Set(conn[nameof(Password)].GetValueOrDefault().AsString().GetValueOrDefault());

			TomlValue val;
			if (conn[nameof(BinaryPwdPath)] case .Ok(out val) && val.IsString)
			{
				let binaryPwd = val.AsString();
				_binaryPwdPath = new .(binaryPwd);
			}

			bool _;
			_ = (conn[nameof(RetryDelayStart)] case .Ok(out val) && val.AsInt32() case .Ok(out _retryDelayStart));
			_ = (conn[nameof(RetryDelayMax)] case .Ok(out val) && val.AsInt32() case .Ok(out _retryDelayMax));
			_ = (conn[nameof(RetryDelayMult)] case .Ok(out val) && val.AsFloat() case .Ok(out _retryDelayMult));
		}

		if (let dev = doc[HEADER_DEVICE].GetValueOrDefault().AsObject())
		{
			_clientID.Set(dev[nameof(ClientId)].GetValueOrDefault().AsString().GetValueOrDefault());
			_deviceName.Set(dev[nameof(DeviceName)].GetValueOrDefault().AsString().GetValueOrDefault());
		}

		if (let log = doc[HEADER_LOGGING].GetValueOrDefault().AsObject())
		{
			TomlValue val;
			if (log[nameof(Log.LogLevel)] case .Ok(out val) && val.AsEnum<ELogLevel>() case .Ok(let logLevel))
			{
				if (Enum.IsDefined(logLevel))
					Log.LogLevel = logLevel;
			}

			if (log[nameof(Log.LogCallerPathMinLevel)] case .Ok(out val) && val.AsEnum<ELogLevel>() case .Ok(let logLevel))
			{
				if (Enum.IsDefined(logLevel))
					Log.LogCallerPathMinLevel = logLevel;
			}
		}

		return .Ok;
	}

	public Result<void> Save(StringView path)
	{
		TomlDocument doc = scope .();

		if (let conn = doc.AddObject(HEADER_CONNECTION))
		{
			conn.AddValue(nameof(Address), _address);
			conn.AddValue(nameof(Username), _username);
			conn.AddValue(nameof(Password), _password);
			if (!String.IsNullOrEmpty(_binaryPwdPath))
				conn.AddValue(nameof(BinaryPwdPath), _binaryPwdPath);

			conn.AddValue(nameof(RetryDelayStart), RetryDelayStart);
			conn.AddValue(nameof(RetryDelayMax), RetryDelayMax);
			conn.AddValue(nameof(RetryDelayMult), RetryDelayMult);
		}
		if (let dev = doc.AddObject(HEADER_DEVICE))
		{
			dev.AddValue(nameof(ClientId), _clientID);
			dev.AddValue(nameof(DeviceName), _deviceName);
		}
		if (let log = doc.AddObject(HEADER_LOGGING))
		{
			log.AddValue(nameof(Log.LogLevel), Log.LogLevel.Underlying);
			log.AddValue(nameof(Log.LogCallerPathMinLevel), Log.LogCallerPathMinLevel.Underlying);
		}

		TrySilent!(TomlWriter.WriteToFile(doc, .() { flags = .PrettyPrint | .UseHeaders | .NoArrayHeaders, maxInlineElements = 4 }, path));
		return .Ok;
	}
}