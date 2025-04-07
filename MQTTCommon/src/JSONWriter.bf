using System;
using System.IO;

namespace MQTTCommon;

class JSONWriter
{
	public enum ECurrentDataType
	{
		case Array,
		Object;

		public String StartChar
		{
			get
			{
				switch (this)
				{
				case .Array: return "[";
				case .Object: return "{";
				}
			}
		}

		public String EndChar
		{
			get
			{
				switch (this)
				{
				case .Array: return "]";
				case .Object: return "}";
				}
			}
		}
	}

	[NoDiscard]
	public struct ObjectDisposer : IDisposable
	{
		public JSONWriter writer;
		public ECurrentDataType previous;

		public this(JSONWriter discoveryWriter, ref ECurrentDataType currentDataType, ECurrentDataType newDataType)
		{
			writer = discoveryWriter;
			previous = currentDataType;
			currentDataType = newDataType;
		}

		public void Dispose()
		{
			writer.EndDataType(previous);
		}
	}

	public char8 indentChar = '\t';
	append String _indent = .(24);

	StreamWriter _writer ~ delete:append _;
	append String _buffer = .(64);

	ECurrentDataType _currentType;
	bool isFirstValue = true;

	[AllowAppend]
	public this(Stream stream, ECurrentDataType startDataType = .Object)
	{
		let streamWriter = append StreamWriter(stream, System.Text.Encoding.UTF8, 2048);
		_writer = streamWriter;

		_currentType = startDataType;
	}

	void WriteIndent()
	{
		_writer.Write(_indent);
	}

	void WriteEscapedString(StringView val)
	{
		// @TODO - add escape
		_writer.Write(val);
	}

	protected ObjectDisposer BeginDataType(StringView key, ECurrentDataType type)
	{
		WriteKey(key);
		_indent.Append(indentChar);
		isFirstValue = true;
		_writer.Write(type.StartChar);
		_writer.WriteLine();
		return .(this, ref _currentType, type);
	}

	protected void EndDataType(ECurrentDataType prevType)
	{
		_writer.WriteLine();
		_indent.Length -= 1;
		WriteIndent();
		_writer.Write(_currentType.EndChar);

		isFirstValue = false;
		_currentType = prevType;
	}

	public ObjectDisposer BeginArray(StringView key) => BeginDataType(key, .Array);

	public ObjectDisposer BeginObject(StringView key) => BeginDataType(key, .Object);

	void WriteKey(StringView key)
	{
		if (!isFirstValue)
		   _writer.Write(",\n");

		isFirstValue = false;

		if (_currentType == .Array)
			return;

		WriteIndent();
		_writer.Write("\"");
		WriteEscapedString(key);
		_writer.Write("\": ");
	}	

	public void WriteValueI32(StringView key, int32 val)
	{
		WriteKey(key);
		val.ToString(_buffer..Clear());
		_writer.Write(_buffer);
	}

	public void WriteValueI64(StringView key, int64 val)
	{
		WriteKey(key);
		val.ToString(_buffer..Clear());
		_writer.Write(_buffer);
	}

	public void WriteValueU32(StringView key, uint32 val)
	{
		WriteKey(key);
		val.ToString(_buffer..Clear());
		_writer.Write(_buffer);
	}

	public void WriteValueU64(StringView key, uint64 val)
	{
		WriteKey(key);
		val.ToString(_buffer..Clear());
		_writer.Write(_buffer);
	}

	public void WriteValueF(StringView key, float val)
	{
		WriteKey(key);
		val.ToString(_buffer..Clear());
		_writer.Write(_buffer);
	}

	public void WriteValueStr(StringView key, StringView val)
	{
		WriteKey(key);

		_writer.Write("\"");
		WriteEscapedString(val);
		_writer.Write("\"");
	}
}