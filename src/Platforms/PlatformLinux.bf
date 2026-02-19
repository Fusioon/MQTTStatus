#if BF_PLATFORM_LINUX

using System;
using System.Interop;
using System.Collections;
using System.IO;

using MQTTCommon;
using MQTTCommon.Linux;

namespace MQTTStatus;

class PlatformLinux : PlatformOS
{
	const int F_DUPFD_CLOEXEC = 1030;

	[CLink]
	static extern c_int fcntl(c_int fd, c_int op, ...);

	[CLink]
	static extern c_int close(c_int fd);

	Linux.DBus* _systemDbus ~ Linux.SdBusUnref(_);
	Linux.DBusSlot* _shutdownSlot ~ SdBusSlotUnref(_);
	Linux.DBusSlot* _sleepSlot ~ SdBusSlotUnref(_);


	public override Result<void> Install()
	{
		return default;
	}

	public override Result<void> Uninstall()
	{
		return default;
	}

	public override int32 Start(bool debug)
	{
		return Run() case .Ok ? 0 : 1;
	}

	
	protected override Result<void> Run()
	{
		if (!Linux.IsSystemdAvailable)
		{
			Log.Error("systemd not available");
			return .Err;
		}

		if (Linux.SdBusOpenSystem(&_systemDbus) < 0) 
		{
			Log.Error(scope $"DBus failed to open system");
			return .Err;
		}

		if (_systemDbus == null) 
		{
			Log.Error(scope $"DBus System connection is NULL");
			return .Err;
		}

		let inhibitLockFD = {

			Linux.DBusErr error = default;
			Linux.DBusMsg* reply = default;
			if (Linux.SdBusCallMethod(_systemDbus,
				"org.freedesktop.login1",           // Service
			    "/org/freedesktop/login1",          // Object path
			    "org.freedesktop.login1.Manager",   // Interface
			    "Inhibit",                          // Method
				&error,
				&reply,
				"ssss",
				"shutdown".CStr(),
				Compiler.ProjectName.CStr(),
				"Cleanup".CStr(),
				"delay".CStr()
				) < 0)
			{
				Log.Error("Failed to acquire inhibit lock");
				return .Err;
			}
			defer Linux.SdBusMessageUnref(reply);

			int32 fd = ?;
			if (Linux.SdBusMessageReadBasic(reply, .UnixFD, &fd) < 0)
			{
				Log.Error("Failed to read fd for inhibit lock");
				return .Err;
			}

			fcntl(fd, F_DUPFD_CLOEXEC, 3)
		};
		defer close(inhibitLockFD);

		if (Linux.SdBusMatchSignal(_systemDbus, 
			&_shutdownSlot, 
			"org.freedesktop.login1", 
			"/org/freedesktop/login1", 
			"org.freedesktop.login1.Manager", 
			"PrepareForShutdown", (m, userdata, err) => {
				int32 start = ?;
				if (Linux.SdBusMessageReadBasic(m, .Bool, &start) < 0)
				{
					Log.Error("Failed to read 'PrepareForShutdown' start value");
					return 0;
				}
				let _this = (Self)Internal.UnsafeCastToObject(userdata);
				_this.OnShutdown(start != 0);
				return 0;
			}, Internal.UnsafeCastToPtr(this)) < 0) 
			{
				Log.Error("Failed to add signal handler for PrepareForShutdown");
			}

		if (Linux.SdBusMatchSignal(
			_systemDbus,
            null,                               // Slot (optional)
            "org.freedesktop.login1",           // Sender
            "/org/freedesktop/login1",          // Path (Manager object)
            "org.freedesktop.login1.Manager",   // Interface
            "SessionNew",                       // Member
			(m, userdata, ret_error) => {  },
			Internal.UnsafeCastToPtr(this)) < 0)
		{

		}

		return base.Run();
	}



	protected override void QueryUserState()
	{
		/*Linux.DBusMsg* responseMsg = null;
		TrySilent!(SdBusCall(_userDbus, "org.freedesktop.ScreenSaver", "/org/freedesktop/ScreenSaver", "org.freedesktop.ScreenSaver", "GetActive", &responseMsg));
		defer Linux.SdBusMessageUnref(responseMsg);

		int32 result = 0;
		if (Linux.SdBusMessageReadBasic(responseMsg, .Bool, &result) < 0) {
			Log.Error("DBus failed to read response for ScreenSaver.GetActive");
			return;
		}
		
		if (result != 0)
		{
			this.SendEvent(.Locked);
			return;
		}

		char8[256] nameBuffer = default;
		StringView userName;
		// @TODO - replace with login1 dbus 
		if (getlogin_r(&nameBuffer, nameBuffer.Count) < 0)
			userName = "unknown";
		else
			userName = .(&nameBuffer);

		this.SendEvent(.Login(userName));*/
	}

	protected override void QueryMonitorState()
	{
		SendEvent(.MonitorPower(true));
	}

	public override void Update(double deltaTime)
	{
		Linux.SdBusWait(_systemDbus, 1000);

		int32 r;
		while ((r = Linux.SdBusProcess(_systemDbus, null)) > 0) 
		{ }
		
		if (r < 0)
			Log.Error(scope $"DBus system process failed ({r})");

	}

	void OnShutdown(bool start)
	{
		Log.Trace(scope $"OnShutdown {start}");
		SendEvent(.Shutdown);
	}

	public override Result<void> HandleClientCommand(eClientCommand cmd)
	{
		return default;
	}
}

#endif