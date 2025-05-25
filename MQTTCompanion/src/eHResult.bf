using System;
using System.Interop;

using MQTTCommon;
using MQTTCommon.Win32;

namespace MQTTCompanion;

enum EHResult : c_long
{
	case S_OK = 0;
	case E_OUTOFMEMORY = 0x8007000EL;
	case E_NOINTERFACE = 0x80004002;
	case CLASS_E_NOAGGREGATION = 0x80040110L;

	public static implicit operator HResult(Self inst)
	{
		return ((.)(c_long)inst);
	}
}

static
{
	public static mixin CheckResult(HResult result, bool allowModeChange = false)
	{
		const int32 RPC_E_CHANGED_MODE = (.)0x80010106L;

		if (result.Failed && (!allowModeChange || result != (.)RPC_E_CHANGED_MODE))
		{
			Log.Error(scope $"0x{((uint32)result):x}");
			return .Err;
		}
	}

	public static mixin CheckResultSilent(HResult result)
	{
		if (result.Failed)
		{
			Log.Error(scope $"0x{((uint32)result):x}");
			return default;
		}
	}

	public static mixin CheckResultVal<T>(Result<T, HResult> result)
	{
		if (result case .Err(let code))
		{
			Log.Error(scope $"0x{((uint32)code):x}");
			return .Err;
		}

		result.Get()
	}
}