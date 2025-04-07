using System;
using System.Interop;

using MQTTCommon;
using MQTTCommon.Win32;

namespace MQTTCompanion;

enum EHResult : c_long
{
	case S_OK = 0;
	case E_OUTOFMEMORY = 0x8007000EL;
	case E_NOINTERFACE = 0x80004002;
	case CLASS_E_NOAGGREGATION = 0x80040110L;

	public static implicit operator HResult(Self inst)
	{
		return ((.)(c_long)inst);
	}
}

class ToastNotifier
{
#region COM_INTERFACES

	[MIDL_INTERFACE("50ac103f-d235-4598-bbef-98fe4d1a3ad4")]
	public interface IToastNotificationManagerStatics : IInspectable
	{
		HResult CreateToastNotifier(ComPtr<IToastNotifier>** result);
		HResult CreateToastNotifierWithId(HSTRING applicationId, ComPtr<IToastNotifier>** result);
		HResult GetTemplateContent(ToastTemplateType type, ComPtr<IXmlDocument>** result);
	}

	public enum ToastTemplateType : c_int
	{
	    ToastImageAndText01 = 0,
	    ToastImageAndText02 = 1,
	    ToastImageAndText03 = 2,
	    ToastImageAndText04 = 3,
	    ToastText01 = 4,
	    ToastText02 = 5,
	    ToastText03 = 6,
	    ToastText04 = 7,
	}

	public enum NotificationSetting : c_int
	{
	    Enabled = 0,
	    DisabledForApplication = 1,
	    DisabledForUser = 2,
	    DisabledByGroupPolicy = 3,
	    DisabledByManifest = 4,
	}

	[CRepr]
	public struct __FIVectorView_1_Windows__CUI__CNotifications__CScheduledToastNotification
	{
		public void* lpVtbl;
	}

	[MIDL_INTERFACE("75927b93-03f3-41ec-91d3-6e5bac1b38e7")]
	public interface IToastNotifier : IInspectable
	{
		HResult Show(ComPtr<IToastNotification>* notification);
		HResult Hide(ComPtr<IToastNotification>* notification);
		HResult get_Setting(NotificationSetting* value);
		HResult AddToSchedule(ComPtr<IScheduledToastNotification>* scheduledToast);
		HResult RemoveFromSchedule(ComPtr<IScheduledToastNotification>* scheduledToast);
		HResult GetScheduledToastNotifications(__FIVectorView_1_Windows__CUI__CNotifications__CScheduledToastNotification** result);
	}

	[CRepr]
	public struct CDateTime
	{
		public int64 UniversalTime;
	}

	[MIDL_INTERFACE("997e2675-059e-4e60-8b06-1760917c8b80")]
	public interface IToastNotification : IInspectable
	{
		HResult get_Content(IXmlDocument** value);
		HResult put_ExpirationTime(ComPtr<IReference<CDateTime>>* value);
		HResult get_ExpirationTime(ComPtr<IReference<CDateTime>>** value);

		/*HResult add_Dismissed(__FITypedEventHandler_2_Windows__CUI__CNotifications__CToastNotification_Windows__CUI__CNotifications__CToastDismissedEventArgs* handler,    EventRegistrationToken* token);
		HResult remove_Dismissed(EventRegistrationToken token);
		HResult add_Activated(__FITypedEventHandler_2_Windows__CUI__CNotifications__CToastNotification_IInspectable* handler,    EventRegistrationToken* token);
		HResult remove_Activated(EventRegistrationToken token);
		HResult add_Failed(__FITypedEventHandler_2_Windows__CUI__CNotifications__CToastNotification_Windows__CUI__CNotifications__CToastFailedEventArgs* handler,    EventRegistrationToken* token);
		HResult remove_Failed(EventRegistrationToken token);*/

	}

	[MIDL_INTERFACE("f7f3a506-1e87-42d6-bcfb-b8c809fa5494")]
	public interface IXmlDocument : IInspectable
	{
		HResult get_Doctype(ComPtr<IXmlDocumentType>** value);
		HResult get_Implementation(ComPtr<IXmlDomImplementation>** value);
		HResult get_DocumentElement(ComPtr<IXmlElement>** value);
		HResult CreateElement(HSTRING tagName, ComPtr<IXmlElement>** newElement);
		HResult CreateDocumentFragment(ComPtr<IXmlDocumentFragment>** newDocumentFragment);
		HResult CreateTextNode(HSTRING data, ComPtr<IXmlText>** newTextNode);
		HResult CreateComment(HSTRING data, ComPtr<IXmlComment>** newComment);
		HResult CreateProcessingInstruction(HSTRING target, HSTRING data, ComPtr<IXmlProcessingInstruction>** newProcessingInstruction);
		HResult CreateAttribute(HSTRING name, ComPtr<IXmlAttribute>** newAttribute);
		HResult CreateEntityReference(HSTRING name, ComPtr<IXmlEntityReference>** newEntityReference);
		HResult GetElementsByTagName(HSTRING tagName, ComPtr<IXmlNodeList>** elements);
		HResult CreateCDataSection(HSTRING data, ComPtr<IXmlCDataSection>** newCDataSection);
		HResult get_DocumentUri(HSTRING* value);
		HResult CreateAttributeNS(IInspectable* namespaceUri, HSTRING qualifiedName, ComPtr<IXmlAttribute>** newAttribute);
		HResult CreateElementNS(IInspectable* namespaceUri, HSTRING qualifiedName, ComPtr<IXmlElement>** newElement);
		HResult GetElementById(HSTRING elementId, ComPtr<IXmlElement>** element);
		HResult ImportNode(ComPtr<IXmlNode>* node, bool deep, ComPtr<IXmlNode>** newNode);

	}

	public interface IXmlDocumentType : IInspectable
	{

	}

	public interface IXmlDomImplementation : IInspectable
	{

	}

	public interface IXmlElement : IInspectable
	{

	}

	public interface IXmlDocumentFragment : IInspectable
	{

	}


	public interface IXmlText : IInspectable
	{

	}

	public interface IXmlComment : IInspectable
	{

	}

	public interface IXmlProcessingInstruction : IInspectable
	{

	}

	public interface IXmlAttribute : IInspectable
	{

	}

	public interface IXmlEntityReference : IInspectable
	{

	}

	public interface IXmlNodeList : IInspectable
	{

	}

	public interface IXmlCDataSection : IInspectable
	{

	}

	public interface IXmlNode : IInspectable
	{

	}

	[MIDL_INTERFACE("6cd0e74e-ee65-4489-9ebf-ca43e87ba637")]
	public interface IXmlDocumentIO : IInspectable
	{
		HResult LoadXml(HSTRING xml);
		HResult LoadXmlWithSettings(HSTRING xml, ComPtr<IXmlLoadSettings>* loadSettings);
		HResult SaveToFileAsync(ComPtr<IStorageFile>* file, ComPtr<IAsyncAction>** asyncInfo);
	}


	public interface IXmlLoadSettings : IInspectable
	{

	}

	public interface IStorageFile : IInspectable
	{

	}

	public interface IAsyncAction : IInspectable
	{

	}

	[MIDL_INTERFACE("79f577f8-0de7-48cd-9740-9b370490c838")]
	public interface IScheduledToastNotification : IInspectable
	{

	}

	[MIDL_INTERFACE("04124b20-82c6-4229-b109-fd9ed4662b53")]
	public interface IToastNotificationFactory : IInspectable
	{
		HResult CreateToastNotification(ComPtr<IXmlDocument>* content, ComPtr<IToastNotification>** value);
	}


#endregion


	static mixin CheckResult(HResult result, bool allowModeChange = false)
	{
		const int32 RPC_E_CHANGED_MODE = (.)0x80010106L;

		if (result.Failed && (!allowModeChange || result != (.)RPC_E_CHANGED_MODE))
		{
			Log.Error(scope $"0x{((uint32)result):x}");
			return .Err;
		}
	}

	static mixin CheckResultVal<T>(Result<T, HResult> result)
	{
		if (result case .Err(let code))
		{
			Log.Error(scope $"0x{((uint32)code):x}");
			return .Err;
		}

		result.Get()
	}

	[GenerateVTable]
	public struct GenericComPtr : ComPtr
	{
		public uint64 refCount = 0;

		public HResult QueryInterface(IID* riid, void** ppvObject)
		{
			return EHResult.E_NOINTERFACE;
		}

		public c_ulong AddRef() mut
		{
			return (.)System.Threading.Interlocked.Increment(ref refCount);
		}

		public c_ulong Release() mut
		{
			return (.)System.Threading.Interlocked.Decrement(ref refCount);
		}
	}

	[GenerateVTable]
	public struct INotificationActivationCallback : GenericComPtr
	{
		[CRepr]
		public struct NOTIFICATION_USER_INPUT_DATA
		{
			public c_wchar* Key;
			public c_wchar* Value;
		}

		[CLink]
		public static extern readonly GUID IID_INotificationActivationCallback;

		public new HResult QueryInterface(IID* riid, void** ppvObject) mut
		{
			if (*riid != IID_INotificationActivationCallback && *riid != ComPtr<IUnknown>.IID)
			{
				*ppvObject = null;
				return EHResult.E_NOINTERFACE;
			}
			*ppvObject = &this;
			AddRef();
			return EHResult.S_OK;
		}

		public HResult Activate(c_wchar* appUserModelId, c_wchar* invokedArgs, NOTIFICATION_USER_INPUT_DATA* data, c_ulong count) mut
		{
			String args = scope .(invokedArgs);
			switch (args)
			{
			/*case "action=closeApp":
				{
					PostThreadMessageW(dwMainThreadId, WM_QUIT, 0, 0);
				}
			case "action=reply":
				{
					String reply = scope .();
					String key = scope .();
					for (let i < count)
					{
						key..Clear().Append(data[i].Key);
						if (key == "tbReply")
						{
							reply..Clear().Append(data.Value);
							Console.WriteLine($"Reply: {reply}");
						}
					}
				}*/
			default:
				Console.WriteLine(_);
			}
			return EHResult.S_OK;
		}
	}

	[GenerateVTable, CRepr]
	public struct IClassFactory : GenericComPtr
	{
		[CLink]
		public static extern readonly GUID IID_IClassFactory;

		public new HResult QueryInterface(IID* riid, void** ppvObject) mut
		{
			 if (*riid != IID_IClassFactory && *riid != ComPtr<IUnknown>.IID)
			{
				*ppvObject = null;
				return EHResult.E_NOINTERFACE;
			}
			*ppvObject = &this;
			AddRef();
			return EHResult.S_OK;
		}

		
		public HResult CreateInstance(ComPtr<IUnknown>* pUnkOuter, GUID* riid, void** ppvObject)
		{
			if (pUnkOuter != null)
				return EHResult.CLASS_E_NOAGGREGATION;

			if (INotificationActivationCallback* thisObj = (.)Internal.StdMalloc(sizeof(INotificationActivationCallback)))
			{
				*thisObj = .();
				thisObj.refCount = 1;
				let hr = thisObj.QueryInterface(riid, ppvObject);
				thisObj.Release();
				return hr;
			}

			return EHResult.E_OUTOFMEMORY;
		}

		public HResult LockServer(Windows.IntBool fLock) mut => EHResult.S_OK;
	}

	public const String GUID_Impl_INotificationActivationCallback_Textual = "80AA4689-D011-4E01-9D98-A90B1C15FF8D";
	public static GUID GUID_Impl_INotificationActivationCallback = ParseUUID(GUID_Impl_INotificationActivationCallback_Textual);

	public const String APP_ID = "MQTTCompanion";
	public const String APP_NAME = "MQTTCompanion";
	public const String TOAST_ACTIVATED_ARG = "-ToastActivated";

	public static GUID IID_IToastNotificationManagerStatics = .(0x50ac103f, 0xd235, 0x4598, 0xbb, 0xef, 0x98, 0xfe, 0x4d, 0x1a, 0x3a, 0xd4);
	public static GUID IID_IToastNotificationFactory = .(0x04124b20, 0x82c6, 0x4229, 0xb1, 0x09, 0xfd, 0x9e, 0xd4, 0x66, 0x2b, 0x53);
	public static GUID IID_IXmlDocument = .(0xf7f3a506, 0x1e87, 0x42d6, 0xbc, 0xfb, 0xb8, 0xc8, 0x09, 0xfa, 0x54, 0x94);
	public static GUID IID_IXmlDocumentIO = .(0x6cd0e74e, 0xee65, 0x4489, 0x9e, 0xbf, 0xca, 0x43, 0xe8, 0x7b, 0xa6, 0x37);

	public const String RuntimeClass_Windows_UI_Notifications_ToastNotificationManager = "Windows.UI.Notifications.ToastNotificationManager";
	public const String RuntimeClass_Windows_UI_Notifications_ToastNotification = "Windows.UI.Notifications.ToastNotification";
	public const String RuntimeClass_Windows_Data_Xml_Dom_XmlDocument = "Windows.Data.Xml.Dom.XmlDocument";

	public const String BANNER_TEXT =
	"""
	<toast scenario="reminder"
	activationType="foreground" duration="@{DURATION}">
		<visual>
			<binding template="ToastGeneric">
				@{CONTENT}
			</binding>
		</visual>
		<audio src="ms-winsoundevent:Notification.Default" loop="false" silent="false"/>
	</toast>
	""";


	public static c_ulong dwMainThreadId;

	public static HResult SetRegistryValue(HKey hKey, StringView subKey, StringView data)
	{
		let subkeyWide = subKey.ToScopedNativeWChar!();
		let dataWide = data.ToScopedNativeWChar!(let dataSize);
		return RegSetValueW(hKey, subkeyWide, REG_SZ, dataWide.Ptr, (.)dataSize * sizeof(c_wchar)).Result;
	}

	public static HResult SetRegistryKeyValue(HKey hKey, StringView subKey, StringView valueName, StringView data)
	{
		let subkeyWide = subKey.ToScopedNativeWChar!();
		let valuekeyWide = valueName.ToScopedNativeWChar!();
		let dataWide = data.ToScopedNativeWChar!(let dataSize);
		return ((LSTATUS)RegSetKeyValueW(hKey, subkeyWide, valuekeyWide, REG_SZ, dataWide.Ptr, (.)dataSize * sizeof(c_wchar))).Result;
	}

	public static Result<HSTRING, HResult> ReferenceString<CString>(CString data, out HSTRING_HEADER hStringHeader) where CString : const String
	{
		static c_wchar[?] wide = CString.ToConstNativeW();
		hStringHeader = default;
		HSTRING hString = 0;

		let result = WindowsCreateStringReference(&wide, (.)CString.Length, &hStringHeader, &hString);
		if (result.Success)
		{
			return .Ok(hString);
		}
		return .Err(result);
	}

	public static Result<HSTRING, HResult> CreateString(StringView data)
	{
		HSTRING hString = 0;
		let buffer = data.ToScopedNativeWChar!(let length);
		let result = WindowsCreateString(buffer.Ptr, (.)length, &hString);
		if (result.Success)
		{
			return .Ok(hString);
		}
		return .Err(result);
	}

	static uint32 s_dwCookie = 0;
	static IClassFactory* s_pClassFactory;

	static HSTRING s_hsAppId;

	static ComPtr<IToastNotificationManagerStatics>* s_pToastNotificationManager;
	static ComPtr<IToastNotifier>* s_pToastNotifier;
	static ComPtr<IToastNotificationFactory>* s_pNotificationFactory;
	static ComPtr<IInspectable>* s_pInspectable;

	static ComPtr<IXmlDocument>* s_pXmlDocument;
	static ComPtr<IXmlDocumentIO>* s_pXmlDocumentIO;

	public static void Shutdown()
	{
		s_pXmlDocumentIO?.Release();
		s_pXmlDocument?.Release();
		s_pNotificationFactory?.Release();
		s_pToastNotifier?.Release();
		s_pToastNotificationManager?.Release();

		WindowsDeleteString(s_hsAppId);

		CoRevokeClassObject(s_dwCookie);

		Internal.StdFree(s_pClassFactory);

		RoUninitialize();
		CoUninitialize();
	}

	public static Result<void> Init()
	{
		{
			String value = scope .();
			value.Append('\"');
			//Environment.GetExecutableFilePath(value);
			c_wchar[Windows.MAX_PATH] buffer = default;
			GetModuleFileNameW(0, &buffer, Windows.MAX_PATH);
			value.Append(&buffer);
			value.Append('\"');
			value.AppendF($" {TOAST_ACTIVATED_ARG}");

			const String LocalServerKey = @$"SOFTWARE\Classes\CLSID\{GUID_Impl_INotificationActivationCallback_Textual}\LocalServer32";
			CheckResult!(SetRegistryValue(HKEY_CURRENT_USER, LocalServerKey, value));
		}

		{
			const String key = @$"SOFTWARE\Classes\AppUserModelId\{APP_ID}";

			CheckResult!(SetRegistryKeyValue(HKEY_CURRENT_USER, key, "DisplayName", APP_NAME));
			CheckResult!(SetRegistryKeyValue(HKEY_CURRENT_USER, key, "IconBackgroundColor", "FF00FF00"));
			const String ACTIVATOR_GUID = $"{{{GUID_Impl_INotificationActivationCallback_Textual}}}";
			CheckResult!(SetRegistryKeyValue(HKEY_CURRENT_USER, key, "CustomActivator", ACTIVATOR_GUID));
		}

		CheckResult!(CoInitializeEx(null, COINIT.COINIT_MULTITHREADED.Underlying), true);
		CheckResult!(RoInitialize(.RO_INIT_MULTITHREADED), true);

		s_pClassFactory = (IClassFactory*)Internal.StdMalloc(sizeof(IClassFactory));
		*s_pClassFactory = .();
		s_pClassFactory.refCount = 1;

		CheckResult!(CoRegisterClassObject(&GUID_Impl_INotificationActivationCallback, (.)s_pClassFactory, .CLSCTX_LOCAL_SERVER, .REGCLS_MULTIPLEUSE, &s_dwCookie));

		s_hsAppId = CheckResultVal!(CreateString(APP_ID));
		let hsToastNotificationManager = CheckResultVal!(CreateString(RuntimeClass_Windows_UI_Notifications_ToastNotificationManager));
		defer hsToastNotificationManager.Dispose();

		CheckResult!(RoGetActivationFactory(hsToastNotificationManager, &ComPtr<IToastNotificationManagerStatics>.IID, (.)&s_pToastNotificationManager));

		CheckResult!(s_pToastNotificationManager.CreateToastNotifierWithId(s_hsAppId, &s_pToastNotifier));

		let hsToastNotification = CheckResultVal!(CreateString(RuntimeClass_Windows_UI_Notifications_ToastNotification));
		defer hsToastNotification.Dispose();

		CheckResult!(RoGetActivationFactory(hsToastNotification, &IID_IToastNotificationFactory, (.)&s_pNotificationFactory));

		let hsXmlDocument = CheckResultVal!(CreateString(RuntimeClass_Windows_Data_Xml_Dom_XmlDocument));
		defer hsXmlDocument.Dispose();

		CheckResult!(RoActivateInstance(hsXmlDocument, (.)&s_pInspectable));

		s_pXmlDocument = CheckResultVal!(s_pInspectable.QueryInterface<IXmlDocument>());

		s_pXmlDocumentIO = CheckResultVal!(s_pXmlDocument.QueryInterface<IXmlDocumentIO>());
		return .Ok;
	}

	public static Result<void> ShowNotification(StringView title, StringView message)
	{
		String banner = scope .();
		String body = scope .();

		// @TODO - escape

		if (title.Length > 0)
		{
			body.AppendF($"<text><![CDATA[{title}]]></text>\n");
		}
		if (message.Length > 0)
		{
			body.AppendF($"<text><![CDATA[{message}]]></text>\n");
		}

		String duration = "default";

		banner..Set(BANNER_TEXT)
			..Replace("@{CONTENT}", body)
			..Replace("@{DURATION}", duration);

		let hNotificationText = CheckResultVal!(CreateString(banner));
		defer hNotificationText.Dispose();

		CheckResult!(s_pXmlDocumentIO.LoadXml(hNotificationText));

		ComPtr<IToastNotification>* pToastNotification = null;
		CheckResult!(s_pNotificationFactory.CreateToastNotification(s_pXmlDocument, &pToastNotification));
		defer pToastNotification.Release();

		CheckResult!(s_pToastNotifier.Show(pToastNotification));

		return .Ok;
	}
}