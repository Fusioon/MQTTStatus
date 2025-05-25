using System;
namespace MQTTCommon;

class Client_IPCCommands
{
	public const String COMMAND_SEPARATOR = "\n";
	public const String MONITOR_POWERSAVE = "monitor_powersave";
	public const String LOCK_WORKSTATION = "workstation_lock";
	public const String QUIT_COMPANION = "companion_close";
	public const String NOTIFICATION = "notify";
	public const String MEDIA_STOP = "media_pause";
	public const String MEDIA_NEXT = "media_next";
	public const String MEDIA_PREV = "media_prev";
	public const String AUDIO_MUTE = "audio_mute";
	public const String AUDIO_SET_VOLUME = "audio_set_volume";
}

class Server_IPCCommands
{
	public const String AUDIO_VOLUME_CHANGED = "audio_volume_changed";
}