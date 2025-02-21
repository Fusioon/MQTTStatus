using System;
using System.IO;
using System.Collections;
using System.Diagnostics;

using internal Fusion.TOML;

namespace Fusion.TOML
{
	enum TomlReadError
	{
		case UnexpectedToken;
		case ParseError;
		case FileOpenError(FileOpenError);
	}

	enum TomlValue
	{
		case Null;
		case Bool(bool v);
		case Int(int64 v);
		case UInt(uint64 v);
		case Double(double v);
		case String(StringView v);
		case MultilineString(StringView v);
		case UnescapedString(StringView v);
		case UnescapedMultilineString(StringView v);
		case Array(TomlArray v);
		case Object(TomlObject v);

		case DateTime(DateTime v);

		public bool IsString
		{
			get
			{
				switch (this)
				{
				case .String, .MultilineString, .UnescapedString, .UnescapedMultilineString:
					return true;
				case .Null, .Bool, .Int, .UInt, .Double, .Array, .Object, .DateTime:
					return false;
				}
			}
		}

		public void SetStringType(bool multiline, bool unescaped) mut
		{
			StringView v;
			switch (this)
			{
			case .String(out v), .MultilineString(out v), .UnescapedString(out v), .UnescapedMultilineString(out v):
				{
					if (multiline)
					{
						if (unescaped)
							this = .UnescapedMultilineString(v);
						else
							this = .MultilineString(v);
					}
					else
					{
						if (unescaped)
							this = .UnescapedString(v);
						else
							this = .String(v);
					}
				}


			case .Null, .Bool, .Int, .UInt, .Double, .Array, .Object, .DateTime:
			}
		}

		public Result<bool> AsBool()
		{
			switch (this)
			{
			case .Bool(let v): return v;
			case .Int(let v): return v != 0;
			case .UInt(let v): return v != 0;
			case .Double(let v): return v != 0;
			default: return .Err;
			}
		}

		public Result<T> AsInt<T>()
			where T : IInteger
			where T : operator explicit int64
			where T : operator explicit uint64
		{
			switch (this)
			{
			case .Int(let v): return (T)v;
			case .UInt(let v): return (T)v;
			case .Double(let v): return (T)((int64)v);
			default: return .Err;
			}
		}

		public Result<int32> AsInt32() => AsInt<int32>();
		public Result<uint32> AsUInt32() => AsInt<uint32>();

		public Result<int64> AsInt64() => AsInt<int64>();
		public Result<uint64> AsUInt64() => AsInt<uint64>();

		public Result<float> AsFloat()
		{
			switch (this)
			{
			case .Int(let v): return (float)v;
			case .UInt(let v): return (float)v;
			case .Double(let v): return (float)v;
			default: return .Err;
			}
		}

		public Result<double> AsDouble()
		{
			switch (this)
			{
			case .Int(let v): return (double)v;
			case .UInt(let v): return (double)v;
			case .Double(let v): return v;
			default: return .Err;
			}
		}

		public Result<StringView> AsString()
		{
			StringView v;
			switch (this)
			{
			case .String(out v), .MultilineString(out v), .UnescapedString(out v), .UnescapedMultilineString(out v):
				{
					return v;
				}

			default: return .Err;
			}
		}

		public Result<TomlObject> AsObject()
		{
			if (this case .Object(let v))
				return v;

			return .Err;
		}

		public Result<TomlArray> AsArray()
		{
			if (this case .Array(let v))
				return v;

			return .Err;
		}

		public Result<DateTime> AsDateTime()
		{
			return .Err;
		}

		public Result<T> AsEnum<T>()
			where T : Enum, enum
		{
			switch (this)
			{
			case .Int(let v):
				{
					if (Enum.IsDefined<T>(((T)v)))
						return (T)v;
				}
			case .UInt(let v):
				{
					if (Enum.IsDefined<T>(((T)v)))
						return (T)v;
				}
			case .String(let v), .UnescapedString(v):
				{
					if (Enum.Parse<T>(v, true) case .Ok(let val))
						return val;
				}
			default: break;
			}
			return .Err;
		}
	}

	enum TomlKeyKind
	{
		Unquoted,
		Single,	// Use '
		Marks	// Use "
	}

	class TomlKey : IHashable
	{
		private TomlKeyKind _kind;
		private String _value ~ delete:append _;

		public String Value => _value;
		public TomlKeyKind Kind => _kind;

		[AllowAppend]
		public this(StringView strView, TomlKeyKind kind)
		{
			let val = append String(strView);
			_value = val;
			_kind = kind;
		}

		public int GetHashCode() => _value.GetHashCode();
		public override void ToString(String strBuffer)
		{
			strBuffer.Append(_value);
		}

		[Commutable]
		public static bool operator ==(Self left, StringView right)
		{
			return (left._value == right);
		}

		[Commutable]
		public static bool operator ==(Self left, String right)
		{
			return (left._value == right);
		}
	}

	internal static
	{
		internal static TomlKeyKind GetKeyKind(StringView key)
		{
			char8 prevC = 0;
			for (let c in key)
			{
				if (!c.IsLetterOrDigit && c != '_' && c != '-')
					return .Single;

				prevC = c;
			}

			return .Unquoted;
		}
	}

	abstract class TomlObjectBase
	{
		public TomlObjectBase Parent { get; }
		public virtual bool IsArray => false;

		protected TomlDocument _doc;
		public TomlDocument Document => _doc;

		public abstract int Count { get; }

		protected this(TomlObjectBase parent)
		{
			Parent = parent;
			_doc = parent._doc;
		}

		protected this(TomlDocument doc)
		{
			Parent = doc;
			_doc = doc;
		}

		protected void* Alloc(int size, int align) => _doc.[Friend]Allocate(size, align);
		protected void* AllocTyped(Type type, int size, int align) => _doc.[Friend]AllocateTyped(type, size, align);
		protected void Free(void* ptr) => _doc.[Friend]FreePtr(ptr);

		public abstract TomlObject AddObject(StringView key);
		public abstract TomlArray AddArray(StringView key);
		public abstract TomlValue* AddValue(StringView key, bool v);
		public abstract TomlValue* AddValue(StringView key, int64 v);
		public abstract TomlValue* AddValue(StringView key, uint64 v);
		public abstract TomlValue* AddValue(StringView key, float v);
		public abstract TomlValue* AddValue(StringView key, double v);
		public abstract TomlValue* AddValue(StringView key, StringView v);

		public abstract TomlValue* ReadValue(StringView key, int32 index);

	}

	class TomlObject : TomlObjectBase, IEnumerable<KeyValT>
	{
		public typealias KeyValT = (TomlKey key, TomlValue value);

		internal this(TomlObjectBase parent) : base(parent)
		{
			
		}

		protected this(TomlDocument doc) : base(doc)
		{
			
		}

		public ~this()
		{
			for (let (key,val) in _map)
			{
				delete:this key;
				switch (val)
				{
				case .Object(let v):
					{
						delete:this v;
					}
				case .Array(let v):
					{
						delete:this v;
					}
				default:
				}
			}
			
		}

		append protected Dictionary<TomlKey, TomlValue> _map;
		public Dictionary<TomlKey, TomlValue>.Enumerator GetEnumerator() => _map.GetEnumerator();
		public Dictionary<TomlKey, TomlValue>.KeyEnumerator Keys => _map.Keys;
		public Dictionary<TomlKey, TomlValue>.ValueEnumerator Values => _map.Values;
		public override int Count => _map.Count;

		public Result<TomlValue> this[StringView key]
		{
			get => _map.TryGetValueAlt(key, let v) ? v : .Err;
		}

		public TomlValue this[StringView key]
		{
			set
			{
				if (TryAdd(key, let ptr))
				{
					*ptr = value;
				}
			}
		}

		bool TryAdd(StringView key, out TomlValue* valPtr)
		{
			//Debug.Assert(key.IndexOf('.') == -1);	// If this ever triggers we have bug in parser
			if(_map.TryAddAlt(key, let keyPtr, out valPtr))
			{
				(*keyPtr) = new:this TomlKey(key, GetKeyKind(key));
				return true;
			}

			// PrintError();
			return false;
		}

		public override TomlObject AddObject(StringView key)
		{
			if (TryAdd(key, let ptr))
			{
				let obj = new:this TomlObject(this);
				*ptr = .Object(obj);
				return obj;
			}

			if (*ptr case .Object(let v))
				return v;

			return null;
		}

		public override TomlArray AddArray(StringView key)
		{
			if (TryAdd(key, let ptr))
			{
				let arr = new:this TomlArray(this);
				*ptr = .Array(arr);
				return arr;
			}
			if (*ptr case .Array(let v))
				return v;

			return null;
		}

		public override TomlValue* AddValue(StringView key, bool v)
		{
			if (TryAdd(key, let ptr))
			{
				*ptr = .Bool(v);
				return ptr;
			}
			return null;
		}

		public override TomlValue* AddValue(StringView key, int64 v)
		{
			if (TryAdd(key, let ptr))
			{
				*ptr = .Int(v);
				return ptr;
			}
			return null;
		}

		public override TomlValue* AddValue(StringView key, uint64 v)
		{
			if (TryAdd(key, let ptr))
			{
				*ptr = .UInt(v);
				return ptr;
			}
			return null;
		}

		public override TomlValue* AddValue(StringView key, float v)
		{
			if (TryAdd(key, let ptr))
			{
				*ptr = .Double(v);
				return ptr;
			}
			return null;
		}

		public override TomlValue* AddValue(StringView key, double v)
		{
			if (TryAdd(key, let ptr))
			{
				*ptr = .Double(v);
				return ptr;
			}
			return null;
		}

		public override TomlValue* AddValue(StringView key, StringView v)
		{
			if (TryAdd(key, let ptr))
			{
				*ptr = .String(_doc.AllocateString(v));
				return ptr;
			}
			return null;
		}

		public override TomlValue* ReadValue(StringView key, int32 index)
		{
			if (_map.TryGetRefAlt(key, let ptrKey, var ptrValue))
				return ptrValue;

			return null;
		}
	}

	class TomlArray : TomlObjectBase, IEnumerable<TomlValue>
	{
		public override bool IsArray => true;

		internal this(TomlObjectBase parent) : base(parent)
		{
			
		}

		public ~this()
		{
			for (let val in _values)
			{
				switch (val)
				{
				case .Object(let v):
					{
						delete:this v;
					}
				case .Array(let v):
					{
						delete:this v;
					}
				default:
				}
			}

		}

		append List<TomlValue> _values;
		int _objectsCount;
		public int ObjectsCount => _objectsCount;
		public bool HasOnlyObjects => _objectsCount > 0 && _objectsCount == _values.Count;

		public override int Count => _values.Count;
		public ref TomlValue this[int i] => ref _values[i];
		public List<TomlValue>.Enumerator GetEnumerator() => _values.GetEnumerator();

		public TomlObject AddObject()
		{
			_objectsCount++;
			let obj = new:this TomlObject(this);
			_values.Add(.Object(obj));
			return obj;
		}

		public TomlArray AddArray()
		{
			let arr = new:this TomlArray(this);
			_values.Add(.Array(arr));
			return arr;
		}

		public TomlValue* AddValue(bool v)
		{
			_values.Add(.Bool(v));
			return &_values.Back;
		}

		public TomlValue* AddValue(int64 v)
		{
			_values.Add(.Int(v));
			return &_values.Back;
		}

		public TomlValue* AddValue(uint64 v)
		{
			_values.Add(.UInt(v));
			return &_values.Back;
		}

		public TomlValue* AddValue(float v)
		{
			_values.Add(.Double(v));
			return &_values.Back;
		}

		public TomlValue* AddValue(double v)
		{
			_values.Add(.Double(v));
			return &_values.Back;
		}

		public TomlValue* AddValue(StringView v)
		{
			let val = _doc.AllocateString(v);
			_values.Add(.String(val));
			return &_values.Back;
		}

		public override TomlObject AddObject(StringView key) => AddObject();

		public override TomlArray AddArray(StringView key) => AddArray();

		public override TomlValue* AddValue(StringView key, bool v) => AddValue(v);

		public override TomlValue* AddValue(StringView key, int64 v) => AddValue(v);

		public override TomlValue* AddValue(StringView key, uint64 v) => AddValue(v);

		public override TomlValue* AddValue(StringView key, float v) => AddValue(v);

		public override TomlValue* AddValue(StringView key, double v) => AddValue(v);

		public override TomlValue* AddValue(StringView key, StringView v) => AddValue(v);

		public override TomlValue* ReadValue(StringView key, int32 index)
		{
			if (index < _values.Count)
				return &_values[index];

			return null;
		}
	}

	class TomlDocument : TomlObject
	{
		append List<String> _allocatedStrings;

		public this() : base(this)
		{
		}

		public ~this()
		{
			if (!NeedsDelete)
				return;

			for (let k in _allocatedStrings)
				delete:this k;
		}

		protected virtual bool NeedsDelete => true;

		protected virtual void* Allocate(int size, int align)
		{
			return new [Align(align)]uint8[size]*(?);
		}
		
		protected virtual void* AllocateTyped(Type t, int size, int align)
		{
			return Alloc(size, align);
		}

		protected virtual void FreePtr(void* ptr)
		{
			delete ptr;
		}

		internal String AllocateString(StringView data)
		{
			return _allocatedStrings.Add(.. new:this String(data));
		}

		void OnReadError(String err, int pos, int line, int col)
		{
			//Console.WriteLine($"{err} ({line}:{col})");
		}

		public Result<void, TomlReadError> ReadFromStream(Stream stream, ErrorHandler errHandler = null)
		{
			StreamReader reader = scope .(stream);
			TOMLStreamSource source = .(reader);
			let parser = scope TOMLParser<TOMLStreamSource>(this, source, errHandler ?? scope => OnReadError);
			return parser.Parse();
		}

		public Result<void, TomlReadError> ReadFromFile(StringView filePath, ErrorHandler errHandler = null)
		{
			FileStream fs = scope .();
			switch (fs.Open(filePath, .Open, .Read))
			{
			case .Ok:
				{
					StreamReader reader = scope .(fs);
					TOMLStreamSource source = .(reader);
					let parser = scope TOMLParser<TOMLStreamSource>(this, source, errHandler ?? scope => OnReadError);
					return parser.Parse();
				}
			case .Err(let err):
				 {
					 return .Err(.FileOpenError(err));
				}
			}
		}

		public Result<void, TomlReadError> ReadFromString(StringView view, ErrorHandler errHandler = null)
		{
			TOMLStringSource source = .(view);
			let parser = scope TOMLParser<TOMLStringSource>(this, source, errHandler ?? scope => OnReadError);
			return parser.Parse();
		}
	}


}