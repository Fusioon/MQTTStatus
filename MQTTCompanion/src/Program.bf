using System;


using System.Interop;
using System.Collections;
using System.Threading;

using MQTTCommon;

namespace MQTTCompanion;

class Program
{
	static int Main(String[] args)
	{
		Log.Init(true, false);

		PlatformOS platform;
#if BF_PLATFORM_WINDOWS
		platform = scope PlatformWin32();
#elif BF_PLATFORM_LINUX
		platform = scope PlatformLinux();
#endif

		Span<String> argsView = args;
		while (argsView.Length > 0)
		{
			let a = argsView[0];
			argsView = argsView.Slice(1);

			switch (a)
			{
			case "--install":
				{
					platform.Install().IgnoreError();
					/*if (SetRunAtStart(true) case .Err)
						Console.WriteLine();*/
					return 0;
				}
			case "--uninstall":
				{
					platform.Uninstall().IgnoreError();
					/*if (SetRunAtStart(false) case .Err)
						Console.WriteLine("");*/
					return 0;
				}
			default:
				{
					switch (platform.HandleArg(a, ref argsView))
					{
					case .Err(let known):
						{
							if (!known)
							{
								Log.Error(scope $"Unhandled command line argument '{a}'");
							}
						}
					case .Ok(let exit):
						{
							if (exit)
								return 0;
						}
					}
				}
			}
		}
		if (platform.Init() case .Err)
			return 1;

		return platform.Run();
	}
}