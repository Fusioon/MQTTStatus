using System;
namespace MQTTCommon;

class Client_IPCCommands
{
	public const String COMMAND_SEPARATOR = "\n";
	public const String MONITOR_POWERSAVE = "monitor_powersave";
	public const String LOCK_WORKSTATION = "workstation_lock";
	public const String QUIT_COMPANION = "companion_close";
	public const String NOTIFICATION = "notify";
}