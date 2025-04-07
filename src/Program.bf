using System;
using System.IO;

using PahoMQTT;
using MQTTCommon;

namespace MQTTStatus;

class Program
{
	public static int Main(String[] args)
	{
		EServiceOptions opts = .None;
		bool debug = false;

		for (let a in args)
		{
			switch (a)
			{
			case "--install": opts = .Install;
			case "--uninstall": opts = .Uninstall;
			case "--debug": debug = true;
			}

		}

		if (opts != .None || debug)
			Log.Init(true, debug);

		FileStream fs = scope .();
		String buffer = scope .();
		Environment.GetExecutableFilePath(buffer);
		{
			let length = buffer.Length;
			buffer.Append(".latest.log");
			if (fs.Open(buffer, FileMode.Create, .Write, .Read) case .Err)
				return 1;
			buffer.Length = length;

			Log.AddCallback(new (level, time, message, preferredFormat) => {
				fs.Write(preferredFormat);
				fs.Write('\n');
				fs.Flush();
			});
		}
		Config cfg = scope .();
		{
			let length = buffer.Length;
			buffer.Append(".config.toml");
			switch (opts)
			{
			case .None:
				{
					if (cfg.Load(buffer) case .Err(let err))
					{
						 Log.Error(scope $"Failed to load config at path: '{buffer}");
						 return 1;
					}
				}
			case .Install:
				{
					cfg.SetDefault();
					if (cfg.Save(buffer) case .Err)
						Log.Error(scope $"Failed to save config at path: '{buffer}");
				}
			case .Uninstall:
			}
			buffer.Length = length;
		}

		PlatformOS platform;
#if BF_PLATFORM_WINDOWS
		platform = scope PlatformWin32();
#endif

		return platform.Start(opts, debug, cfg);
	}
}