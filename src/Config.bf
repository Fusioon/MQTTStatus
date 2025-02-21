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

	protected uint32 _retryCount;
	protected uint32 _retryDelay;

	public uint32 RetryCount
	{
		get => _retryCount;
	}

	public uint32 RetryDelay
	{
		get => _retryDelay;
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

		_retryCount = 10;
		_retryDelay = 2000;

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
			if (conn[nameof(BinaryPwdPath)] case .Ok(let val) && val.IsString)
			{
				let binaryPwd = val.AsString();
				_binaryPwdPath = new .(binaryPwd);
			}

			if (conn[nameof(RetryCount)] case .Ok(let val) && val.AsUInt32() case .Ok(out _retryCount)) {}
			if (conn[nameof(RetryDelay)] case .Ok(let val) && val.AsUInt32() case .Ok(out _retryDelay)) {}
		}

		if (let dev = doc[HEADER_DEVICE].GetValueOrDefault().AsObject())
		{
			_clientID.Set(dev[nameof(ClientId)].GetValueOrDefault().AsString().GetValueOrDefault());
			_deviceName.Set(dev[nameof(DeviceName)].GetValueOrDefault().AsString().GetValueOrDefault());
		}

		if (let log = doc[HEADER_LOGGING].GetValueOrDefault().AsObject())
		{
			if (log[nameof(Log.LogLevel)] case .Ok(let val) && val.AsEnum<ELogLevel>() case .Ok(let logLevel))
			{
				if (Enum.IsDefined(logLevel))
					Log.LogLevel = logLevel;
			}

			if (log[nameof(Log.LogCallerPathMinLevel)] case .Ok(let val) && val.AsEnum<ELogLevel>() case .Ok(let logLevel))
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
			conn.AddValue(nameof(RetryCount), RetryCount);
			conn.AddValue(nameof(RetryDelay), RetryDelay);
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