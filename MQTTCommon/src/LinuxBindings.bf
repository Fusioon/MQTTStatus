#if BF_PLATFORM_LINUX

using System;
using System.Interop;

namespace MQTTCommon.Linux;

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

static
{
	[Import("libsystemd.so"), LinkName("sd_bus_get_property_trivial")]
	public static extern c_int SdBusGetPropertyTrivial(Linux.DBus *bus, c_char* destination,
		c_char* path,
		c_char* _interface,
		c_char* member,
		Linux.DBusErr* ret_error,
		Linux.DBusType type,
		void* ret_ptr);

	[Import("libsystemd.so"), LinkName("sd_bus_get_property_string")]
	public static extern c_int SdBusGetPropertyString(Linux.DBus *bus, 
		c_char* destination,
		c_char* path,
		c_char* _interface,
		c_char* member,
		Linux.DBusErr* ret_error,
		c_char** ret);

	[Import("libsystemd.so"), LinkName("sd_bus_get_property")]
	public static extern c_int SdBusGetProperty(Linux.DBus *bus, 
		c_char* destination,
		c_char* path,
		c_char* _interface,
		c_char* member,
		Linux.DBusErr* ret_error,
		Linux.DBusMsg** reply,
		c_char* type);


	[Import("libsystemd.so"), LinkName("sd_bus_slot_unref")]
	public static extern Linux.DBusSlot* SdBusSlotUnref(Linux.DBusSlot* slot);

	[Import("libsystemd.so"), LinkName("sd_bus_add_match")]
	public static extern c_int SdBusAddMatch(Linux.DBus* bus, Linux.DBusSlot** slot, c_char* match, function c_int(Linux.DBusMsg* msg, void* userdata, Linux.DBusErr* retError), void* userdata);


	[Import("libsystemd.so"), LinkName("sd_bus_request_name")]
	public static extern c_int SdBusRequestName(Linux.DBus* bus, c_char* name, uint64 flags);

	public static Result<void> SdBusCall(Linux.DBus* dbus, String destination, String path, String iface, String member, Linux.DBusMsg** reply)
	{
		Linux.DBusErr error = default;
		let result = Linux.SdBusCallMethod(dbus, destination.CStr(), path.CStr(), iface.CStr(), member.CStr(), &error, reply, "");

		if (result< 0)
		{
			let name = StringView (error.name);
			let message = StringView (error.message);
			Log.Error(scope $"DBus failed to call '{name}' ({message})");
			Linux.SdBusErrorFree(&error);
			return .Err;
		}

		return .Ok;
	}

	public static Result<void> SdBusCallArgs<Args>(Linux.DBus* dbus, String destination, String path, String iface, String member, Linux.DBusMsg** reply, String types, params Args args) where Args : Tuple
	{
		Linux.DBusErr error = default;
		let result = Linux.SdBusCallMethod(dbus, destination.CStr(), path.CStr(), iface.CStr(), member.CStr(), &error, reply, types.CStr(), params args);

		if (result < 0)
		{
			let name = StringView (error.name);
			let message = StringView (error.message);
			Log.Error(scope $"DBus failed to call '{name}' ({message})");
			Linux.SdBusErrorFree(&error);
			return .Err;
		}

		return .Ok;
	}

	[AllowDuplicates]
	public enum SigNum : c_int
	{
	    /// <summary>
	    /// Hangup detected on controlling terminal or death of controlling process.
	    /// </summary>
	    SIGHUP = 1,

	    /// <summary>
	    /// Interrupt from keyboard (Ctrl+C).
	    /// </summary>
	    SIGINT = 2,

	    /// <summary>
	    /// Quit from keyboard (Ctrl+\).
	    /// </summary>
	    SIGQUIT = 3,

	    /// <summary>
	    /// Illegal Instruction.
	    /// </summary>
	    SIGILL = 4,

	    /// <summary>
	    /// Trace/breakpoint trap.
	    /// </summary>
	    SIGTRAP = 5,

	    /// <summary>
	    /// Abort signal from abort().
	    /// </summary>
	    SIGABRT = 6,

	    /// <summary>
	    /// IOT trap. A synonym for SIGABRT.
	    /// </summary>
	    SIGIOT = 6,

	    /// <summary>
	    /// Bus error (bad memory access).
	    /// </summary>
	    SIGBUS = 7,

	    /// <summary>
	    /// Floating-point exception.
	    /// </summary>
	    SIGFPE = 8,

	    /// <summary>
	    /// Kill signal. Cannot be caught or ignored.
	    /// </summary>
	    SIGKILL = 9,

	    /// <summary>
	    /// User-defined signal 1.
	    /// </summary>
	    SIGUSR1 = 10,

	    /// <summary>
	    /// Invalid memory reference (Segmentation Fault).
	    /// </summary>
	    SIGSEGV = 11,

	    /// <summary>
	    /// User-defined signal 2.
	    /// </summary>
	    SIGUSR2 = 12,

	    /// <summary>
	    /// Broken pipe: write to pipe with no readers.
	    /// </summary>
	    SIGPIPE = 13,

	    /// <summary>
	    /// Timer signal from alarm().
	    /// </summary>
	    SIGALRM = 14,

	    /// <summary>
	    /// Termination signal.
	    /// </summary>
	    SIGTERM = 15,

	    /// <summary>
	    /// Stack fault on coprocessor (mostly unused/reserved).
	    /// </summary>
	    SIGSTKFLT = 16,

	    /// <summary>
	    /// Child stopped or terminated.
	    /// </summary>
	    SIGCHLD = 17,

	    /// <summary>
	    /// Continue if stopped.
	    /// </summary>
	    SIGCONT = 18,

	    /// <summary>
	    /// Stop process. Cannot be caught or ignored.
	    /// </summary>
	    SIGSTOP = 19,

	    /// <summary>
	    /// Stop typed at terminal (Ctrl+Z).
	    /// </summary>
	    SIGTSTP = 20,

	    /// <summary>
	    /// Terminal input for background process.
	    /// </summary>
	    SIGTTIN = 21,

	    /// <summary>
	    /// Terminal output for background process.
	    /// </summary>
	    SIGTTOU = 22,

	    /// <summary>
	    /// Urgent condition on socket.
	    /// </summary>
	    SIGURG = 23,

	    /// <summary>
	    /// CPU time limit exceeded.
	    /// </summary>
	    SIGXCPU = 24,

	    /// <summary>
	    /// File size limit exceeded.
	    /// </summary>
	    SIGXFSZ = 25,

	    /// <summary>
	    /// Virtual alarm clock.
	    /// </summary>
	    SIGVTALRM = 26,

	    /// <summary>
	    /// Profiling timer expired.
	    /// </summary>
	    SIGPROF = 27,

	    /// <summary>
	    /// Window resize signal.
	    /// </summary>
	    SIGWINCH = 28,

	    /// <summary>
	    /// I/O now possible.
	    /// </summary>
	    SIGIO = 29,

	    /// <summary>
	    /// Pollable event (Synonym for SIGIO).
	    /// </summary>
	    SIGPOLL = 29,

	    /// <summary>
	    /// Power failure.
	    /// </summary>
	    SIGPWR = 30,

	    /// <summary>
	    /// Bad system call.
	    /// </summary>
	    SIGSYS = 31
	}

	[CRepr]
	public struct sigaction_t
	{
		typealias sigset_t = c_uint;
		typealias pid_t = c_uint;
		typealias uid_t = c_uint;
		[CRepr]
		public struct siginfo_t
		{
			public c_int		si_signo;  /* Signal number */
			public c_int		si_code;   /* Signal code */
			public pid_t		si_pid;    /* Sending process ID */
			public uid_t		si_uid;    /* Real user ID of sending process */
			public void* 		si_addr;   /* Memory location which caused fault */
			public c_int		si_status; /* Exit value or signal */
			[CRepr, Union]
			public struct
			{
				public c_int 		sigval_int;
				public void* 		sigval_ptr;
			} 					si_value;  /* Signal value */
		}

		public enum Flags : c_int
		{
			/// <summary>
			/// Default behavior (no flags set).
			/// </summary>
			None = 0,

			/// <summary>
			/// If Signum is SIGCHLD, do not receive notification when child processes stop 
			/// (i.e., when they receive SIGSTOP, SIGTSTP, SIGTTIN, or SIGTTOU).
			/// </summary>
			SA_NOCLDSTOP = 0x00000001,

			/// <summary>
			/// If Signum is SIGCHLD, do not transform children into zombies when they terminate. 
			/// Wait() is not required to clean them up.
			/// </summary>
			SA_NOCLDWAIT = 0x00000002,

			/// <summary>
			/// The signal handler takes three arguments (sa_sigaction) instead of one (sa_handler).
			/// This is crucial for receiving context info like which PID sent the signal.
			/// </summary>
			SA_SIGINFO = 0x00000004,

			/// <summary>
			/// (Legacy) Element used to restore register state. Generally handled by libc.
			/// </summary>
			SA_RESTORER = 0x04000000,

			/// <summary>
			/// Call the signal handler on an alternate signal stack provided by sigaltstack(2).
			/// If an alternate stack is not available, the default stack is used.
			/// </summary>
			SA_ONSTACK = 0x08000000,

			/// <summary>
			/// Provide behavior compatible with BSD signal semantics by making certain system calls 
			/// restartable across signals.
			/// </summary>
			SA_RESTART = 0x10000000,

			/// <summary>
			/// Do not prevent the signal from being received from within its own signal handler.
			/// (Normally, the signal is blocked while the handler runs).
			/// Synonym: SA_NOMASK.
			/// </summary>
			SA_NODEFER = 0x40000000,

			/// <summary>
			/// Restore the signal action to the default state once the signal handler has been called.
			/// Synonym: SA_ONESHOT.
			/// </summary>
			SA_RESETHAND = 0x80000000
		}


		public function void(SigNum signum) sa_handler;
		public sigset_t sa_mask;
		public Flags sa_flags;
		public function void(SigNum signum, siginfo_t* info, void*) sa_sigaction;
		public function void() sa_restorer;
	}

	[CLink]
	public static extern c_int sigaction(SigNum signum, sigaction_t* act, sigaction_t* oldact);
}

#endif // BF_PLATFORM_LINUX