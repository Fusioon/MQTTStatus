using System;

using MQTTCommon;

namespace MQTTCompanion;

abstract class PlatformOS
{
	public abstract Result<bool, bool> HandleArg(StringView current, ref Span<String> args);

	public abstract Result<void> Install();
	public abstract Result<void> Uninstall();

	public abstract Result<void> Init();
	public abstract int Run();

	public abstract Result<void> HandleClientCommand(eClientCommand cmd);

	protected void OnMessage(StringView message)
	{
		switch (eClientCommand.TryParseFromMessage(message))
		{
		case .Err:
			Log.Error(scope $"Failed to parse client command from '{message}'");
		case .Ok(let cmd):
			HandleClientCommand(cmd);
		}
	}
}