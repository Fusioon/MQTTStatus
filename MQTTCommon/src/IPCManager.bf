using System;
using System.Collections;

using MQTTCommon.Win32;

namespace MQTTCommon;

class MessageHandler
{
	append String _buffer;
	append List<String> _messages ~ ClearAndDeleteItems!(_);

	[NoDiscard]
	public String PopMessage()
	{
		if (_messages.IsEmpty)
			return null;

		return _messages.PopFront();
	}

	public void ClearBuffer()
	{
		_buffer.Clear();
	}

	public Result<void, bool> ReadData(Span<uint8> data)
	{
		switch (System.Text.Encoding.UTF8.DecodeToUTF8(data, _buffer))
		{
		case .Ok:
		case .Err(let err):
			{
				if (err case .FormatError)
					return .Err(false);
			}
		}

		int lastEnd = 0;
		int prevIndex = 0;
		while (prevIndex < _buffer.Length)
		{
			int crPos = _buffer.IndexOf('\n', prevIndex);
			if (crPos > 0)
			{
				if (_buffer[crPos - 1] != '\\')
				{
					String msg = new String(_buffer, lastEnd, crPos - lastEnd);
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
		return .Ok;
	}
}

class IPCServer
{
	const int32 BUFFER_SIZE = 1024;
	const String NAME = "FU_MQTTStatus";

	bool _pipeConnected;
	Windows.Handle _pipeHandle ~ _.Close();

	public using append MessageHandler _msgHandler;

	public static readonly String s_pipeName = String.ConstF(@$"\\.\pipe\{NAME}");

	public Result<void> Init()
	{
		SECURITY_ATTRIBUTES sa = .(){
			nLength = sizeof(SECURITY_ATTRIBUTES),
			bInheritHandle = true
		};
		SECURITY_DESCRIPTOR sd;

		InitializeSecurityDescriptor(&sd, SECURITY_DESCRIPTOR_REVISION);
		SetSecurityDescriptorDacl(&sd, true, null, false); // Grants access to everyone
		sa.lpSecurityDescriptor = &sd;

		_pipeHandle = Windows.CreateNamedPipeA(s_pipeName,
			Windows.PIPE_ACCESS_DUPLEX,       // read/write access 
			Windows.PIPE_TYPE_MESSAGE |       // message type pipe 
			Windows.PIPE_READMODE_MESSAGE |   // message-read mode 
			Windows.PIPE_NOWAIT,
			1, // max. instances  
			BUFFER_SIZE,              // output buffer size 
			BUFFER_SIZE,              // input buffer size 
			0 /*NMPWAIT_USE_DEFAULT_WAIT*/, // client time-out 
			(.)&sa);

		if (_pipeHandle.IsInvalid)
		{
			int32 lastError = Windows.GetLastError();
			Log.Error(scope $"[IPCServer] Failed to create read named pipe ({lastError})");
			return .Err;
		}

		return .Ok;
	}

	Result<void> Connect()
	{
		if (_pipeConnected)
			return .Ok;

		if (!Windows.ConnectNamedPipe(_pipeHandle, null))
		{
			int32 lastError = Windows.GetLastError();

			if ((lastError != Windows.ERROR_PIPE_CONNECTED) && (lastError != Windows.ERROR_NO_DATA))
				return .Err;
		}
		_pipeConnected = true;
		return .Ok;
	}

	public Result<void> Send(StringView msg)
	{
		Try!(Connect());

		if (Windows.WriteFile(_pipeHandle, (uint8*)msg.Ptr, (int32)msg.Length, let written, null) == 0)
		{
			const int ERROR_BAD_PIPE = 0xE6;
			const int ERROR_NO_DATA = 0xE8;
			const int ERROR_PIPE_NOT_CONNECTED = 0xE9;

			let err = Windows.GetLastError();
			Log.Error(scope $"[IPCServer] Win32 WriteFile failed err: (0x{err:X})");

			switch(err)
			{
			case ERROR_BAD_PIPE:
			case ERROR_NO_DATA:
			case ERROR_PIPE_NOT_CONNECTED:
				_pipeConnected = false;
				return .Err;
			}

			return .Err;
		}

		return .Ok;
	}

	public Result<void> Update()
	{
		Try!(Connect());

		uint8[1024] buffer = default;

		int32 bytesRead;
		int32 result = Windows.ReadFile(_pipeHandle, &buffer, buffer.Count, out bytesRead, null);
		if ((result <= 0) || (bytesRead == 0))
		{
			int32 lastError = Windows.GetLastError();
			if (lastError == Windows.ERROR_BROKEN_PIPE)
			{
				_pipeConnected = false;
				Windows.DisconnectNamedPipe(_pipeHandle);
			}

			return .Err;
		}

		Try!(ReadData(.(&buffer, bytesRead)));
		return .Ok;
	}
}

class IPCClient
{
	bool _pipeConnected;
	Windows.Handle _pipeHandle ~ _.Close();
	public using append MessageHandler _msgHandler;

	Result<void> Connect()
	{
		if (_pipeConnected)
			return .Ok;

		_pipeHandle = Windows.CreateFileA(IPCServer.s_pipeName, Windows.FILE_READ_DATA | Windows.FILE_WRITE_DATA, .None, null, .Open, Windows.FILE_FLAG_OVERLAPPED, .NullHandle);
		if (_pipeHandle.IsInvalid)
		{
			let err = Windows.GetLastError();
			if (err != Windows.ERROR_FILE_NOT_FOUND)
				Log.Error(scope $"[IPCClient] Win32 CreateFile '{IPCServer.s_pipeName}' failed ({err})");

			return .Err;
		}

		_pipeConnected = true;
		return .Ok;
	}

	public Result<void> Send(StringView msg)
	{
		Try!(Connect());
		if (Windows.WriteFile(_pipeHandle, (uint8*)msg.Ptr, (int32)msg.Length, let written, null) == 0)
		{
			const int ERROR_BAD_PIPE = 0xE6;
			const int ERROR_NO_DATA = 0xE8;
			const int ERROR_PIPE_NOT_CONNECTED = 0xE9;

			let err = Windows.GetLastError();
			Log.Error(scope $"[IPCClient] Win32 WriteFile failed err: (0x{err:X})");

			switch(err)
			{
			case ERROR_NO_DATA:

			case ERROR_BAD_PIPE, ERROR_PIPE_NOT_CONNECTED:
				_pipeHandle.Close();
				_pipeHandle = default;
				_pipeConnected = false;
				return .Err;
			}

			return .Err;
		}

		return .Ok;
	}

	public Result<bool> Update(bool peekFirst = true)
	{
		Try!(Connect());

		uint32 bytesAval = 0;
		if (peekFirst && PeekNamedPipe(_pipeHandle, null, 0, null , &bytesAval, null) && bytesAval == 0)
			return .Ok(false);

		uint8[1024] buffer = default;
		int32 bytesRead;

		int32 result = Windows.ReadFile(_pipeHandle, &buffer, buffer.Count, out bytesRead, null);
		if ((result <= 0) || (bytesRead == 0))
		{
			int32 lastError = Windows.GetLastError();
			if (lastError == Windows.ERROR_BROKEN_PIPE)
			{
				_pipeHandle.Close();
				_pipeHandle = default;
				_pipeConnected = false;
			}
			return .Err;
		}

		Try!(_msgHandler.ReadData(.(&buffer, bytesRead)));
		return .Ok(true);
	}
}