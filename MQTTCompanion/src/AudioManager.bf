using System;

using System;
using System.Interop;

using MQTTCommon;
using MQTTCommon.Win32;

namespace MQTTCompanion;

static class AudioManager
{
#region COM

	public enum EDataFlow : int32
	{
		eRender	= 0,
		eCapture	= (eRender + 1),
		eAll	= (eCapture + 1),
		EDataFlow_enum_count	= (eAll + 1)
	}

	public enum ERole : int32
	{
		eConsole	= 0,
		eMultimedia	= (eConsole + 1),
		eCommunications	= (eMultimedia + 1),
		ERole_enum_count	= (eCommunications + 1)
	}

	[CRepr]
	public struct PROPERTYKEY
	{
		public GUID fmtid;
		public c_ulong pid;
	}

	[MIDL_INTERFACE("A95664D2-9614-4F35-A746-DE8DB63617E6")]
	public interface IMMDeviceEnumerator : IUnknown
	{
		HResult EnumAudioEndpoints(EDataFlow dataFlow, uint32 dwStateMask, ComPtr<IMMDeviceCollection>* ppDevices);
		HResult GetDefaultAudioEndpoint(EDataFlow data, ERole role, ComPtr<IMMDevice>** ppEndpoint);
		HResult GetDevice(c_wchar* pwstrId, ComPtr<IMMDevice>** ppDevice);
		HResult RegisterEndpointNotificationCallback(IMMNotificationClient* pClient);
		HResult UnregisterEndpointNotificationCallback(IMMNotificationClient* pClient);
	}

	[MIDL_INTERFACE("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E")]
	public interface IMMDeviceCollection : IUnknown
	{
	}

	[MIDL_INTERFACE("D666063F-1587-4E43-81F1-B948E807363F")]
	public interface IMMDevice : IUnknown
	{
		HResult Activate(GUID* iid, CLSCTX dwClsCtx, PROPVARIANT* pActivationParams, void** ppInterface);
		HResult OpenPropertyStore(c_ulong stgmAccess, ComPtr<IPropertyStore>* ppProperties);
		HResult GetId(c_wchar* ppstrId);
		HResult GetState(c_ulong* pdwState);
	}

	[MIDL_INTERFACE("7991EEC9-7E89-4D85-8390-6C703CEC60C0")]
	public interface IMMNotificationClient : IUnknown
	{
		HResult OnDeviceStateChanged(c_wchar* pwstrDeviceId, c_ulong dwNewState);
		        
		HResult OnDeviceAdded(c_wchar* pwstrDeviceId);
		        
		HResult OnDeviceRemoved(c_wchar* pwstrDeviceId);
		        
		HResult OnDefaultDeviceChanged(EDataFlow flow, ERole role, c_wchar* pwstrDefaultDeviceId);
		        
		HResult OnPropertyValueChanged(c_wchar* pwstrDeviceId, PROPERTYKEY key);
	}

	[MIDL_INTERFACE("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99")]
	public interface IPropertyStore : IUnknown
	{
	}

	[MIDL_INTERFACE("5CDF2C82-841E-4546-9722-0CF74078229A")]
	public interface IAudioEndpointVolume : IUnknown
	{
		HResult RegisterControlChangeNotify(IAudioEndpointVolumeCallback* pNotify);

		HResult UnregisterControlChangeNotify(IAudioEndpointVolumeCallback* pNotify);

		HResult GetChannelCount(c_uint* pnChannelCount);

		HResult SetMasterVolumeLevel(float fLevelDB, GUID* pguidEventContext);

		HResult SetMasterVolumeLevelScalar(float fLevel, GUID* pguidEventContext);

		HResult GetMasterVolumeLevel(float* pfLevelDB);

		HResult GetMasterVolumeLevelScalar(float* pfLevel);

		HResult SetChannelVolumeLevel(c_uint nChannel, float fLevelDB, GUID* pguidEventContext);

		HResult SetChannelVolumeLevelScalar(c_uint nChannel, float fLevel, GUID* pguidEventContext);

		HResult GetChannelVolumeLevel(c_uint nChannel, float* pfLevelDB);

		HResult GetChannelVolumeLevelScalar(c_uint nChannel, float* pfLevel);

		HResult SetMute(Windows.IntBool bMute, GUID* pguidEventContext);

		HResult GetMute(Windows.IntBool* pbMute);

		HResult GetVolumeStepInfo(c_uint* pnStep, c_uint* pnStepCount);

		HResult VolumeStepUp(GUID* pguidEventContext);

		HResult VolumeStepDown(GUID* pguidEventContext);

		HResult QueryHardwareSupport(c_ulong* pdwHardwareSupportMask);

		HResult GetVolumeRange(float* pflVolumeMindB, float* pflVolumeMaxdB, float* pflVolumeIncrementdB);
	}

	[CRepr]
	public struct AUDIO_VOLUME_NOTIFICATION_DATA
	{
		public GUID guidEventContext;
		public Windows.IntBool bMuted;
		public float fMasterVolume;
		public c_uint nChannels;
		public float[1] afChannelVolumes;
	}

	[MIDL_INTERFACE("657804FA-D6AD-4496-8A60-352752AF4F89")]
	public interface IAudioEndpointVolumeCallback : IUnknown
	{
		HResult OnNotify(AUDIO_VOLUME_NOTIFICATION_DATA* pNotify);
	}

#endregion

	[GenerateVTable]
	public struct EndpointNotifyCB : GenericComPtr, IMMNotificationClient
	{
		public HResult OnDeviceStateChanged(char16* pwstrDeviceId, uint32 dwNewState)
		{
			return EHResult.E_NOINTERFACE;
		}

		public HResult OnDeviceAdded(char16* pwstrDeviceId)
		{
			return EHResult.E_NOINTERFACE;
		}

		public HResult OnDeviceRemoved(char16* pwstrDeviceId)
		{
			return EHResult.E_NOINTERFACE;
		}

		public HResult OnDefaultDeviceChanged(EDataFlow flow, ERole role, char16* pwstrDefaultDeviceId)
		{
			if (flow == .eRender && role == .eConsole)
			{
				AudioManager.DeviceChanged();
			}

			return EHResult.S_OK;
		}

		public HResult OnPropertyValueChanged(char16* pwstrDeviceId, PROPERTYKEY key)
		{
			return EHResult.E_NOINTERFACE;
		}
	}

	[GenerateVTable]
	public struct AudioVolumeNotifyCB : GenericComPtr, IAudioEndpointVolumeCallback
	{
		public HResult OnNotify(AUDIO_VOLUME_NOTIFICATION_DATA* pNotify)
		{
			AudioManager.VolumeChanged(pNotify.bMuted, pNotify.fMasterVolume);
			return EHResult.S_OK;
		}
	}

	public static Event<delegate void(bool muted, float volume)> onVolumeChanged ~ _.Dispose();

	static GUID MMDeviceEnumerator = [ConstEval]ParseUUID("BCDE0395-E52F-467C-8E3D-C4579291692E");

	static ComPtr<IMMDeviceEnumerator>* s_pEnumerator;
	static EndpointNotifyCB s_endpointNotifier;

	static ComPtr<IMMDevice>* s_pDevice;
	static ComPtr<IAudioEndpointVolume>* s_pEndpointVolume;

	static AudioVolumeNotifyCB s_volumeChangeNotifier;

	public static Result<void> Init()
	{
		CheckResult!(CoInitializeEx(null, COINIT.COINIT_MULTITHREADED.Underlying), true);

		s_pEnumerator = default;
		CheckResult!(CoCreateInstance(&MMDeviceEnumerator,
			null,
			.CLSCTX_ALL,
			&ComPtr<IMMDeviceEnumerator>.IID,
			&s_pEnumerator));

		s_endpointNotifier = .();
		s_pEnumerator.RegisterEndpointNotificationCallback(&s_endpointNotifier);

		s_volumeChangeNotifier = .();

		DeviceChanged();

		return .Ok;
	}

	public static void Shutdown()
	{
		if (s_pEnumerator != null)
		{
			s_pEnumerator.UnregisterEndpointNotificationCallback(&s_endpointNotifier);
			s_pEnumerator.Release();
		}	


		CoUninitialize();
	}

	static void DeviceChanged()
	{
		if (s_pEndpointVolume != null)
		{
			s_pEndpointVolume.UnregisterControlChangeNotify(&s_volumeChangeNotifier);
			s_pEndpointVolume.Release();
			s_pEndpointVolume = default;
		}

		s_pDevice?.Release();
		s_pDevice = default;

		CheckResultSilent!(s_pEnumerator.GetDefaultAudioEndpoint(.eRender, .eConsole, &s_pDevice));
		CheckResultSilent!(s_pDevice.Activate(&ComPtr<IAudioEndpointVolume>.IID, .CLSCTX_ALL, null, (.)&s_pEndpointVolume));
		CheckResultSilent!(s_pEndpointVolume.RegisterControlChangeNotify(&s_volumeChangeNotifier));
	}

	static void VolumeChanged(bool muted, float volume)
	{
		if (onVolumeChanged.HasListeners)
			onVolumeChanged(muted, volume);
	}

	public static void QueryVolume()
	{
		var _ = GetVolume() case .Ok(let volume);
		_ = (GetMute() case .Ok(let mute));
		VolumeChanged(mute, volume);
	}

	public static Result<void> SetVolume(float value)
	{
		if (s_pEndpointVolume == null)
			return .Err;

		CheckResult!(s_pEndpointVolume.SetMasterVolumeLevelScalar(value, null));

		return .Ok;
	}

	public static Result<float> GetVolume()
	{
		if (s_pEndpointVolume == null)
			return .Err;

		float volume = 1;
		if (s_pEndpointVolume.GetMasterVolumeLevelScalar(&volume).Success)
		{
			return volume;
		}

		return .Err;
	}

	public static Result<bool> GetMute()
	{
		if (s_pEndpointVolume == null)
			return .Err;

		Windows.IntBool muted = false;
		CheckResult!(s_pEndpointVolume.GetMute(&muted));
		return .Ok(muted);
	}

	public static Result<void> SetMute(bool value)
	{
		if (s_pEndpointVolume == null)
			return .Err;

		CheckResult!(s_pEndpointVolume.SetMute(value, null));
		return .Ok;
	}
}