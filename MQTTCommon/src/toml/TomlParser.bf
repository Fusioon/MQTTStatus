using System;
using System.IO;
using System.Collections;
using System.Diagnostics;

using internal Fusion.TOML;

// @TODO - implement DateTime parsing

namespace Fusion.TOML
{
	internal interface TOMLParserSource
	{
		int CurrentPos { get; }
		char8 ReadChar();
		void Advance() mut;
		bool IsEnd();
	}

	internal struct TOMLStringSource : TOMLParserSource
	{
		char8* startPtr, ptr, endPtr;


		public this(StringView str)
		{
			startPtr = str.Ptr;
			ptr = startPtr;
			endPtr = ptr + str.Length;
		}

		[Inline]
		public int CurrentPos => (ptr - startPtr);

		[Inline]
		public char8 ReadChar()
		{
			return *ptr;
		}

		[Inline]
		public void Advance() mut
		{
			if (ptr != endPtr)
				ptr++;
		}

		[Inline]
		public bool IsEnd()
		{
			return ptr == endPtr;
		}
	}

	internal struct TOMLStreamSource : TOMLParserSource
	{
		char8 current;
		int pos;
		StreamReader reader;
		bool isEnd = false;

		public this(StreamReader _reader)
		{
			pos = 0;
			current = 0;
			reader = _reader;
			Advance();
		}

		[Inline]
		public int CurrentPos => pos;

		public char8 ReadChar()
		{
			return current;
		}

		public void Advance() mut
		{
			if (isEnd)
				return;

			if (reader.Read() case .Ok(let val))
			{
				pos++;
				current = val;
			}
			else
			{
				isEnd = true;
			}

		}

		public bool IsEnd()
		{
			return isEnd;
		}
	}

	public delegate void ErrorHandler(String err, int pos, int line, int col);

	public struct TomlDocWriter
	{
		TomlDocument _doc;
		public String key = null;
		TomlObjectBase _currentTarget;

		public uint32 nestLevel = 0;

		public this(TomlDocument doc)
		{
			_doc = doc;
			_currentTarget = doc;
		}

		public bool InValidState => _currentTarget == _doc;

		public void WriteValue(bool v)
		{
			_currentTarget.AddValue(key, v);
		}

		public void WriteValue(int64 v) 
		{
			_currentTarget.AddValue(key, v);
		}

		public void WriteValue(uint64 v)
		{
			_currentTarget.AddValue(key, v);
		}

		public void WriteValue(double v) 
		{
			_currentTarget.AddValue(key, v);
		}

		public TomlValue* WriteValue(StringView v) 
		{
			return _currentTarget.AddValue(key, v);
		}

		public void WriteValueObject() mut
		{
			nestLevel++;
			let obj = _currentTarget.AddObject(key);
			Debug.Assert(obj != null);
			_currentTarget = obj;
		}

		public void WriteValueArray() mut
		{
			nestLevel++;
			let arr = _currentTarget.AddArray(key);
			Debug.Assert(arr != null);
			_currentTarget = arr;
		}

		public void ResetTopLevel() mut
		{
			Debug.Assert(nestLevel == 0);
			_currentTarget = _currentTarget.Document;
			key = null;
		}

		public TomlObject WriteToplevelObject(String key) mut
		{
			Debug.Assert(nestLevel == 0);
			let obj = _currentTarget.AddObject(key);
			Debug.Assert(obj != null);
			_currentTarget = obj;
			return obj;
		}

		public TomlArray WriteTopLevelArray(String key) mut
		{
			Debug.Assert(nestLevel == 0);
			let arr = _currentTarget.AddArray(key);
			Debug.Assert(arr != null);
			_currentTarget = arr;
			return arr;
		}

		public void Pop() mut
		{
			System.Diagnostics.Debug.Assert(nestLevel != 0);
			nestLevel--;
			_currentTarget = _currentTarget.Parent;
			Debug.Assert(_currentTarget != null);
			key = null;
		}
		
	}

	public class TomlDocReader
	{
		public String key = null;
		public int32 index = 0;
		public TomlObjectBase _currentTarget;

		append List<int32> _indexStack;

		public void Init(TomlDocument doc)
		{
			_currentTarget = doc;
			_indexStack.Add(0);
		}

		mixin TryRead<T>()
		{
			TomlValue val;
			if (let ptr = _currentTarget.ReadValue(key, index))
			{
				index++;
				val = *ptr;
			}
			else
				return Result<T>.Err;

			val
		}

		public Result<bool> ReadBool()
		{
			return TryRead!<bool>().AsBool();
		}

		public Result<int64> ReadInt()
		{
			return TryRead!<int64>().AsInt<int64>();
		}

		public Result<uint64> ReadUInt()
		{
			return TryRead!<uint64>().AsInt<uint64>();
		}

		public Result<float> ReadFloat()
		{
			return TryRead!<float>().AsFloat();
		}

		public Result<double> ReadDouble()
		{
			return TryRead!<double>().AsDouble();
		}

		public Result<StringView> ReadString()
		{
			return TryRead!<StringView>().AsString();
		}

		public Result<TomlArray> ReadArray()
		{
			if (TryRead!<TomlArray>().AsArray() case .Ok(let arr))
			{
				_indexStack.Add(index);
				index = 0;
				_currentTarget = arr;
				return arr;
			}
			
			return .Err;
		}

		public Result<TomlObject> ReadObject()
		{
			if (TryRead!<TomlObject>().AsObject() case .Ok(let obj))
			{
				_indexStack.Add(index);
				index = 0;
				_currentTarget = obj;
				return obj;
			}

			return .Err;
		}

		public TomlObjectBase Pop(String Caller = Compiler.CallerFileName, int CallerLine = Compiler.CallerLineNum)
		{
			index = _indexStack.PopBack();
			return _currentTarget = _currentTarget.Parent;
		}
	}

	internal class TOMLParser<Source>
		where Source : TOMLParserSource
	{
		int _currentLineStart = 0;
		uint32 _currentLine = 1;
		String _currentTopLevelKey = new .() ~ delete _;

		int _prevRecoverPosition = 0;

		Source _source;
		ErrorHandler _errorHandler;
		TomlDocument _doc;
		TomlDocWriter _writer;

		public this(TomlDocument doc, Source source, ErrorHandler err)
		{
			_doc = doc;
			_source = source;
			_errorHandler = err;
			_writer = .(_doc);
		}

		[Inline]
		char8 ReadChar() => _source.ReadChar();
		[Inline]
		void Advance() => _source.Advance();
		[Inline]
		bool IsEnd => _source.IsEnd();
		[Inline]
		int CurrentPos => _source.CurrentPos;
		[Inline]
		void ReportError(String err)
		{
			_errorHandler(err, CurrentPos, _currentLine, CurrentPos - _currentLineStart);
		}

		bool Match(char8 c)
		{
			if (ReadChar() == c)
			{
				Advance();
				return true;
			}

			return false;
		}

		bool Match<N>(char8[N] chars) where N : const int
		{
			let cc = ReadChar();
			for (let c in chars)
			{
				if (cc == c)
				{
					Advance();
					return true;
				}	
			}

			return false;
		}


		void SkipWhitespace()
		{
			while(!IsEnd)
			{
				let c = ReadChar();
				switch (c)
				{
				case ' ', '\t', '\r':
				case '\n':
					_currentLine++;
					_currentLineStart = CurrentPos;
				default:
					return;
				}
				Advance();
			}
		}

		void SkipWhitespaceNoNewLine()
		{
			while(!IsEnd)
			{
				let c = ReadChar();
				switch (c)
				{
				case ' ', '\t', '\r':
				default:
					return;
				}
				Advance();
			}
		}

		bool SkipComment()
		{
			if (Match('#'))
			{
				SkipLine();
				return true;
			}
			return false;
		}

		void SkipCommentsAndWhitespace()
		{
			int start;
			repeat
			{
				start = CurrentPos;
				SkipWhitespace();
				SkipComment();
			}
			while(CurrentPos != start && !IsEnd);
		}

		void SkipLine()
		{
			while(!IsEnd)
			{
				if (ReadChar() == '\n')
				{
					_currentLine++;
					_currentLineStart = CurrentPos;
					Advance();

					return;
				}

				Advance();
			}
		}

		bool ParseString_Quotation(String buffer, bool allowMultiline, out bool wasMultiline)
		{
			wasMultiline = ?;
			if (!Match('"') || IsEnd)
				return false;

			bool ParseMultiline()
			{
				return false;
			}

			bool ParseSingle()
			{
				char8 prevC = 0;
				while (!IsEnd)
				{
					let c = ReadChar();

					if (c == '"' && prevC != '\\')
					{
						Advance();
						return true;
					}	

					if (prevC == '\\')
					{
						switch (c)
						{
						case 't': buffer.Append('\t');
						case 'n': buffer.Append('\n');
						case 'r': buffer.Append('\r');
						case 'b': buffer.Append('\b');
						case 'f': buffer.Append('\f');
						case '\'': buffer.Append('\'');
						case '\\': buffer.Append('\\');
						case '"': buffer.Append('"');
						case 'u': // @TODO - parse unicode sequence
						default: ReportError(scope $"Unrecognized escape sequence '\\{c}'");
						}
					}
					else
						buffer.Append(c);

					prevC = c;
					Advance();
				}

				ReportError("Unexpected EOF while parsing string literal");
				return false;
			}
			
			if (Match('"'))
			{
				if (IsEnd)
				{
					wasMultiline = false;
					return true;
				}

				if (Match('"'))
				{
					if (!allowMultiline)
					{
						ReportError("Unexpected multiline string");
						return false;
					}

					wasMultiline = true;
					return ParseMultiline();
				}
				return true;
			}

			wasMultiline = false;
			return ParseSingle();
		}

		bool ParseString_SingleQuote(String buffer, bool allowMultiline, out bool wasMultiline)
		{
			wasMultiline = ?;
			if (!Match('\'') || IsEnd)
				return false;

			bool ParseSingle()
			{
				while (!IsEnd)
				{
					let c = ReadChar();
					if (c == '\'')
					{
						Advance();
						return true;
					}	
					if (c == '\n')
						ReportError("Unexpected newline in string literal");

					buffer.Append(c);
					Advance();
				}

				return false;
			}

			bool ParseMultiline()
			{
				char8 prevC = 0;
				char8 prevC2 = 0;
				while (!IsEnd)
				{
					let c = ReadChar();

					if (c == '\'' && prevC == '\'' && prevC2 == '\'')
					{
						buffer.RemoveFromEnd(2);
						buffer.TrimEnd();
						Advance();
						return true;
					}

					buffer.Append(c);
					Advance();
					prevC2 = prevC;
					prevC = c;
				}

				return false;
			}

			if (Match('\''))
			{
				if (IsEnd)
				{
					wasMultiline = false;
					return true;
				}

				if (Match('\''))
				{
					if (!allowMultiline)
					{
						ReportError("Unexpected multiline string");
						return false;
					}
					wasMultiline = true;
					SkipWhitespace();
					return ParseMultiline();
				}
				
				return true;
			}

			wasMultiline = false;
			return ParseSingle();
		}

		bool ParseIdentifier(String buffer)
		{
			{
				let c = ReadChar();
				if (c != '_' && !c.IsLetter)
					return false;
			}

			while (!IsEnd)
			{
				let c = ReadChar();
				if (c.IsLetterOrDigit || c == '_')
				{
					buffer.Append(c);
				}
				else
					break;

				Advance();
			}

			return true;
		}

		enum KeyKind
		{
			Error = 0,
			Inline,
			TopLevel
		}

		KeyKind ParseKey(String buffer)
		{
			bool IsValidChar(char8 c) => c.IsLetterOrDigit || c == '-' || c == '_';

			let c = ReadChar();

			if (c == '\'')
			{
				if (ParseString_SingleQuote(buffer, false, ?))
					return .Inline;
				else
					return .Error;
			}
			else if (c == '"')
			{
				if (ParseString_Quotation(buffer, false, ?))
					return .Inline;
				else
					return .Error;
			}
			else if (IsValidChar(c))
			{
				while (!IsEnd)
				{
					var c;
					c = ReadChar();
					if (IsValidChar(c))
					{
						buffer.Append(c);
					}
					else
						return .Inline;

					Advance();
				}

				return .Inline;
			}

			ReportError(scope $"Unexpected character '{c}' while parsing key");
			return .Error;
		}

		KeyKind ParseToplevelKey(String buffer)
		{
			if (Match('['))
			{
				_writer.ResetTopLevel();
				if (Match('['))
				{
					while (!IsEnd)
					{
						let result = ParseKey(buffer);
						if (result == .Error)
							return .Error;

						SkipWhitespaceNoNewLine();
						if (Match('.'))
						{
							SkipWhitespaceNoNewLine();
							_writer.WriteToplevelObject(buffer);
							buffer.Clear();
						}
						else if (Match(']') && Match(']'))
						{
							_writer.WriteTopLevelArray(buffer);
							break;
						}
						else
						{
							ReportError("Expected ']]' or '.' while parsing key");
							return .Error;
						}
					}
					return .TopLevel;
				}

				while (!IsEnd)
				{
					let result = ParseKey(buffer);
					if (result == .Error)
						return .Error;

					SkipWhitespaceNoNewLine();
					if (Match('.'))
					{
						SkipWhitespaceNoNewLine();
						_writer.WriteToplevelObject(buffer);
						buffer.Clear();
					}
					else if (Match(']'))
					{
						_writer.WriteToplevelObject(buffer);
						break;
					}
					else
					{
						ReportError("Expected ']' or '.' while parsing key");
						return .Error;
					}
				}
				return .TopLevel;
			}

			return ParseKey(buffer);
		}

		Result<void> ParseObject()
		{
			if (!Match('{'))
				return .Err;

			SkipCommentsAndWhitespace();

			_writer.WriteValueObject();
			defer _writer.Pop();

			String key = scope .();

			while (!IsEnd)
			{
				SkipCommentsAndWhitespace();
				if (Match('}'))
					return .Ok;

				key.Clear();
				let type = ParseKey(key);
				if (type != .Inline)
				{
					ReportError(scope $"Unexpected key type {type}");
					return .Err;
				}
				else
					_writer.key = key;

				SkipWhitespaceNoNewLine();

				if (!Match('='))
				{
					ReportError("Expected '=' after key");
					return .Err;
				}

				SkipWhitespace();
				if (ParseValue() case .Err)
				{
					return .Err;
				}
				
				SkipCommentsAndWhitespace();
				if (Match('}'))
				{
					break;
				}
				else if (Match(','))
				{
					
				}
				else
				{
					ReportError("Unexpected char");
					return .Err;
				}
			}

			return .Ok;
		}

		Result<void> ParseArray()
		{
			if (!Match('['))
				return .Err;

			SkipCommentsAndWhitespace();

			_writer.WriteValueArray();
			defer _writer.Pop();

			while (!IsEnd)
			{
				SkipCommentsAndWhitespace();
				if (Match(']'))
					return .Ok;

				if (ParseValue() case .Err)
				{
					return .Err;
				}
				SkipCommentsAndWhitespace();
				if (Match(','))
					continue;
				else if (Match(']'))
				{
					return .Ok;
				}	
				else
				{
					ReportError("Expected ',' or ']");
					TryRecoverFromError();
					return .Err;
				}	
			}

			return .Err;
		}

		Result<void> ParseNumber()
		{
			const int MAX_HEX_LENGTH = 16;
			const int MAX_OCT_LENGTH = 22;
			const int MAX_BIN_LENGTH = 64;

			bool wasZero;
			{
				let c = ReadChar();
				if (!c.IsDigit && c != '+' && c != '-' && c != 'i' && c != 'n')
				{
					return .Err;
				}	

				 wasZero = c == '0';
				if (wasZero)
				{
					Advance();
					var c;
					if (Match('x'))
					{
						uint64 value = 0;
						uint8 length = 0;
						while (!IsEnd)
						{
							c = ReadChar();
							if (c >= '0' && c <= '9')
							{
								value *= 16;
								value += (uint16)(c - '0');
							}
							else if (c >= 'a' && c <= 'f')
							{
								value *= 16;
								value += 10 + (uint16)(c - 'a');
							}
							else if (c >= 'A' && c <= 'F')
							{
								value *= 16;
								value += 10 + (uint16)(c - 'A');
							}
							else if(c != '_')
							{
								break;
							}

							Advance();
							length++;
						}
						if (length > MAX_HEX_LENGTH)
							ReportError("Hex literal too long");
						_writer.WriteValue(value);
						return .Ok;
					}
					else if (Match('o'))
					{
						uint64 value = 0;
						uint8 length = 0;
						while (!IsEnd)
						{
							c = ReadChar();
							if (c >= '0' && c <= '8')
							{
								value *= 8;
								value += (uint16)(c - '0');
							}
							else if(c != '_')
							{
								break;
							}

							Advance();
							length++;
						}
						if (length > MAX_OCT_LENGTH)
							ReportError("Octal literal too long");
						_writer.WriteValue(value);
						return .Ok;
					}
					else if (Match('b'))
					{
						uint64 value = 0;
						uint8 length = 0;
						while (!IsEnd)
						{
							c = ReadChar();
							if (c >= '0' && c <= '1')
							{
								value *= 2;
								value += (uint16)(c - '0');
							}
							else if(c != '_')
							{
								break;
							}
							
							Advance();
							length++;
						}
						if (length > MAX_BIN_LENGTH)
							ReportError("Binary literal too long");
						_writer.WriteValue(value);
						return .Ok;
					}
				}
			}
			

			bool isNegative = Match('-');
			if (Match('+'))
			{
				if (isNegative)
				{
					ReportError("Unexpected '+' after '-'");
					return .Err;
				}
			}	

			if (Match('i'))
			{
				if (Match('n') && Match('f'))
				{
					_writer.WriteValue(isNegative ? double.NegativeInfinity : double.PositiveInfinity);
					return .Ok;
				}
				else
				{
					ReportError("Unexpected character, expected 'inf'");
					return .Err;
				}
			}
			else if(Match('n'))
			{
				if (Match('a') && Match('n'))
				{
					_writer.WriteValue(double.NaN);
					return .Ok;
				}
				else
				{
					ReportError("Unexpected character, expected 'nan'");
					return .Err;
				}
			}
			else
			{
				var c = ReadChar();
				if (c.IsDigit || wasZero)
				{
					uint64 value = 0;
					uint64 decimal = 0;
					uint64 exponent = 0;
					uint8 valueLength = 0;
					uint8 decimalLength = 0;
					uint8 exponentLength = 0;

					bool exponentNegative = false;
					bool hadDecimal = false;
					bool hadExponent = false;
					uint64* ptr = &value;
					uint8* lenPtr = &valueLength;

					while (!IsEnd)
					{
						c = ReadChar();
						if (c >= '0' && c <= '9')
						{
							*ptr *= 10;
							*ptr += (uint16)(c - '0');
							(*lenPtr)++;
						}
						else if (c == '.')
						{
							if (hadDecimal)
								ReportError("Multiple '.' inside float literal");

							ptr = &decimal;
							lenPtr = &decimalLength;
							hadDecimal = true;
						}
						else if (c == 'e' || c == 'E')
						{
							if (hadExponent)
								ReportError("Multiple exponents inside literal");

							Advance();
							hadExponent = true;
							exponentNegative = Match('-');
							if (Match('+') && exponentNegative)
							{
								ReportError("Unexpected '+' after '-'");
							}
							ptr = &exponent;
							lenPtr = &exponentLength;
							continue;
						}
						else if(c != '_')
						{
							break;
						}

						Advance();
					}

					if (!hadDecimal && !hadExponent)
					{
						if (isNegative)
						{
							const uint64 MIN_VAL = (uint64)-int64.MinValue;
							if (value > MIN_VAL)
								ReportError("Value of integer literal does not fit in 64bits");

							_writer.WriteValue(-(int64)value);
						}
						else
						{
							if (value > int64.MaxValue)
								_writer.WriteValue((uint64)value);
							else
								_writer.WriteValue((int64)value);
						}

						return .Ok;
					}

					let exp = Math.Pow(10.0d, exponentNegative ? (-(double)exponent) : exponent);

					double val = value  * exp;
					double dec = decimal;
					while (decimalLength > 0)
					{
						dec *= 0.1d;
						decimalLength--;
					}
					val += dec * exp;
					if (isNegative)
						val = -val;

					_writer.WriteValue(val);
					return .Ok;
				}
			}

			return .Err;
		}


		Result<void> ParseValue()
		{
			let c = ReadChar();

			String buffer = scope .();

			switch (c)
			{
			case '{': return ParseObject();
			case '[': return ParseArray();
			case '"':
				if (ParseString_Quotation(buffer, true, let multiline))
				{
					_writer.WriteValue(buffer).SetStringType(multiline, false);
					return .Ok;
				}	
				else
					return .Err;	
			case '\'':
				if (ParseString_SingleQuote(buffer, true, let multiline))
				{
					_writer.WriteValue(buffer).SetStringType(multiline, true);
					return .Ok;
				}	
				else
					return .Err;
			}


			if (ParseNumber() case .Ok)
			{
				return .Ok;
			}

			if (ParseIdentifier(buffer))
			{
				if (buffer == "true")
				{
					_writer.WriteValue(true);
					return .Ok;
				}	
				else if (buffer == "false")
				{
					_writer.WriteValue(false);
					return .Ok;
				}
				else
				{
					ReportError(scope $"Unexpected '{buffer}'");
				}	
			}

			return .Err;
		}

		bool TryRecoverFromError()
		{
			if (_prevRecoverPosition == CurrentPos)
				return false;

			defer { _prevRecoverPosition = CurrentPos; }
			// @TODO
			while (!IsEnd)
			{
				switch (ReadChar())
				{
				case ']', '}', ',':
					{
						Advance();
						return true;
					}
				case '[', '{', '\n': return true; 
				}
				Advance();
			}

			return false;
		}

		public Result<void, TomlReadError> Parse()
		{
			// @TODO - add support for 'key.subkey = 10' expressions
			String key = scope .();

			bool hadNewLine = true;
			while (!IsEnd)
			{
				SkipCommentsAndWhitespace();
				if (IsEnd)
					break;
				key.Clear();
				let kind = ParseToplevelKey(key);

				PARSE_VALUE: do
				{
					switch (kind)
					{
					case .Error:
						{
							ReportError("Failed to parse key");
							if (TryRecoverFromError())
								continue;
							else
								return .Err(.ParseError);
						} 
					case .Inline:
						{
							SkipWhitespaceNoNewLine();
							if (!Match('='))
							{
								ReportError("Expected '=' after key");
								if (TryRecoverFromError())
									continue;
								else
									return .Err(.ParseError);
							}	
						}
					case .TopLevel: break PARSE_VALUE;

					}

					_writer.key = key;
					SkipCommentsAndWhitespace();
					if (IsEnd)
						break;
					if (ParseValue() case .Err)
					{
						if (TryRecoverFromError())
							continue;
						else
							return .Err(.ParseError);
					}
				}
				
				SkipWhitespaceNoNewLine();
				if (Match('\n'))
				{
					_currentLineStart = CurrentPos;
					_currentLine++;
					hadNewLine = true;
				}
				else
					hadNewLine = false;
			}

			return .Ok;

		}

	}
}