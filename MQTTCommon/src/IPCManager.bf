using System;
using System.Collections;

using MQTTCommon.Win32;

namespace MQTTCommon;

class IPCManager
{
	const String NAME = "FU_MQTTStatus";
	const int32 BUFFER_SIZE = 1024;
	bool _hasConnection;
	append String _buffer;
	append List<String> _messages ~ ClearAndDeleteItems!(_);
	append String _pipeName = .(32);

	Windows.Handle _pipeHandle ~ _.Close();

	bool _isServer;

	public Result<void> Init(bool server)
	{
		_pipeName..Clear().Append(@"\\.\pipe\", NAME);

		_isServer = server;

		if (server)
		{
			_pipeHandle = Windows.CreateNamedPipeA(_pipeName, Windows.PIPE_ACCESS_DUPLEX,       // read/write access 
				Windows.PIPE_TYPE_MESSAGE |       // message type pipe 
				Windows.PIPE_READMODE_MESSAGE |   // message-read mode 
				Windows.PIPE_NOWAIT,
				1/*Windows.PIPE_UNLIMITED_INSTANCES*/, // max. instances  
				BUFFER_SIZE,              // output buffer size 
				BUFFER_SIZE,              // input buffer size 
				0 /*NMPWAIT_USE_DEFAULT_WAIT*/, // client time-out 
				null);

			if (_pipeHandle.IsInvalid)
			{
				int32 lastError = Windows.GetLastError();
				Log.Error(scope $"[IPCManager] Failed to create named pipe ({lastError})");
				return .Err;
			}
		}
		
		return .Ok;
	}

	bool Connect(System.IO.FileAccess access)
	{
		if (!_hasConnection)
		{
			if (_isServer)
			{
				if (!Windows.ConnectNamedPipe(_pipeHandle, null))
				{
					int32 lastError = Windows.GetLastError();

					if ((lastError != Windows.ERROR_PIPE_CONNECTED) && (lastError != Windows.ERROR_NO_DATA))
						return false;
				}
				_hasConnection = true;
			}
			else
			{
				int32 flags;
				switch (access)
				{
				case .Read: flags = Windows.FILE_READ_DATA;
				case .Write: flags = Windows.FILE_WRITE_DATA;
				case .ReadWrite: flags = Windows.FILE_READ_DATA | Windows.FILE_WRITE_DATA;
				}

				_pipeHandle = Windows.CreateFileA(_pipeName.CStr(), flags, .None, null, .Open, 0, .NullHandle);
				if (_pipeHandle.IsInvalid)
				{
					let err = Windows.GetLastError();
					if (err == Windows.ERROR_FILE_NOT_FOUND)
					{
						return false; 
					}

					Log.Error(scope $"[IPCManager] Win32 CreateFile failed ({err})");
					return false;
				}
				_hasConnection = true;
			}
		}

		return _hasConnection;
	}

	void CloseConnection()
	{
		if (!_hasConnection)
			return;

		if (_isServer)
		{
			Windows.DisconnectNamedPipe(_pipeHandle);
		}

		_hasConnection = false;
		_buffer.Clear();

	}

	public Result<void> Send(StringView msg)
	{
		if (!Connect(.Write))
		{
			return .Err;
		}

		if (Windows.WriteFile(_pipeHandle, (uint8*)msg.Ptr, (int32)msg.Length, let written, null) == 0)
		{
			const int ERROR_BAD_PIPE = 0xE6;
			const int ERROR_NO_DATA = 0xE8;
			const int ERROR_PIPE_NOT_CONNECTED = 0xE9;

			let err = Windows.GetLastError();
			Log.Error(scope $"[IPCManager] Win32 WriteFile failed err: (0x{err:X})");

			switch(err)
			{
			case ERROR_BAD_PIPE:
			case ERROR_NO_DATA:
			case ERROR_PIPE_NOT_CONNECTED:
				_hasConnection = false;
				return .Err;
			}

			return .Err;
		}

		return .Ok;
	}

	[NoDiscard]
	public String PopMessage()
	{
		if (_messages.IsEmpty)
			return null;

		return _messages.PopFront();
	}

	public bool Update()
	{
		if (!Connect(.Read))
		{
			return false;
		}

		uint8[1024] buffer = default;
		int32 bytesRead;
		int32 result = Windows.ReadFile(_pipeHandle, &buffer, buffer.Count, out bytesRead, null);
		if ((result <= 0) || (bytesRead == 0))
		{
			int32 lastError = Windows.GetLastError();
			if (lastError == Windows.ERROR_BROKEN_PIPE)
			{
				CloseConnection();
			}
		}
		else
		{
			for (int32 i = 0; i < bytesRead; i++)
			{
				_buffer.Append((char8)buffer[i]);
			}
		}

		int lastEnd = 0;
		int prevIndex = 0;
		while (prevIndex < _buffer.Length)
		{
			int crPos = _buffer.IndexOf('\n', prevIndex);
			if (crPos > 0)
			{
				if (buffer[crPos - 1] != '\\')
				{
					String msg = new String(_buffer, lastEnd, crPos);
					_messages.Add(msg);
					lastEnd = crPos + 1;
				}
			}
			else
			{
				if (lastEnd < _buffer.Length)
				{
					String msg = new String(_buffer, lastEnd);
					_messages.Add(msg);
				}
				break;
			}

			prevIndex = crPos + 1;
		}

		_buffer.Clear();

		return true;
	}
}