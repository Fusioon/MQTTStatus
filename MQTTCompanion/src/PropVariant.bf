using System;
using System.Interop;

using MQTTCommon.Win32;

namespace MQTTCompanion;

[CRepr]
struct DECIMAL
{
	c_ushort wReserved;

	[CRepr, Union]
	public using struct
	{
		[CRepr]
		public using struct
		{
			public uint8 scale;
			public uint8 sign;
		};
		public uint16 signscale;
	};
	public uint32 Hi32;

	[CRepr, Union]
	public using struct
	{
		public using struct
		{
			public uint32 Lo32;
			public uint32 Mid32;
		};
		public uint64 Lo64;
	};
}

enum VARENUM : c_int
{
    VT_EMPTY	= 0,
    VT_NULL	= 1,
    VT_I2	= 2,
    VT_I4	= 3,
    VT_R4	= 4,
    VT_R8	= 5,
    VT_CY	= 6,
    VT_DATE	= 7,
    VT_BSTR	= 8,
    VT_DISPATCH	= 9,
    VT_ERROR	= 10,
    VT_BOOL	= 11,
    VT_VARIANT	= 12,
    VT_UNKNOWN	= 13,
    VT_DECIMAL	= 14,
    VT_I1	= 16,
    VT_UI1	= 17,
    VT_UI2	= 18,
    VT_UI4	= 19,
    VT_I8	= 20,
    VT_UI8	= 21,
    VT_INT	= 22,
    VT_UINT	= 23,
    VT_VOID	= 24,
    VT_HRESULT	= 25,
    VT_PTR	= 26,
    VT_SAFEARRAY	= 27,
    VT_CARRAY	= 28,
    VT_USERDEFINED	= 29,
    VT_LPSTR	= 30,
    VT_LPWSTR	= 31,
    VT_RECORD	= 36,
    VT_INT_PTR	= 37,
    VT_UINT_PTR	= 38,
    VT_FILETIME	= 64,
    VT_BLOB	= 65,
    VT_STREAM	= 66,
    VT_STORAGE	= 67,
    VT_STREAMED_OBJECT	= 68,
    VT_STORED_OBJECT	= 69,
    VT_BLOB_OBJECT	= 70,
    VT_CF	= 71,
    VT_CLSID	= 72,
    VT_VERSIONED_STREAM	= 73,
    VT_BSTR_BLOB	= 0xfff,
    VT_VECTOR	= 0x1000,
    VT_ARRAY	= 0x2000,
    VT_BYREF	= 0x4000,
    VT_RESERVED	= 0x8000,
    VT_ILLEGAL	= 0xffff,
#unwarn
    VT_ILLEGALMASKED	= 0xfff,
#unwarn
    VT_TYPEMASK	= 0xfff
}

struct VARTYPE : c_ushort
{
	public static operator Self(c_ushort);
}

[CRepr, Union]
struct PROPVARIANT
{
	[CRepr]
	public using struct
	{
		public VARTYPE vt;
		c_ushort mReserved1;
		c_ushort mReserved2;
		c_ushort mReserved3;

		[CRepr, Union]
		public using struct
		{
			public c_char cVal;
			public c_uchar bVal;
			public c_short iVal;
			public c_ushort uiVal;
			public c_long lVal;
			public c_ulong ulVal;
			public c_int intVal;
			public c_uint uintVal;
			/*public LARGE_INTEGER hVal;
			public ULARGE_INTEGER uhVal;*/
			public float fltVal;
			public double dblVal;
			/*public VARIANT_BOOL boolVal;
			public VARIANT_BOOL __OBSOLETE__VARIANT_BOOL;*/
			/*public SCODE scode;
			public CY cyVal;
			public DATE date;
			public FILETIME filetime;*/
			public GUID* puuid;
			/*public CLIPDATA *pclipdata;
			public BSTR bstrVal;
			public BSTRBLOB bstrblobVal;
			public BLOB blob;*/
			public c_char* pszVal;
			public c_wchar* pwszVal;
			public ComPtr<IUnknown> punkVal;
			/*public IDispatch *pdispVal;
			public IStream *pStream;
			public IStorage *pStorage;
			public LPVERSIONEDSTREAM pVersionedStream;
			public LPSAFEARRAY parray;
			public CAC cac;
			public CAUB caub;
			public CAI cai;
			public CAUI caui;
			public CAL cal;
			public CAUL caul;
			public CAH cah;
			public CAUH cauh;
			public CAFLT caflt;
			public CADBL cadbl;
			public CABOOL cabool;
			public CASCODE cascode;
			public CACY cacy;
			public CADATE cadate;
			public CAFILETIME cafiletime;
			public CACLSID cauuid;
			public CACLIPDATA caclipdata;
			public CABSTR cabstr;
			public CABSTRBLOB cabstrblob;
			public CALPSTR calpstr;
			public CALPWSTR calpwstr;
			public CAPROPVARIANT capropvar;*/
			public c_char* pcVal;
			public c_uchar* pbVal;
			public c_short* piVal;
			public c_ushort* puiVal;
			public c_long* plVal;
			public c_ulong* pulVal;
			public c_int* pintVal;
			public c_uint* puintVal;
			public float* pfltVal;
			public double* pdblVal;
			/*public VARIANT_BOOL *pboolVal;*/
			public DECIMAL* pdecVal;
			/*public SCODE *pscode;
			public CY *pcyVal;
			public DATE *pdate;
			public BSTR *pbstrVal;*/
			public ComPtr<IUnknown>* ppunkVal;
			/*public IDispatch **ppdispVal;
			public LPSAFEARRAY *pparray;*/
			public PROPVARIANT* pvarVal;

			uint8[16] __force_size__;
		};
	};
	public DECIMAL decVal;
}