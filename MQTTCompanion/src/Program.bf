using System;

using MQTTCommon;
using MQTTCommon.Win32;
using System.Interop;
using System.Collections;
using System.Threading;

namespace MQTTCompanion;

class Program
{
	const String APP_NAME = "MQTTCompanion";
	static c_wchar[?] RUN_ON_STARTUP_REGISTRY_PATH_WIDE = @"Software\Microsoft\Windows\CurrentVersion\Run".ToConstNativeW();
	static c_wchar[?] APP_REGISTRY_NAME_WIDE = APP_NAME.ToConstNativeW();

	[CallingConvention(.Stdcall), CLink]
	static extern Windows.IntBool LockWorkStation();

	static public bool IsRunAtStart(bool checkPath)
	{
		c_wchar[Windows.MAX_PATH] buffer = default;
		uint32 length = buffer.Count;

		if (RegGetValueW(HKEY_CURRENT_USER, &RUN_ON_STARTUP_REGISTRY_PATH_WIDE, &APP_REGISTRY_NAME_WIDE, RRF_RT_REG_SZ, null, &buffer, &length) == 0)
		{
			if (checkPath)
			{
				String path = scope .(Span<c_wchar>(&buffer, length));
				return System.IO.File.Exists(path);
			}

			return true;
		}

		return false;
	}

	static Result<void> SetRunAtStart(bool enable)
	{
		if (!enable)
		{
			if (RegDeleteKeyValueW(HKEY_CURRENT_USER, &RUN_ON_STARTUP_REGISTRY_PATH_WIDE, &APP_REGISTRY_NAME_WIDE) == 0)
				return .Ok;
			return .Err;
		}

		HKey hKey = default;
		uint32 disposition = 0;
		var res = RegCreateKeyExW(HKEY_CURRENT_USER, &RUN_ON_STARTUP_REGISTRY_PATH_WIDE, 0, null, REG_OPTION_NON_VOLATILE, KEY_WRITE, null, &hKey, &disposition);
		if (res != 0)
		{
			Log.Error(scope $"[Win32] Failed to create/open registry 'RUN_ON_STARTUP_REGISTRY_PATH'. ({res})");
			return .Err;
		}
		defer RegCloseKey(hKey);

		c_wchar[Windows.MAX_PATH] buffer = default;
		let length = GetModuleFileNameW(0, &buffer, buffer.Count);

		if (length == 0)
		{
			Log.Error(scope $"[Win32] Failed to retrieve executable path. ({Windows.GetLastError()})");
			return .Err;
		}

		let result = RegSetKeyValueW(hKey, null, &APP_REGISTRY_NAME_WIDE, REG_SZ, &buffer, length * sizeof(c_wchar));
		if (result != 0)
		{
			Log.Error(scope $"[Win32] Failed to set value of registry key '{APP_REGISTRY_NAME_WIDE}'. ({result})");
			return .Err;
		}

		return .Ok;
	}

	static void SendKeyboardInput(int16 vk)
	{
		INPUT input = .CreateKeyboard(.KeyDown(vk));
		SendInput(1, &input, sizeof(INPUT));
		input.keyboard.dwFlags = KEYEVENTF_KEYUP;
		SendInput(1, &input, sizeof(INPUT));
	}

	static void Main(String[] args)
	{
		Log.Init(true, false);

		for (let a in args)
		{
			switch (a)
			{
			case "--install":
				{
					if (SetRunAtStart(true) case .Err)
						Console.WriteLine();
					return;
				}
			case "--uninstall":
				{
					if (SetRunAtStart(false) case .Err)
						Console.WriteLine("");
					return;
				}

			case ToastNotifier.TOAST_ACTIVATED_ARG:
				{
					return;
				}
			}
		}

		defer ToastNotifier.Shutdown();
		if (ToastNotifier.Init() case .Err)
		{
			return;
		}

		defer AudioManager.Shutdown();
		if (AudioManager.Init() case .Err)
			return;

		MQTTCommon.IPCClient_T ipcClient = scope .();

		AudioManager.onVolumeChanged.Add(new (muted, volume) => {
			let volumeValue = (uint32)Math.Clamp((int32)(volume * 100), 1, 100);
			TrySilent!(ipcClient.Send(.AudioVolumeChanged(volumeValue)));
		});

		let timer = SetTimer(0, 0, 1000, null);
		defer KillTimer(0, timer);

		MSG msg = default;
		bool wasDisconnected = true;
		while (GetMessageW(&msg, 0, 0, 0))
		{
			TranslateMessage(&msg);
			DispatchMessageW(&msg);

			if (ipcClient.Update(wasDisconnected) case .Err)
			{
				wasDisconnected = true;
				continue;
			}

			if (wasDisconnected)
			{
				wasDisconnected = false;
				AudioManager.QueryVolume();
			}

			let message = ipcClient.PopMessage();
			if (message == null)
				continue;

			defer delete message;

			if (eClientCommand.TryParseFromMessage(message) not case .Ok(let cmd))
				continue;

			switch (cmd)
			{
			case .MonitorPowersave:
				{
					const int SC_MONITORPOWER = 0xF170;
					Windows.PostMessageW(.Broadcast, WM_SYSCOMMAND, SC_MONITORPOWER, 2);
				}
			case .LockWorkstation:
				{
					LockWorkStation();
				}
			case .AudioMute:
				{
					if (AudioManager.GetMute() case .Ok(let muted))
					{
						AudioManager.SetMute(!muted).IgnoreError();
					}
				}
			case .AudioSetVolume(let volume):
				{
					AudioManager.SetVolume(Math.Clamp(volume, 1, 100) / 100f).IgnoreError();
				}
			case .MediaStop:
				{
					SendKeyboardInput(VK_MEDIA_STOP);
				}
			case .MediaNext:
				{
					SendKeyboardInput(VK_MEDIA_NEXT_TRACK);
				}
			case .MediaPrev:
				{
					SendKeyboardInput(VK_MEDIA_PREV_TRACK);
				}
			case .Notification(let title, let text):
				{
					ToastNotifier.ShowNotification(title, text).IgnoreError();
				}
			case .QuitCompanion:
				{
					PostQuitMessage(0);

				}
			}
		}
	}
}