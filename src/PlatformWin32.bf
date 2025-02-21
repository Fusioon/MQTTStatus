#if BF_PLATFORM_WINDOWS

using System;

using MQTTStatus.Win32;
using System.IO;

namespace MQTTStatus;

class PlatformWin32 : PlatformOS
{
	const String SERVICE_NAME = "FuMQTT";

	const GUID GUID_CONSOLE_DISPLAY_STATE = .(0x6fe69556, 0x704a, 0x47a0, .(0x8f, 0x24, 0xc2, 0x8d, 0x93, 0x6f, 0xda, 0x47));

	static Self sInstance;

	SERVICE_STATUS _serviceStatus;
	SERVICE_STATUS_HANDLE _hStatus;
	bool _debug;
	Config _cfg;

	volatile bool _running = false;

	public override bool Update(double deltaTime)
	{
		/*const int SC_MONITORPOWER = 0xF170;

		MSG msg = default;
		//PeekMessageW(&msg, null, 0, 0)
		if (GetMessageW(&msg, 0, 0, 0) > 0)
		{
			if (msg.message == WM_SYSCOMMAND && (msg.wParam & 0xFFF0) == SC_MONITORPOWER)
			{
				bool on = msg.lParam == -1;
				SendEvent(.MonitorPower(on));
			}
		}*/
		System.Threading.Thread.Sleep(1000);

		if (_serviceStatus.dwWaitHint != 0 && _serviceStatus.dwCurrentState == SERVICE_RUNNING)
		{
			_serviceStatus.dwWaitHint = (.)Math.Max(0, _serviceStatus.dwWaitHint - deltaTime);
			SetServiceStatus(_hStatus, &_serviceStatus);
		}
		
		return _running;
	}

	protected override void QueryUserState()
	{
		const int SESSION_ID_NONE = 0xFFFFFFFF;
		let sessionId = WTSGetActiveConsoleSessionId();
		if (sessionId == SESSION_ID_NONE)
		{
			SendEvent(.Logout);
			return;
		}

		String username = scope .();
		GetUsername(sessionId, username);
		SendEvent(.Login(username));
	}

	protected override void QueryMonitorState()
	{
		const int SPI_GETSCREENSAVEACTIVE = 0x0010;
		let powerSaveEnabled = SystemParametersInfoW(SPI_GETSCREENSAVEACTIVE, 0, null, 0);
		SendEvent(.MonitorPower(!powerSaveEnabled));
	}

	bool IsUserAdmin()
	{
		Windows.IntBool isAdmin = false;
		PSID adminGroup = 0;

		// Create a SID for the Administrators group
		SID_IDENTIFIER_AUTHORITY NtAuthority = .{Value = .(0,0,0,0,0,5)};

		if (AllocateAndInitializeSid(&NtAuthority, 2, SECURITY_BUILTIN_DOMAIN_RID,
		    DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0, &adminGroup))
		{

				defer  FreeSid(adminGroup);
			    // Check if the current process's token contains the admin group
			    if (!CheckTokenMembership(0, adminGroup, &isAdmin)) {
			        isAdmin = false;
			    }
		}
		return isAdmin;
	}

	mixin CheckAdminRightsReturn(String error)
	{
		if (!IsUserAdmin())
		{
			Log.Error(error);
			return 2;
		}
	}

	int32 InstallService()
	{
		CheckAdminRightsReturn!("Application requires administrator rights to add/install service.");

		let schSCManager = OpenSCManagerW(null, null, SC_MANAGER_CREATE_SERVICE);
		if (schSCManager == 0)
		{
			Log.Error(scope $"OpenSCManager failed ({Windows.GetLastError()})");
			return 1;
		}
		defer CloseServiceHandle(schSCManager);

		String exePath = scope .();
		Environment.GetExecutableFilePath(exePath);

		let serviceNameWStr = SERVICE_NAME.ToScopedNativeWChar!();

		let schService = CreateServiceW(
		    schSCManager,
		    serviceNameWStr,
		    serviceNameWStr,
		    SERVICE_ALL_ACCESS,
		    SERVICE_WIN32_OWN_PROCESS,
		    SERVICE_AUTO_START,
		    SERVICE_ERROR_NORMAL,
		    exePath.ToScopedNativeWChar!(),
		    null, null, null, null, null
		);

		if (schService == 0)
		{
			Log.Error(scope $"Failed to create service ({Windows.GetLastError()})");
			return 1;
		}

		Log.Success("Service registered");
		CloseServiceHandle(schService);
		return 0;
	}

	int32 UninstallService()
	{
		CheckAdminRightsReturn!("Application requires administrator rights to remove/uninstall service.");

		let schSCManager = OpenSCManagerW(null, null, SC_MANAGER_ALL_ACCESS);
		if (schSCManager == 0)
		{
			Log.Error(scope $"OpenSCManager failed ({Windows.GetLastError()})");
			return 1;
		}
		defer CloseServiceHandle(schSCManager);

		let schService = OpenServiceW(schSCManager, SERVICE_NAME.ToScopedNativeWChar!(), DELETE);
		if (schService == 0)
		{
			Log.Error(scope $"OpenService failed ({Windows.GetLastError()})");
			return 1;
		}
		defer CloseServiceHandle(schService);

	    if (!DeleteService(schService))
		{
			Log.Error(scope $"DeleteService failed ({Windows.GetLastError()})");
			return 1;
		}

		Log.Success("Service removed");
		return 0;
	}

	static uint32 ServiceControlHandler(uint32 control, uint32 eventType, void* eventData, void* context)
	{
		Log.Info(scope $"Event {control} {eventType} {eventData} {context}");

		if (let _this = Internal.UnsafeCastToObject(context) as Self)
		{
			return _this.ControlHandler(control, eventType, eventData);
		}

		return 0;
	}

	[Comptime(ConstEval=true)]
	static String GetCallerMemberName(String CallerMemberName = Compiler.CallerMemberName) => CallerMemberName;

	static void ServiceMain(uint32 argc, char16** argv)
	{
		Log.Trace(GetCallerMemberName());

		let _this = sInstance;
		sInstance = null;
		_this.Main();
	}

	void Main()
	{
		Log.Trace(GetCallerMemberName());

		_serviceStatus = .(){
			dwServiceType = SERVICE_WIN32_OWN_PROCESS,
			dwCurrentState = SERVICE_START_PENDING,
			dwControlsAccepted = SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_SESSIONCHANGE | SERVICE_ACCEPT_PRESHUTDOWN | SERVICE_ACCEPT_POWEREVENT,
			dwWin32ExitCode = 0,
			dwServiceSpecificExitCode = 0,
			dwCheckPoint = 0,
			dwWaitHint = 0,
		};

		if (!_debug)
		{
			_hStatus = RegisterServiceCtrlHandlerExW(SERVICE_NAME.ToScopedNativeWChar!(), => ServiceControlHandler, Internal.UnsafeCastToPtr(this));
			if (_hStatus == 0)
			{
				Log.Error(scope $"RegisterServiceCtrlHandlerEx failed ({Windows.GetLastError()})");
				return;
			}

			var guid = GUID_CONSOLE_DISPLAY_STATE;

			if (RegisterPowerSettingNotification(_hStatus, &guid, 1) == 0)
			{
				Log.Error(scope $"RegisterPowerSettingNotification failed ({Windows.GetLastError()})");
			}

			_serviceStatus.dwCurrentState = SERVICE_RUNNING;
			SetServiceStatus(_hStatus, &_serviceStatus);
		}

		Log.Success("Service started");

		_running = true;
		if (base.Run(_cfg) case .Err)
		{
			_serviceStatus.dwWin32ExitCode = 1;
		}

		if (!_debug)
		{
			_serviceStatus.dwCurrentState = SERVICE_STOPPED;
			SetServiceStatus(_hStatus, &_serviceStatus);
		}
		
		Log.Success("Service stopped");
	}

	bool GetUsername(uint32 sessionId, String buffer)
	{
		char16* pUserName = null;
		uint32 bytesReturned = 0;
		if (WTSQuerySessionInformationW(WTS_CURRENT_SERVER, sessionId, .WTSUserName, &pUserName, &bytesReturned))
		{
			buffer.Append(Span<char16>(pUserName, bytesReturned / sizeof(char16)));
			WTSFreeMemory(pUserName);
			return true;
		}

		return false;
	}

	uint32 ControlHandler(uint32 control, uint32 eventType, void* eventData)
	{
		switch (control)
		{
		case SERVICE_CONTROL_INTERROGATE:
		case SERVICE_CONTROL_STOP:
			{
				_serviceStatus.dwCurrentState = SERVICE_STOP_PENDING;
				SetServiceStatus(_hStatus, &_serviceStatus);
				_running = false;
			}
		case SERVICE_CONTROL_PRESHUTDOWN:
			{
				SendEvent(.Shutdown);
				_running = false;
			}

		case SERVICE_CONTROL_POWEREVENT:
			{
				switch (eventType)
				{
				case PBT_POWERSETTINGCHANGE:
					{
						let pbs = (POWERBROADCAST_SETTING*)eventData;

						/*String guid = scope $"0x{pbs.PowerSetting.data:x}, 0x{pbs.PowerSetting.data2:x}, {pbs.PowerSetting.data3:x}";
						for (int32 i < pbs.PowerSetting.data4.Count)
						{
							guid.Append(", ");
							guid.AppendF($"0x{pbs.PowerSetting.data4[i]:x}");
						}

						Log.Info(scope $"PowerEvent PBT_POWERSETTINGCHANGE GUID: ({guid})");*/

						if (pbs.PowerSetting == GUID_CONSOLE_DISPLAY_STATE)
						{
							let displayState = *(uint32*)&pbs.Data;
							bool on = displayState != 0;
							SendEvent(.MonitorPower(on));
						}
					}
				case PBT_APMSUSPEND, PBT_APMSTANDBY:
					{
						SendEvent(.Shutdown);
					}
				case PBT_APMRESUMEAUTOMATIC:
					{
						SendEvent(.PowerOn);
					}
				}
			}

		case SERVICE_CONTROL_SESSIONCHANGE:
			{
				let sessionNotification = (WTSSESSION_NOTIFICATION*)eventData;

				switch (eventType)
				{
				case WTS_SESSION_LOGON:
					{
						String username = scope .();
						GetUsername(sessionNotification.dwSessionId, username);
						SendEvent(.Login(username));
					}
				case WTS_SESSION_LOGOFF:
					{
						SendEvent(.Logout);
					}
				case WTS_SESSION_LOCK:
					{
						SendEvent(.Locked);
					}
				case WTS_SESSION_UNLOCK:
					{
						String username = scope .();
						GetUsername(sessionNotification.dwSessionId, username);
						SendEvent(.Unlocked(username));
					}
				}
			}

		default:
			{
				return ERROR_CALL_NOT_IMPLEMENTED;
			}
		}

		return NO_ERROR;
	}

	public override int32 Start(EServiceOptions serviceOpts, bool debug, Config cfg)
	{
		switch (serviceOpts)
		{
		case .Install:
			{
				return InstallService();
			}
		case .Uninstall:
			{
				return UninstallService();
			}
		case .None:
			{
				Runtime.Assert(sInstance == null);
				sInstance = this;
				_cfg = cfg;

				_debug = debug;
				if (!debug)
				{
					SERVICE_TABLE_ENTRYW[2] serviceTable = .(.{
						lpServiceName = SERVICE_NAME.ToScopedNativeWChar!(),
						lpServiceProc = => ServiceMain
					}, default);
					Log.Trace("StartServiceCtrlDispatcher");
					StartServiceCtrlDispatcherW(&serviceTable);
					return 0;
				}

				ServiceMain(0, null);
				return 0;
			}
		}
	}
}

#endif // BF_PLATFORM_WINDOWS