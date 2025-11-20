#if WITH_KDE

using System;
using System.IO;

using MQTTCommon;

namespace MQTTStatus;

class kwinInstaller
{
	const String SCRIPT_DATA = Compiler.ReadText("assets/kwin.main.js");
	const String METADATA_DATA = Compiler.ReadText("assets/kwin.metadata.json");

	const String INSTALL_PATH = "~/.local/share";
	const String[?] INSTALL_PATH_SUBDIRS = .("kwin", "scripts", "screen-off-watcher");

	const String[?] CONTENT_DIRS = .("contents", "code");

	static Result<void> CreateDirs(String path, Span<String> dirs)
	{
		int savedLength = -1;

		for (let subdirName in dirs)
		{
			if (String.IsNullOrEmpty(subdirName))
			{
				savedLength = path.Length;
				continue;
			}

			Path.Combine(path, subdirName);
			if (Directory.CreateDirectory(path) case .Err(let err) && err != .AlreadyExists)
			{
				Log.Error(scope $"Failed to create folder at '{path}' ({err})");
				return .Err;
			}

			if (savedLength != -1)
			{
				path.Length = savedLength;
			}
		}
		return .Ok;
	}

	public static Result<void> Install()
	{
		String path = scope .(INSTALL_PATH);
		LinuxPathHelper.MakeAbsolute(path);

		Try!(CreateDirs(path, INSTALL_PATH_SUBDIRS));

		// Write metadata
		{
			let length = path.Length;

			Path.Combine(path, "metadata.json");
			if (File.WriteAllText(path, METADATA_DATA) case .Err)
			{
				Log.Error(scope $"Failed to write metadata at '{path}'");
				return .Err;
			}

			path.Length = length;
		}

		// Write script
		{
			let length = path.Length;

			Try!(CreateDirs(path, CONTENT_DIRS));
			Path.Combine(path, "main.js");
			if (File.WriteAllText(path, SCRIPT_DATA) case .Err)
			{
				Log.Error(scope $"Failed to write script file at '{path}'");
				return .Err;
			}

			path.Length = length;
		}

		Log.Success(scope $"kwin created screen-off-watcher");

		Log.Info(
			"""
			NOTE:
			You might need to run following commands

				# Enable the script in KWin
				kwriteconfig6 --file kwinrc --group Plugins --key screen-off-watcherEnabled true
				
				# Reload KWin scripts (or logout/login)
				qdbus6 org.kde.KWin /KWin reconfigure
			""");

		return .Ok;
	}

	public static Result<void> Uninstall()
	{
		return .Err;
	}
}

#endif