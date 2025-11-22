using System;
using System.IO;

using PahoMQTT;
using MQTTCommon;

namespace MQTTStatus;

class Program
{
	const String CONFIG_FILENAME = $"{Compiler.ProjectName}.config.toml";
	const String LOG_FILENAME_TEMPLATE = $"{Compiler.ProjectName}.{{0}}.log";
	const int MAX_LOG_HISTORY_COUNT = 10;

	public static int Main(String[] args)
	{
		EServiceOptions opts = .None;
		bool debug = false;
		bool force = false; // Force regeneration of config file

		for (let a in args)
		{
			switch (a)
			{
			case "--install": opts = .Install;
			case "--uninstall": opts = .Uninstall;
			case "--debug": debug = true;
			case "--force": force = true;
			}

		}

		if (opts != .None || debug)
		{
			Log.Init(true, debug);
		}

		FileStream fs = scope .();
		String exeDirectoryPath = {
			String exeFilePath = scope .();
			Environment.GetExecutableFilePath(exeFilePath);
			
			Path.GetDirectoryPath(exeFilePath, .. scope:: .())
		};
		
		String tempPathBuffer = scope .(256);
		INIT_LOG_FILES:
		{
			String fileNameBuffer = scope .(LOG_FILENAME_TEMPLATE.Length + 8);
			String prevLogPath = scope .(256);

			tempPathBuffer.Set(exeDirectoryPath);

			Path.Combine(tempPathBuffer, "logs");

			prevLogPath.Set(tempPathBuffer);

			let logsDirPathLength = tempPathBuffer.Length;

			for (int32 i = MAX_LOG_HISTORY_COUNT; i >= 0; i--)
			{
				fileNameBuffer..Clear().AppendF(LOG_FILENAME_TEMPLATE, i);
				Path.Combine(tempPathBuffer, fileNameBuffer);
				if (i == MAX_LOG_HISTORY_COUNT)
				{
					if (File.Delete(tempPathBuffer) case .Err(let err))
					{
						if (err != .NotFound)
						{
							Log.Error(scope $"Failed to delete log file '{tempPathBuffer}' ({err})");
						}
					}
				}
				else
				{
					if (File.Move(tempPathBuffer, prevLogPath) case .Err(let err))
					{
						if (err != .NotFound)
						{
							Log.Error(scope $"Failed to move log file '{tempPathBuffer}' ({err})");
						}
					}
				}

				prevLogPath.Length = logsDirPathLength;
				Path.Combine(prevLogPath, fileNameBuffer);
				
				tempPathBuffer.Length = logsDirPathLength;
			}

			fileNameBuffer..Clear().AppendF(LOG_FILENAME_TEMPLATE, "latest");
			Path.Combine(tempPathBuffer, fileNameBuffer);
			switch (File.Move(tempPathBuffer, prevLogPath))
			{
				case .Ok:
				case .Err(let err):
				{
					switch (err)
					{
						case .NotFound: break;
						default:
						{
							Log.Error(scope $"Failed to move log file '{tempPathBuffer}' ({err})");
						}
					}

				}
			}

			if (fs.Open(tempPathBuffer, FileMode.Create, .Write, .Read) case .Err(let err))
			{
				Log.Error(scope $"Failed to open log file for writing '{tempPathBuffer}' ({err})");
				return 1;
			}

			Log.AddCallback(new (level, time, message, preferredFormat) => {
				fs.Write(preferredFormat);
				fs.Write('\n');
				fs.Flush();
			});
		}
		Config cfg = scope .();
		{
			tempPathBuffer.Set(exeDirectoryPath);
			Path.Combine(tempPathBuffer, CONFIG_FILENAME);
			switch (opts)
			{
			case .None:
				{
					if (cfg.Load(tempPathBuffer) case .Err(let err))
					{
						 Log.Error(scope $"Failed to load config at path: '{tempPathBuffer}' ({err})");
						 return 1;
					}
				}
			case .Install:
				{
					bool canOverwrite;
					if (force)
					{
						canOverwrite = true;
						cfg.SetDefault();
					}
					else
					{
						switch (cfg.Load(tempPathBuffer))
						{
						case .Err(let err):
							{
								canOverwrite = false;

								if (err not case .FileError(let p0) && p0 != .NotFound)
								{
									Log.Error(scope $"Failed to load config at path: '{tempPathBuffer}' ({err})");
								}
							}

						case .Ok:
							canOverwrite = true;
						}
					}
					
					if (cfg.Save(tempPathBuffer, canOverwrite) case .Err)
						Log.Error(scope $"Failed to save config at path: '{tempPathBuffer}");
				}
			case .Uninstall:
			}
		}

		PlatformOS platform;
#if BF_PLATFORM_WINDOWS
		platform = scope PlatformWin32();
#elif BF_PLATFORM_LINUX
		platform = scope PlatformLinux();
#endif

		platform.AssignConfig(cfg);
		return platform.Start(opts, debug);
	}
}