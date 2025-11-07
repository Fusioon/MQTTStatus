#if BF_PLATFORM_LINUX

#define WITH_KDE

using System;
using System.Interop;
using System.Collections;

using MQTTCommon;

namespace MQTTStatus;

class PlatformLinux : PlatformOS
{
	static class PulseAudio
	{
		public static bool IsAvailable { get; private set; } = true;
		
		public static this()
		{
			Runtime.AddErrorHandler(new => Handle);
		}

		public static Runtime.ErrorHandlerResult Handle(Runtime.ErrorStage errorStage, Runtime.Error error)
		{
			if (errorStage == .PreFail)
			{
				if (var loadLibaryError = error as Runtime.LoadSharedLibraryError)
				{
					if (loadLibaryError.mPath == "libpulse.so")
					{
						IsAvailable = false;
						return .Ignore;
					}
				}
			}
			return .ContinueFailure;
		}


		public struct pa_context;
		public struct pa_mainloop;
		public struct pa_mainloop_api;
		public struct pa_spawn_api;
		public struct pa_operation;
		public struct pa_proplist;

		typealias pa_volume_t = uint32;
		typealias pa_usec_t = uint64;

		public const int CHANNELS_MAX = 32;
		public const pa_volume_t VOLUME_NORM = 0x10000U;

		public const String DefaultSink = "@DEFAULT_SINK@";

		[CRepr]
		public struct pa_cvolume
		{
			public uint8 channels;
			public pa_volume_t[CHANNELS_MAX] values;
		}


		[CRepr]
		public struct pa_channel_map
		{
			public uint8 channels;
			public ChannelPosition[CHANNELS_MAX] map;
		} 

		[CRepr]
		public struct pa_sample_spec
		{
			public SampleFormat format;
			public uint32 rate;
			public uint8 channels;
		}

		[CRepr]
		public struct pa_sink_port_info
		{
			public c_char* name;                   
			public c_char* description;            
			public uint32 priority;          
		}

		[CRepr]
		public struct pa_sink_info
		{
			public c_char* name;                  
			public uint32 index;                    
			public c_char* description;           
			public pa_sample_spec sample_spec;        
			public pa_channel_map channel_map;        
			public uint32 owner_module;             
			public pa_cvolume volume;                 
			public c_int mute;                          
			public uint32 monitor_source;           
			public c_char* monitor_source_name;   
			public pa_usec_t latency;                 
			public c_char* driver;                
			public SinkFlags flags;             
			public pa_proplist *proplist;             
			public pa_usec_t configured_latency;      
			public pa_volume_t base_volume;           
			public SinkState state;             
			public uint32 n_volume_steps;           
			public uint32 card;                     
			public uint32 n_ports;                  
			public pa_sink_port_info** ports;         
			public pa_sink_port_info* active_port;    
		}

		public enum ContextFlags : c_int
		{
			NoFlags = 0x0000,
			NoAutospawn = 0x0001,
			NoFail = 0x0002 
		}

		public enum ContextState : c_int
		{
			Unconnected,
			Connecting,
			Authorizing,
			SettingName,
			Ready,
			Failed,
			Terminated
		}

		public enum SubscriptionEventType : c_int
		{
			Sink = 0,           /**< Event type: Sink */
			Source = 1,         /**< Event type: Source */
			Sink_input = 2,     /**< Event type: Sink input */
			Source_output = 3,  /**< Event type: Source output */
			Module = 4,         /**< Event type: Module */
			Client = 5,         /**< Event type: Client */
			Sample_cache = 6,   /**< Event type: Sample cache item */
			Facility_mask = 7,  /**< A mask to extract the event type from an event value */
			#unwarn
			New = 0,            /**< A new object was created */
			Change = 16,        /**< A property of the object was modified */
			Remove = 32,        /**< An object was removed */
			Type_mask = 16+32,  /**< A mask to extract the event operation from an event value */
		}

		public enum SubscriptionMask : c_int
		{
			Null = 0,               /**< No events */
			Sink = 1,               /**< Sink events */
			Source = 2,             /**< Source events */
			Sink_input = 4,         /**< Sink input events */
			Source_output = 8,      /**< Source output events */
			Module = 16,            /**< Module events */
			Client = 32,            /**< Client events */
			Sample_cache = 64,      /**< Sample cache events */
		}

		public enum SampleFormat : c_int
		{
			U8,
			ALAW,
			ULAW,
			S16LE,
			S16BE,
			FLOAT32LE,
			FLOAT32BE,
			S32LE,
			S32BE,
			S24LE,
			S24BE,
			S24_32LE,
			S24_32BE,
			/* Remeber to update
			* https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/SupportedAudioFormats/
			* when adding new formats! */

			MAX,
			INVALID = -1
		}

		[AllowDuplicates]
		public enum ChannelPosition : c_int
		{
			INVALID = -1,
			MONO = 0,
			FRONT_LEFT,               
			FRONT_RIGHT,              
			FRONT_CENTER,             
			LEFT = FRONT_LEFT,
			RIGHT = FRONT_RIGHT,
			CENTER = FRONT_CENTER,
			REAR_CENTER,              
			REAR_LEFT,                
			REAR_RIGHT,               
			LFE,                      
			SUBWOOFER = LFE,
			FRONT_LEFT_OF_CENTER,     
			FRONT_RIGHT_OF_CENTER,    
			SIDE_LEFT,                
			SIDE_RIGHT,               
			AUX0,
			AUX1,
			AUX2,
			AUX3,
			AUX4,
			AUX5,
			AUX6,
			AUX7,
			AUX8,
			AUX9,
			AUX10,
			AUX11,
			AUX12,
			AUX13,
			AUX14,
			AUX15,
			AUX16,
			AUX17,
			AUX18,
			AUX19,
			AUX20,
			AUX21,
			AUX22,
			AUX23,
			AUX24,
			AUX25,
			AUX26,
			AUX27,
			AUX28,
			AUX29,
			AUX30,
			AUX31,
			TOP_CENTER,               
			TOP_FRONT_LEFT,           
			TOP_FRONT_RIGHT,          
			TOP_FRONT_CENTER,         
			TOP_REAR_LEFT,            
			TOP_REAR_RIGHT,           
			TOP_REAR_CENTER,          
			MAX
		}

		public enum SinkFlags : c_int 
		{
			Noflags = 0x0000U,
			Hw_volume_ctrl = 0x0001U,
			Latency = 0x0002U,
			Hardware = 0x0004U,
			Network = 0x0008U,
			Hw_mute_ctrl = 0x0010U,
			Decibel_volume = 0x0020U,
			Flat_volume = 0x0040U,
			Dynamic_latency = 0x0080U 
		}

		public enum SinkState : c_int 
		{
			Invalid_state = -1,
			Running = 0,
			Idle = 1,
			Suspended = 2 
		}

		[Import("libpulse.so"), LinkName("pa_mainloop_new")]
		public static extern pa_mainloop* MainLoopNew();

		[Import("libpulse.so"), LinkName("pa_mainloop_get_api")]
		public static extern pa_mainloop_api* MainLoopGetApi(pa_mainloop* mainloop);

		[Import("libpulse.so"), LinkName("pa_context_new")]
		public static extern pa_context* ContextNew(pa_mainloop_api* api, c_char* name);

		[Import("libpulse.so"), LinkName("pa_context_disconnect")]
		public static extern void ContextDisconnect(pa_context* context);

		[Import("libpulse.so"), LinkName("pa_context_unref")]
		public static extern void ContextUnref(pa_context* context);

		[Import("libpulse.so"), LinkName("pa_mainloop_free")]
		public static extern void MainLoopFree(pa_mainloop* mainloop);

		[Import("libpulse.so"), LinkName("pa_mainloop_iterate")]
		public static extern c_int MainLoopIterate(pa_mainloop* mainloop, c_int block, out c_int retval);

		[Import("libpulse.so"), LinkName("pa_context_set_state_callback")]
		public static extern void ContextSetStateCallback(pa_context* context, function void(pa_context* context, void* userdata) cb, void* userdata);

		[Import("libpulse.so"), LinkName("pa_context_connect")]
		public static extern void ContextConnect(pa_context* context, c_char* server, ContextFlags flags, pa_spawn_api* api);

		[Import("libpulse.so"), LinkName("pa_context_get_state")]
		public static extern ContextState ContextGetState(pa_context* context);

		[Import("libpulse.so"), LinkName("pa_context_set_subscribe_callback")]
		public static extern void ContextSetSubscribeCallback(pa_context* context, function void(pa_context* context, SubscriptionEventType t, uint32 idx, void* userdata) cb, void* userdata);

		[Import("libpulse.so"), LinkName("pa_context_subscribe")]
		public static extern pa_operation* ContextSetSubscribeCallback(pa_context* context, SubscriptionMask m, function void(pa_context context, SubscriptionEventType t, uint32 idx, void* userdata) cb, void* userdata);

		[Import("libpulse.so"), LinkName("pa_context_get_sink_info_by_index")]
		public static extern pa_operation* ContextGetSinkInfoByIndex(pa_context* context, uint32 idx, function void(pa_context context, pa_sink_info* i, c_int eol, void* userdata) cb, void* userdata);

		[Import("libpulse.so"), LinkName("pa_context_get_sink_info_by_name")]
		public static extern pa_operation* ContextGetSinkInfoByName(pa_context* context, c_char* name, function void(pa_context context, pa_sink_info* i, c_int eol, void* userdata) cb, void* userdata);

		[Import("libpulse.so"), LinkName("pa_operation_unref")]
		public static extern void OperationUnref(pa_operation* operation);

		[Import("libpulse.so"), LinkName("pa_cvolume_avg")]
		public static extern pa_volume_t CVolumeAvg(pa_cvolume* a);

		[Import("libpulse.so"), LinkName("pa_cvolume_set")]
		public static extern pa_volume_t CVolumeSet(pa_cvolume* a, c_uint channels, pa_volume_t v);

		[Import("libpulse.so"), LinkName("pa_context_set_sink_volume_by_name")]
		public static extern pa_operation* ContextSetSinkVolumeByName(pa_context* context, c_char* name, pa_cvolume* volume, function void(pa_context* context, c_int success, void* userdata) cb, void* userdata);

	}
	
	[Import("libsystemd.so"), LinkName("sd_bus_get_property_trivial")]
	static extern c_int SdBusGetPropertyTrivial(Linux.DBus *bus, c_char* destination,
		c_char* path,
		c_char* _interface,
		c_char* member,
		Linux.DBusErr* ret_error,
		Linux.DBusType type,
		void* ret_ptr);

	[Import("libsystemd.so"), LinkName("sd_bus_get_property_string")]
	static extern c_int SdBusGetPropertyString(Linux.DBus *bus, 
		c_char* destination,
		c_char* path,
		c_char* _interface,
		c_char* member,
		Linux.DBusErr* ret_error,
		c_char** ret);

	[Import("libsystemd.so"), LinkName("sd_bus_get_property")]
	static extern c_int SdBusGetProperty(Linux.DBus *bus, 
		c_char* destination,
		c_char* path,
		c_char* _interface,
		c_char* member,
		Linux.DBusErr* ret_error,
		Linux.DBusMsg** reply,
		c_char* type);

	
	[Import("libsystemd.so"), LinkName("sd_bus_slot_unref")]
	static extern Linux.DBusSlot* SdBusSlotUnref(Linux.DBusSlot* slot);

	Linux.DBus* _userDbus ~ Linux.SdBusUnref(_);
	Linux.DBusSlot* _lidActionSlot ~ SdBusSlotUnref(_);
	Linux.DBusSlot* _displayAddedSlot ~ SdBusSlotUnref(_);
	Linux.DBusSlot* _displayRemovedSlot ~ SdBusSlotUnref(_);

	Linux.DBus* _systemDbus ~ Linux.SdBusUnref(_);
	Linux.DBusSlot* _shutdownSlot ~ SdBusSlotUnref(_);
	Linux.DBusSlot* _sleepSlot ~ SdBusSlotUnref(_);
	Linux.DBusErr _error;

	PulseAudio.pa_context* _paContext;
	PulseAudio.pa_mainloop* _paMainloop;


	append HashSet<int> _monitors = .(4);

	public ~this()
	{
		if (PulseAudio.IsAvailable)
		{
			PulseAudio.ContextDisconnect(_paContext);
			PulseAudio.ContextUnref(_paContext);
			PulseAudio.MainLoopFree(_paMainloop);
		}
	}

	public override int32 Start(EServiceOptions serviceOpts, bool debug, Config cfg)
	{
		if (serviceOpts == .None)
		{
			if (Run(cfg) case .Ok)
				return 0;

			return 1;
		}

		return 1;
	}

	void SinkInfoCallback(PulseAudio.pa_context context, PulseAudio.pa_sink_info* i, c_int eol)
	{
		if (i.state != .Running)
			return;

		readonly double volume = i.mute == 0 ? (PulseAudio.CVolumeAvg(&i.volume) * 100.0 / PulseAudio.VOLUME_NORM) : 0;
		this.HandleServerCommand(.AudioVolumeChanged((uint32)Math.Round(volume)));

	}

	static void s_SinkInfoCB(PulseAudio.pa_context context, PulseAudio.pa_sink_info* i, c_int eol, void* userdata)
	{
		if (eol > 0 || i == null)
			return;

		let _this = (Self)Internal.UnsafeCastToObject(userdata);
		_this.SinkInfoCallback(context, i, eol);
	}

	protected override Result<void> Run(Config cfg)
	{
		if (!Linux.IsSystemdAvailable)
			return .Err;

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

#if WITH_KDE

		static mixin ReadDisplayName(Linux.DBusMsg* msg)
		{
			c_char* ptr = default;
			if (Linux.SdBusMessageReadBasic(msg, .String, &ptr) < 0)
			{
				Log.Error("Failed to retrieve display name");
			}

			StringView(ptr)
		}

		if (Linux.SdBusMatchSignal(_userDbus, 
			&_displayAddedSlot, 
			"org.kde.ScreenBrightness",
			"/org/kde/ScreenBrightness",
			"org.kde.ScreenBrightness",
			"DisplayAdded", (m, userdata, ret_error) => {
				let name = ReadDisplayName!(m);
				((Self)Internal.UnsafeCastToObject(userdata)).DisplayEvent(true, name);
				return 0;
			}, 
		Internal.UnsafeCastToPtr(this)) < 0)
		{
			Log.Error("Failed to add signal handler for DisplayAdded");
		}

		if (Linux.SdBusMatchSignal(_userDbus, 
			&_displayRemovedSlot, 
			"org.kde.ScreenBrightness",
			"/org/kde/ScreenBrightness",
			"org.kde.ScreenBrightness",
			"DisplayRemoved", (m, userdata, ret_error) => {
				let name = ReadDisplayName!(m);
				((Self)Internal.UnsafeCastToObject(userdata)).DisplayEvent(false, name);
				return 0;
			}, 
		Internal.UnsafeCastToPtr(this)) < 0)
		{
			Log.Error("Failed to add signal handler for DisplayRemoved");
		}

		do 
		{
			Linux.DBusMsg* reply = null;
			if (SdBusGetProperty(_userDbus, 
				"org.kde.Solid.PowerManagement", 
				"/org/kde/ScreenBrightness",
				"org.kde.ScreenBrightness",
				"DisplaysDBusNames",
				&_error,
				&reply, 
				"as") < 0) 
			{
				let name = StringView(_error.name);
				let message = StringView (_error.message);
				Log.Error(scope $"DBus Failed to DisplaysDBusNames container ({name}) ({message})");
				Linux.SdBusErrorFree(&_error);
				break;
			}
			defer Linux.SdBusMessageUnref(reply);

			if (Linux.SdBusMessageEnterContainer(reply, .Array, "s") < 0)
			{
				Log.Error("DBus Failed to enter container for DisplaysDBusNames");
				break;
			}

			c_char* name = null;
			c_int r = 0;
			int count = 0;
			while ((r = Linux.SdBusMessageReadBasic(reply, .String, &name)) > 0)
			{
				count++;
				StringView nameView = .(name);
				let nameHash = nameView.GetHashCode();
				_monitors.Add(nameHash);
			}

			Linux.SdBusMessageExitContainer(reply);
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

		return base.Run(cfg);
	}

	[CLink, CallingConvention(.Stdcall)]
	static extern c_int getlogin_r(c_char* buf, c_size bufsize);

	protected override void QueryUserState()
	{
		Linux.DBusMsg* responseMsg = null;
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

		this.SendEvent(.Login(userName));
	}

	protected override void QueryMonitorState()
	{
		SendEvent(.MonitorPower(_monitors.Count > 0));
	}

	public override void Update(double deltaTime)
	{
		Linux.SdBusWait(_systemDbus, 1000);

		int32 r;
		while ((r = Linux.SdBusProcess(_systemDbus, null)) > 0) 
		{ }
		
		if (r < 0)
			Log.Error(scope $"DBus system process failed ({r})");

		while ((r = Linux.SdBusProcess(_userDbus, null)) > 0) 
		{ }

		if (r < 0)
			Log.Error(scope $"DBus user process failed ({r})");

		if (PulseAudio.IsAvailable)
		{
			PulseAudio.MainLoopIterate(_paMainloop, 0, ?);
		}
	}

	void OnShutdown(bool start)
	{
		Log.Trace(scope $"OnShutdown {start}");
		SendEvent(.Shutdown);
	}

	void DisplayEvent(bool added, StringView name)
	{
		let displayHash = name.GetHashCode();
		if (added)
			_monitors.Add(displayHash);
		else
			_monitors.Remove(displayHash);

		SendEvent(.MonitorPower(_monitors.Count > 0));
	}
	
	Result<void> SdBusCall(Linux.DBus* dbus, String destination, String path, String iface, String member, Linux.DBusMsg** reply)
	{
		let result = Linux.SdBusCallMethod(dbus, destination.CStr(), path.CStr(), iface.CStr(), member.CStr(), &_error, reply, "");

		if (result< 0)
		{
			let name = StringView (_error.name);
			let message = StringView (_error.message);
			Log.Error(scope $"DBus failed to call '{name}' ({message})");
			Linux.SdBusErrorFree(&_error);
			return .Err;
		}

		return .Ok;
	}

	Result<void> SdBusCallArgs<Args>(Linux.DBus* dbus, String destination, String path, String iface, String member, Linux.DBusMsg** reply, String types, params Args args) where Args : Tuple
	{
		let result = Linux.SdBusCallMethod(dbus, destination.CStr(), path.CStr(), iface.CStr(), member.CStr(), &_error, reply, types.CStr(), params args);

		if (result < 0)
		{
			let name = StringView (_error.name);
			let message = StringView (_error.message);
			Log.Error(scope $"DBus failed to call '{name}' ({message})");
			Linux.SdBusErrorFree(&_error);
			return .Err;
		}

		return .Ok;
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

	Result<void> ForEachDBusListName(Linux.DBus* dbus, delegate bool(StringView name) forEach)
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

			c_char* playbackStatus = null; 
			if (SdBusGetPropertyString(_userDbus, 
				name.Ptr, 
				"/org/mpris/MediaPlayer2", 
				"org.mpris.MediaPlayer2.Player", 
				"PlaybackStatus", 
				&_error,
				&playbackStatus) < 0) 
			{
				let errMsg = StringView(_error.message);
				Log.Error(scope $"DBus Failed to retrieve PlaybackStatus for '{name}' ({errMsg})");
				Linux.SdBusErrorFree(&_error);
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

			if (Linux.SdBusCallMethod(_userDbus, name.Ptr, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", methodName.CStr(), &_error, null, "") < 0)
			{
				let errMsg = StringView(_error.message);
				Log.Error(scope $"DBus Failed to call {methodName} on '{name}'. ({errMsg})");
				Linux.SdBusErrorFree(&_error);
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
				this.Shutdown();
		}

		return .Err;
	}

}

#endif