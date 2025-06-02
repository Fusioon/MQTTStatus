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

	static void HandleCommand(StringView command, StringView data)
	{
		switch (command)
		{
		case Client_IPCCommands.MONITOR_POWERSAVE:
			{
				const int SC_MONITORPOWER = 0xF170;
				Windows.PostMessageW(.Broadcast, WM_SYSCOMMAND, SC_MONITORPOWER, 2);
			}

		case Client_IPCCommands.LOCK_WORKSTATION:
			{
				LockWorkStation();
			}

		case Client_IPCCommands.NOTIFICATION:
			{
				StringView title = default;
				StringView msg = data;
				let idx = data.IndexOf('|');
				if (idx > 0)
				{
					title = data.Substring(0, idx);
					msg = data.Substring(idx + 1);
				}

				ToastNotifier.ShowNotification(title, msg).IgnoreError();
			}

		case Client_IPCCommands.AUDIO_MUTE:
			{
				if (AudioManager.GetMute() case .Ok(let muted))
				{
					AudioManager.SetMute(!muted).IgnoreError();
				}
			}

		case Client_IPCCommands.AUDIO_SET_VOLUME:
			{
				if (uint32.Parse(data) case .Ok(let val))
				{
					AudioManager.SetVolume(Math.Clamp(val, 1, 100) / 100f).IgnoreError();
				}
			}
		case Client_IPCCommands.MEDIA_STOP:
			{
				SendKeyboardInput(VK_MEDIA_STOP);
			}
		case Client_IPCCommands.MEDIA_NEXT:
			{
				SendKeyboardInput(VK_MEDIA_NEXT_TRACK);
			}
		case Client_IPCCommands.MEDIA_PREV:
			{
				SendKeyboardInput(VK_MEDIA_PREV_TRACK);
			}

		case Client_IPCCommands.QUIT_COMPANION:
			{
				PostQuitMessage(0);
			}
		}
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

		MQTTCommon.IPCClient ipcClient = scope .();

		AudioManager.onVolumeChanged.Add(new (muted, volume) => {
			let volumeValue = Math.Clamp((int32)(volume * 100), 1, 100);
			let command = scope $"{Server_IPCCommands.AUDIO_VOLUME_CHANGED}|{volumeValue}{Client_IPCCommands.COMMAND_SEPARATOR}";
			ipcClient.Send(command).IgnoreError();
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

			StringView cmd = message;
			StringView data = default;

			let cmdIndex = message.IndexOf('|');
			if (cmdIndex > 0)
			{
				cmd = message.Substring(0, cmdIndex);
				data = message.Substring(cmdIndex + 1);
			}

			HandleCommand(cmd, data);
		}
	}
}