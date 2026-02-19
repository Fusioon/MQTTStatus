#if BF_PLATFORM_LINUX

using System;
using System.Interop;
using System.Collections;
using System.Threading;
using System.IO;

using MQTTCommon;
using MQTTCommon.Linux;

namespace MQTTCompanion;


class PlatformLinux : PlatformOS
{
#region AUTOSTART
	const String AUTOSTART_DATA = Compiler.ReadText("assets/autostart.desktop");
	const String AUTOSTART_TARGETPATH = "~/.config/autostart";

	const String AUTOSTART_FILENAME = Compiler.ProjectName + ".desktop";

	static Result<void> EnableAutostart()
	{
		String  outFilePath = scope .(AUTOSTART_TARGETPATH);
		LinuxPathHelper.MakeAbsolute(outFilePath);

		if (Directory.CreateDirectory(outFilePath) case .Err(let err) && err != .AlreadyExists)
		{
			Log.Error(scope $"Failed to create directory at '{outFilePath}' ({err})");
			return .Err;
		}

		String exePath = scope .(256);
		Environment.GetExecutableFilePath(exePath);
		String contents = scope .(AUTOSTART_DATA.Length + exePath.Length);
		contents.AppendF(AUTOSTART_DATA, exePath);

		Path.Combine(outFilePath, AUTOSTART_FILENAME);
		if (File.WriteAllText(outFilePath, contents) case .Err)
		{
			Log.Error(scope $"Failed to write directory file '{outFilePath}'");
			return .Err;
		}

		Log.Success(scope $"Autostart created '{AUTOSTART_FILENAME}'");
		return .Ok;
	}

	static Result<void> DisableAutostart()
	{
		let outFilePath = Path.Combine(.. scope String(), AUTOSTART_TARGETPATH, AUTOSTART_FILENAME);
		LinuxPathHelper.MakeAbsolute(outFilePath);

		if (File.Delete(outFilePath) case .Err(let err))
		{
			Log.Error(scope $"Failed to delete '{AUTOSTART_FILENAME}' file ({err})");
			return .Err;
		}

		Log.Success(scope $"Autostart removed '{AUTOSTART_FILENAME}'");
		return .Ok;
	}
#endregion

	volatile bool _running;

	Linux.DBus* _userDbus ~ Linux.SdBusUnref(_);
	Linux.DBusSlot* _monitorSleepSlot ~ SdBusSlotUnref(_);
	Linux.DBusSlot* _monitorWakeUp ~ SdBusSlotUnref(_);

	PulseAudio.pa_context* _paContext;
	PulseAudio.pa_mainloop* _paMainloop;

	public ~this()
	{
		if (PulseAudio.IsAvailable && _paContext != null)
		{
			PulseAudio.ContextDisconnect(_paContext);
			PulseAudio.ContextUnref(_paContext);
			PulseAudio.MainLoopFree(_paMainloop);
		}
	}


	public override Result<bool, bool> HandleArg(StringView current, ref Span<String> args)
	{
		return .Err(false);
	}

	public override Result<void> Install()
	{
		Try!(EnableAutostart());

#if WITH_KDE
		Try!(kwinInstaller.Install());
#endif // WITH_KDE

		return .Ok;
	}

	public override Result<void> Uninstall()
	{
#if WITH_KDE
		kwinInstaller.Uninstall().IgnoreError();
#endif // WITH_KDE

		DisableAutostart();

		return .Ok;
	}

	public override Result<void> Init()
	{
		if (!Linux.IsSystemdAvailable)
			return .Err;

		static Self s_instance = null;
		if (s_instance == null)
		{
			s_instance = this;
			_running = true;

			if (sigaction(.SIGTERM, &sigaction_t{
				sa_flags = 0,
				sa_sigaction = null,
				sa_handler = (signum) => {
					s_instance._running = false;
				}
			}, null) != 0)
			{
				Log.Error("Failed to register SIGTERM handler");
				return .Err;
			}	
		}	

		if (Linux.SdBusOpenUser(&_userDbus) < 0) 
		{
			Log.Error(scope $"DBus failed to open user");
			return .Err;
		}

		if (_userDbus == null) 
		{
			Log.Error(scope $"DBus User connection is NULL");
			return .Err;
		}

		
#if WITH_KDE

		if (SdBusRequestName(_userDbus, "org.kde.kwin.ScreenPower", 0) < 0)
			Log.Error("Failed to acquire service 'org.kde.kwin.ScreenPower' name");

		// org.kde.kwin.ScreenPower
		if (SdBusAddMatch(_userDbus, 
			&_monitorSleepSlot, 
			"type='method_call',interface='org.kde.kwin.ScreenPower',member='aboutToTurnOff'",
			(m, userdata, err) => {
				let _this = (Self)Internal.UnsafeCastToObject(userdata);
				//_this.SendEvent(.MonitorPower(false));
				return 0;
			}, Internal.UnsafeCastToPtr(this)) < 0) 
			{
				Log.Error("Failed to add handler for Monitor sleep");
			}



		if (SdBusAddMatch(_userDbus, 
			&_monitorWakeUp, 
			"type='method_call',interface='org.kde.kwin.ScreenPower',member='wakeUp'",
			(m, userdata, err) => {
				let _this = (Self)Internal.UnsafeCastToObject(userdata);
				//_this.SendEvent(.MonitorPower(true));
				return 0;
			}, Internal.UnsafeCastToPtr(this)) < 0) 
			{
				Log.Error("Failed to add handler for Monitor wakeup");
			}

#endif
		if (PulseAudio.IsAvailable)
		{
			_paMainloop = PulseAudio.MainLoopNew();
			let api = PulseAudio.MainLoopGetApi(_paMainloop);
			_paContext = PulseAudio.ContextNew(api, "volume-listener");

			PulseAudio.ContextSetStateCallback(_paContext, (ctx, userdata) => {
				switch (PulseAudio.ContextGetState(ctx))
				{
					case .Ready:
					{
						PulseAudio.OperationUnref(PulseAudio.ContextGetSinkInfoByName(ctx, PulseAudio.DefaultSink, => s_SinkInfoCB, userdata));
						PulseAudio.ContextSetSubscribeCallback(ctx, (ctx, t, idx, userdata) => {
							PulseAudio.OperationUnref(
								PulseAudio.ContextGetSinkInfoByIndex(ctx, idx, => s_SinkInfoCB, userdata)
							);
						}, userdata);
						PulseAudio.OperationUnref(PulseAudio.ContextSetSubscribeCallback(ctx, .Sink, null, null));
					}

					default:
						//Log.Trace((.)ctx);
				}

			}, Internal.UnsafeCastToPtr(this));

			PulseAudio.ContextConnect(_paContext, null, .NoFlags, null);
		}
		else 
		{
			Log.Warning("PulseAudio not available, volume controls won't work");
		}

		return .Ok;
	}

	void SinkInfoCallback(PulseAudio.pa_context context, PulseAudio.pa_sink_info* i, c_int eol)
	{
		if (i.state != .Running)
			return;

		readonly double volume = i.mute == 0 ? (PulseAudio.CVolumeAvg(&i.volume) * 100.0 / PulseAudio.VOLUME_NORM) : 0;
		// this.HandleServerCommand(.AudioVolumeChanged((uint32)Math.Round(volume)));

	}

	static void s_SinkInfoCB(PulseAudio.pa_context context, PulseAudio.pa_sink_info* i, c_int eol, void* userdata)
	{
		if (eol > 0 || i == null)
			return;

		let _this = (Self)Internal.UnsafeCastToObject(userdata);
		_this.SinkInfoCallback(context, i, eol);
	}

	public override int Run()
	{
		
		while (_running)
		{
			Linux.SdBusWait(_userDbus, 1000);

			int32 r;
			while ((r = Linux.SdBusProcess(_userDbus, null)) > 0) 
			{ }

			if (r < 0)
				Log.Error(scope $"DBus user process failed ({r})");

			if (PulseAudio.IsAvailable)
			{
				PulseAudio.MainLoopIterate(_paMainloop, 0, ?);
			}
		}

		return 0;
	}

	Result<void> MonitorPowerSave()
	{
		return SdBusCallArgs(_userDbus, "org.kde.kglobalaccel", "/component/org_kde_powerdevil", "org.kde.kglobalaccel.Component", "invokeShortcut", null, "s", "Turn Off Screen".CStr());
	}

	Result<void> LockWorkstation()
	{
		return SdBusCall(_userDbus, "org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", "Lock", null);
	}

	Result<void> ToggleAudioMute()
	{
		return SdBusCallArgs(_userDbus, "org.kde.kglobalaccel", "/component/kmix", "org.kde.kglobalaccel.Component", "invokeShortcut", null, "s", "mute".CStr());
	}

	static Result<void> ForEachDBusListName(Linux.DBus* dbus, delegate bool(StringView name) forEach)
	{	
		Linux.DBusMsg* responseMsg = null;
		Try!(SdBusCall(dbus, "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "ListNames", &responseMsg));
		defer Linux.SdBusMessageUnref(responseMsg);

		if (Linux.SdBusMessageEnterContainer(responseMsg, .Array, "s") < 0)
		{
			return .Err;
		}

		c_char* name = null;
		c_int r = 0;
		int count = 0;
		while ((r = Linux.SdBusMessageReadBasic(responseMsg, .String, &name)) > 0)
		{
			count++;
			StringView nameView = .(name);
			if (forEach(nameView) == false)
				break;
		}

		Linux.SdBusMessageExitContainer(responseMsg);

		if (r < 0)
		{
			Log.Error(scope $"Error occured while enumerating DBus ListNames ({r}) enumerated: {count}");
		}

		if (count == 0 && r < 0)
			return .Err;

		return .Ok;	
	}

	enum ePlaybackStatus
	{
		Playing,
		Paused,
		Stopped
	}

	Result<void> ForEachMediaPlayer(delegate bool(StringView name, ePlaybackStatus status) forEach)
	{
		return ForEachDBusListName(_userDbus, scope (name) => {
			const String MPRIS_PREFIX = "org.mpris.MediaPlayer2";
			if (!name.StartsWith(MPRIS_PREFIX))
				return true;

			Linux.DBusErr error = default;
			c_char* playbackStatus = null; 
			if (SdBusGetPropertyString(_userDbus, 
				name.Ptr, 
				"/org/mpris/MediaPlayer2", 
				"org.mpris.MediaPlayer2.Player", 
				"PlaybackStatus", 
				&error,
				&playbackStatus) < 0) 
			{
				let errMsg = StringView(error.message);
				Log.Error(scope $"DBus Failed to retrieve PlaybackStatus for '{name}' ({errMsg})");
				Linux.SdBusErrorFree(&error);
				return true;
			}

			StringView statusView = .(playbackStatus);
			ePlaybackStatus status;
			if (statusView.CompareTo("Playing", true) == 0)
				status = .Playing;
			else if (statusView.CompareTo("Paused", true) == 0)
				status = .Paused;
			else
				status = .Stopped;

			return forEach(name, status);
		});
	}

	enum eMediaControl
	{
		Pause,
		Next,
		Prev
	}

	Result<void> MediaControl(eMediaControl control)
	{
		let methodName = (String){
			String tmp;
			switch (control)
			{
				case .Pause: tmp = "Pause";
				case .Next: tmp = "Next";
				case .Prev: tmp = "Previous";
			}
			tmp
		};

		return ForEachMediaPlayer(scope (name, status) => {
			if (status != .Playing)
				return true;

			Linux.DBusErr error = default;
			if (Linux.SdBusCallMethod(_userDbus, name.Ptr, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", methodName.CStr(), &error, null, "") < 0)
			{
				let errMsg = StringView(error.message);
				Log.Error(scope $"DBus Failed to call {methodName} on '{name}'. ({errMsg})");
				Linux.SdBusErrorFree(&error);
				return true;
			}
			
			return true;
		});
	}

	Result<void> SendNotification(StringView title, StringView text)
	{
		const String APP = Compiler.ProjectName;

		return SdBusCallArgs(_userDbus, "org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "Notify", null, "susssasa{sv}i", 
			APP.CStr(), 0, "".CStr(), title.ToScopeCStr!(), text.ToScopeCStr!(), null, 0, -1
		);
	}

	Result<void> SetAudioVolume(uint32 value)
	{
		if (!PulseAudio.IsAvailable || _paContext == null)
			return .Err;

		PulseAudio.pa_cvolume vol = default;
		PulseAudio.CVolumeSet(&vol, 2, (uint32)(PulseAudio.VOLUME_NORM * (value / 100f)));

		let op = PulseAudio.ContextSetSinkVolumeByName(_paContext, PulseAudio.DefaultSink, &vol, null, null);
		if (op == null)
			return .Err;

		PulseAudio.OperationUnref(op);

		return .Ok;
	}

	public override Result<void> HandleClientCommand(eClientCommand cmd)
	{
		switch (cmd)
		{
			case .MonitorPowersave:
				return MonitorPowerSave();
			case .LockWorkstation:
				return LockWorkstation();
			case .MediaStop:
				return MediaControl(.Pause);
			case .MediaNext:
				return MediaControl(.Next);
			case .MediaPrev:
				return MediaControl(.Prev);
			case .AudioMute:
				return ToggleAudioMute();
			case .AudioSetVolume(let volume):
				return SetAudioVolume(volume);
			case .Notification(let title, let text):
				return SendNotification(title, text);
			case .QuitCompanion:
			{
				_running = false;
				return .Ok;
			}
		}
	}
}

#endif // BF_PLATFORM_LINUX