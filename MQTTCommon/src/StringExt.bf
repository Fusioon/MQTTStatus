using System.Text;
using System.Interop;

namespace System;

extension String
{
	public mixin ToScopedNativeWChar(out int encodedLen)
	{
		encodedLen = UTF16.GetEncodedLen(this);
		c_wchar* buf;
		if (encodedLen < 128)
		{
			buf = scope:mixin c_wchar[encodedLen+1]* ( ? );
		}
		else
		{
			buf = new c_wchar[encodedLen+1]* ( ? );
			defer:mixin delete buf;
		}

		if (sizeof(c_wchar) == 2)
			UTF16.Encode(this, (.)buf, encodedLen);
		else
			UTF32.Encode(this, (.)buf, encodedLen);
		buf[encodedLen] = 0;
		buf
	}
}

extension StringView
{
	public mixin ToScopedNativeWChar(out int encodedLen)
	{
		encodedLen = UTF16.GetEncodedLen(this);
		c_wchar[] buf;
		if (encodedLen < 128)
		{
			buf = scope:mixin c_wchar[encodedLen+1] ( ? );
		}
		else
		{
			buf = new c_wchar[encodedLen+1] ( ? );
			defer:mixin delete buf;
		}

		if (sizeof(c_wchar) == 2)
			UTF16.Encode(this, (.)buf.Ptr, encodedLen);
		else
			UTF32.Encode(this, (.)buf.Ptr, encodedLen);
		buf[encodedLen] = 0;
		buf
	}
}