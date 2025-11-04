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

class IPCHelper
{
	public static (StringView cmd, StringView args) SplitMessage(StringView message )
	{
		StringView cmd = message;
		StringView data = default;

		let cmdIndex = message.IndexOf('|');
		if (cmdIndex > 0)
		{
			cmd = message.Substring(0, cmdIndex);
			data = message.Substring(cmdIndex + 1);
		}
		return (cmd, data);
	}
}

enum eClientCommand
{
	case MonitorPowersave;
	case LockWorkstation;
	case QuitCompanion;
	case Notification(StringView title, StringView message);
	case MediaStop;
	case MediaNext;
	case MediaPrev;
	case AudioMute;
	case AudioSetVolume(uint32 volume);

	public static Result<Self> TryParseFromMessage(StringView message)
 	{
		 let (cmd, args) = IPCHelper.SplitMessage(message);
		 return TryParse(cmd, args);
	}

	public static Result<Self> TryParse(StringView cmd, StringView args)
	{
		switch (cmd)
		{
		case Client_IPCCommands.MONITOR_POWERSAVE: return Self.MonitorPowersave;

		case Client_IPCCommands.LOCK_WORKSTATION: return Self.LockWorkstation;

		case Client_IPCCommands.NOTIFICATION:
			{
				StringView title = default;
				StringView msg = args;
				let idx = args.IndexOf('|');
				if (idx > 0)
				{
					title = args.Substring(0, idx);
					msg = args.Substring(idx + 1);
				}

				return Self.Notification(title, msg);
			}

		case Client_IPCCommands.AUDIO_MUTE: return Self.AudioMute;

		case Client_IPCCommands.AUDIO_SET_VOLUME:
			{
				if (uint32.Parse(args) case .Ok(let val))
				{
					return Self.AudioSetVolume(val);
				}
			}
		case Client_IPCCommands.MEDIA_STOP: return Self.MediaStop;

		case Client_IPCCommands.MEDIA_NEXT: return Self.MediaNext;

		case Client_IPCCommands.MEDIA_PREV: return Self.MediaPrev;

		case Client_IPCCommands.QUIT_COMPANION: return Self.QuitCompanion;
		}

		return .Err;
	}

	public static void ToMessage(Self value, String buffer)
	{
		switch (value)
		{
		case .MonitorPowersave: buffer.Append(Client_IPCCommands.MONITOR_POWERSAVE);
		case .LockWorkstation:buffer.Append(Client_IPCCommands.LOCK_WORKSTATION);
		case .Notification(let title, let message):
			{
				buffer.Append(Client_IPCCommands.NOTIFICATION);
				if (title.Length > 0)
				{
					buffer.Append('|');
					buffer.Append(title);
				}
				buffer.Append('|');
				buffer.Append(message);
			}
		case .MediaStop: buffer.Append(Client_IPCCommands.MEDIA_STOP);
		case .MediaNext: buffer.Append(Client_IPCCommands.MEDIA_NEXT);
		case .MediaPrev: buffer.Append(Client_IPCCommands.MEDIA_PREV);
		case .AudioMute: buffer.Append(Client_IPCCommands.AUDIO_MUTE);
		case .AudioSetVolume(let volume):
			{
				buffer.AppendF($"{Client_IPCCommands.AUDIO_SET_VOLUME}|{volume}");
			}
		case .QuitCompanion: buffer.Append(Client_IPCCommands.QUIT_COMPANION);
		}

		buffer.Append(Client_IPCCommands.COMMAND_SEPARATOR);
	}
}

enum eServerCommand
{
	case AudioVolumeChanged(uint32 volume);

	public static Result<Self> TryParseFromMessage(StringView message)
	{
		 let (cmd, args) = IPCHelper.SplitMessage(message);
		 return TryParse(cmd, args);
	}

	public static Result<Self> TryParse(StringView cmd, StringView args)
	{
		switch (cmd)
		{
		case Server_IPCCommands.AUDIO_VOLUME_CHANGED:
			{
				if (uint32.Parse(args) case .Ok(let val))
				{
					return Self.AudioVolumeChanged(val);
				}
			}
		}
		return .Err;
	}

	public static void ToMessage(Self value, String buffer)
	{
		switch (value)
		{
		case .AudioVolumeChanged(let volume):
			{
				buffer.AppendF($"{Client_IPCCommands.AUDIO_SET_VOLUME}|{volume}");
			}
		}
		buffer.Append(Client_IPCCommands.COMMAND_SEPARATOR);
	}
}