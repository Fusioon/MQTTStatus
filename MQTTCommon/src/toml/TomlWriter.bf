using System;
using System.IO;
using System.Collections;
using System.Diagnostics;


namespace Fusion.TOML
{
	enum TomlWriterFlags
	{
		None = 0x00,
		/// Makes output formatted, each property on new line with indentation
		PrettyPrint = 0x01,
		/// Use headers instead of inline tables
		UseHeaders = 0x02,
		/// Do not use headers for arrays
		NoArrayHeaders = 0x04
	}

	struct TomlWriterConfig
	{
		public TomlWriterFlags flags;
		public int32 maxInlineElements;
	}

	public static class TomlWriter
	{
		interface ITomlWriter
		{
			void AppendF(StringView format, params Span<Object> args);
			void Append(StringView text);
			void Append(char8 c);
			void Append(char8 c, int32 count);
		}

		class StringTomlWriter : ITomlWriter
		{
			public String _target;
			public this(String target)
			{
				_target = target;
			}

			public void AppendF(StringView format, params Span<Object> args) => _target.AppendF(format, args);
			public void Append(StringView text) => _target.Append(text);
			public void Append(char8 c) => _target.Append(c);
			public void Append(char8 c, int32 count) => _target.Append(c, count);
		}

		class StreamTomlWriter : ITomlWriter
		{
			public Stream _target;

			public this(Stream target)
			{
				_target = target;
			}

			public void AppendF(StringView format, params Span<Object> args)
			{
				_target.WriteStrUnsized(scope String()..AppendF(format, params args));
			}

			public void Append(StringView text)
			{
				_target.WriteStrUnsized(text);
			}

			public void Append(char8 c)
			{
				var c;
				_target.TryWrite(.((.)&c, 1));
			}

			public void Append(char8 c, int32 count) 
			{
				_target.Write((uint8)c, count);
			}
		}

		class WriterInstance<T> where T : ITomlWriter
		{
			TomlWriterFlags _flags;
			int32 _nestLevel;
			T _writer;

			int32 _maxInlineElements;

			append String _header;
			append List<int> _headerLengths;
			append List<int32> _nestLevelStack = .(32);

			public this(TomlWriterConfig config, T writer)
			{
				this._flags = config.flags;
				if (_flags & .UseHeaders == .UseHeaders)
					_flags |= .PrettyPrint;

				this._writer = writer;
				this._maxInlineElements = config.maxInlineElements;
				this._nestLevel = 0;
			}

			[Inline]
			static void EnumerateSkipOnFirst<ValueT, EnumerableT, SkipFN, AlwaysFN>(EnumerableT enumerable, SkipFN skipFirst, AlwaysFN always)
				where EnumerableT : IEnumerable<ValueT>
				where SkipFN : delegate void (ValueT)
				where AlwaysFN : delegate void (ValueT)
			{
				var en = enumerable.GetEnumerator();
				if (en.GetNext() case .Ok(let val))
				{
					always(val);
				}

				for (let v in en)
				{
					skipFirst(v);
					always(v);
				}
			}

			[Inline]
			void AppendF(StringView format, params Span<Object> args)
			{
				_writer.AppendF(format, params args);
			}

			[Inline]
			void Append(StringView text)
			{
				_writer.Append(text);
			}

			[Inline]
			void Append(char8 c)
			{
				_writer.Append(c);
			}

			[Inline]
			void Append(char8 c, int32 count)
			{
				_writer.Append(c, count);
			}

			[Inline]
			void AppendValue<ValueT>(ValueT val)
			{
				String tmp = scope .(64);
				val.ToString(tmp);
				_writer.Append(tmp);
			}

			void WriteLineAndIndent(bool hasEnding)
			{
				if ((_nestLevel == 0 && !hasEnding) || (_flags & .PrettyPrint == .PrettyPrint))
				{
					Append('\n');
					Append('\t', _nestLevel);
				}	
			}

			void WriteValueSeparator(bool forceInline, bool hasEnding)
			{
				if (_nestLevel != 0)
					Append(", ");
				if (!forceInline)
					WriteLineAndIndent(hasEnding);
			}

			void KeyToString<WriteFN>(TomlKey key, WriteFN fn) where WriteFN : delegate void(StringView)
			{
				char8 quotes;
				switch (key.Kind)
				{
				case .Unquoted:
					fn(key.Value);
					return;

				case .Single:
					quotes = '\'';
				case .Marks:
					quotes = '"';
				}

				String tmp = new:ScopedAlloc! .(key.Value.Length + 2);
				tmp.Append(quotes);
				tmp.Append(key.Value);
				tmp.Append(quotes);
				fn(tmp);
			}

			// Return value indicates if header '[[key]]' was used
			bool WriteKey(TomlKey key, bool hasHeader, bool isArray)
			{
				if (key == null)
					return false;

				if (hasHeader && (!isArray || _flags & .NoArrayHeaders == 0))
				{
					// @TODO - needs to append "Full path header"
					_headerLengths.Add(_header.Length);

					if (_header.Length > 0)
						_header.Append('.');
					KeyToString(key, => _header.Append);

					if (isArray)
					{
						Append("[[");
						Append(_header);
						Append("]]");
					}
					else
					{
						Append("[");
						Append(_header);
						Append("]");
					}

					_nestLevelStack.Add(_nestLevel);
					_nestLevel = 0;

					return true;
				}

				KeyToString(key, => this.Append);
				Append(" = ");
				return false;
			}

			bool CanUseHeader(TomlValue val)
			{
				if (_flags & .UseHeaders != .UseHeaders)
					return false;

				switch (val)
				{
				case .Array(let v):
					return v.HasOnlyObjects;
				case .Object:
					return true;
				default:
					return false;
				}
			}

			void WriteValueAndKey(TomlKey key, TomlValue value)
			{
				let hasHeader = WriteKey(key, CanUseHeader(value), value case .Array);

				switch (value)
				{
				case .Null:

				case .Bool(let val): Append(val ? "true" : "false");
				case .Int(let val): AppendValue(val);
				case .UInt(let val): AppendValue(val);
				case .Double(let val):
					{
						if (val.IsNaN)
							Append("nan");
						else if (val.IsNegativeInfinity)
							Append("-inf");
						else if (val.IsPositiveInfinity)
							Append("+inf");
						else
							AppendValue(val);
					}
				case .String(let val):
					{
						 // @TODO - do actual escape of characters
						 Append('"');
						 Append(val);
						 Append('"');
					}
				case .MultilineString(let val):
					{
						Append("\"\"\"");
						Append(val);
						Append("\"\"\"");
					}
				case .UnescapedString(let val):
					{
						Append('\'');
						Append(val);
						Append('\'');

					}
				case .UnescapedMultilineString(let val):
					{
						Append("'''");
						Append(val);
						Append("'''");
					}
				case .Object(let val):
					{
						if (!hasHeader)
						{
							Append('{');
							++_nestLevel;
						}

						WriteLineAndIndent(false);

						EnumerateSkipOnFirst<TomlObject.KeyValT...>(val,
							(v) => {
								WriteValueSeparator(false, false);
							},
							(v) => {
								WriteValueAndKey(v.key, v.value);
							});

						--_nestLevel;
						WriteLineAndIndent(true);
					
						if (!hasHeader)
						{
							Append('}');
						}
						else
						{
							_header.RemoveToEnd(_headerLengths.PopBack());
							_nestLevel = _nestLevelStack.PopBack();
						}
					}
				case .Array(let val):
					{
						if (!hasHeader)
						{
							Append('[');
							++_nestLevel;
						}

						bool forceInline = (_nestLevel > 0 && _flags.HasFlag(.PrettyPrint) && val.Count <= _maxInlineElements);
						if (!forceInline)
							WriteLineAndIndent(false);

						EnumerateSkipOnFirst<TomlValue...>(val,
							(v) => {
								WriteValueSeparator(forceInline, false);
							},
							(v) => {
								WriteValueAndKey(null, v);
							});

						--_nestLevel;
						if (!forceInline)
							WriteLineAndIndent(true);

						if (!hasHeader)
						{
							Append(']');
						}
						else
						{
							_header.RemoveToEnd(_headerLengths.PopBack());
							_nestLevel = _nestLevelStack.PopBack();
						}
					}

				case .DateTime(let v):
					{
						
					}
				}	 
			}

			public void Write(TomlDocument doc)
			{
				EnumerateSkipOnFirst<TomlObject.KeyValT...>(doc,
					(val) => {
						WriteValueSeparator(false, false);
					},
					(val) => {
						WriteValueAndKey(val.key, val.value);
					});
			}

		}

		public static void WriteToString(TomlDocument doc, TomlWriterConfig config, String buffer)
		{
			scope WriterInstance<StringTomlWriter>(config, scope .(buffer)).Write(doc);
		}

		public static void WriteToStream(TomlDocument doc, TomlWriterConfig config, Stream stream)
		{
			Debug.Assert(stream.CanWrite);
			scope WriterInstance<StreamTomlWriter>(config, scope .(stream)).Write(doc);
		}

		public static Result<void, FileOpenError> WriteToFile(TomlDocument doc, TomlWriterConfig config, StringView filePath, bool allowOverwrite)
		{
			FileStream fs = scope .();

			if(fs.Open(filePath, (allowOverwrite ? FileMode.Create : FileMode.CreateNew) , .Write) case .Err(let err))
				return .Err(err);

			WriteToStream(doc, config, fs);
			return .Ok;
		}
	}
}