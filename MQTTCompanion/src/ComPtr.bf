using System;
using System.Interop;

using MQTTCommon.Win32;

using System.Collections;
using System.Reflection;

namespace MQTTCompanion;

static
{
	public static Result<GUID> ParseUUID(StringView value)
	{
		if (value.Length != 36)
			return .Err;

		GUID guid;
		guid.data = Try!(uint32.Parse(value[0...7], .Hex));
		guid.data2 = Try!(uint16.Parse(value[9...12], .Hex));
		guid.data3 = Try!(uint16.Parse(value[14...17], .Hex));
		guid.data4[0] = Try!(uint8.Parse(value[19...20], .Hex));
		guid.data4[1] = Try!(uint8.Parse(value[21...22], .Hex));
		guid.data4[2] = Try!(uint8.Parse(value[24...25], .Hex));
		guid.data4[3] = Try!(uint8.Parse(value[26...27], .Hex));
		guid.data4[4] = Try!(uint8.Parse(value[28...29], .Hex));
		guid.data4[5] = Try!(uint8.Parse(value[30...31], .Hex));
		guid.data4[6] = Try!(uint8.Parse(value[32...33], .Hex));
		guid.data4[7] = Try!(uint8.Parse(value[34...35], .Hex));
		return guid;
	}
}


struct MIDL_INTERFACEAttribute : Attribute
{
	public readonly String UUID;
	public this(String guid)
	{
		UUID = guid;
	}
}

[MIDL_INTERFACE("00000000-0000-0000-C000-000000000046")]
interface IUnknown
{
	public HResult QueryInterface(GUID* riid, void** ppvObject);
	public c_ulong AddRef() mut;
	public c_ulong Release() mut;
}

[MIDL_INTERFACE("AF86E2E0-B12D-4c6a-9C5A-D7AA65101E90")]
interface IInspectable : IUnknown
{
	HResult GetIids(c_ulong* iidCount, GUID** iids);
	HResult GetRuntimeClassName(HSTRING* className);
	HResult GetTrustLevel(TrustLevel* trustLevel);
}

interface IReference<T> : IInspectable
	where T : struct
{
	HResult get_Value(T* value);
}	

public struct ComVtbl<T>
	where T : interface, IUnknown
{
	typealias ThisT = void;//ComPtr<T>;

	[Comptime]
	static void GenerateType(Type type, String code, HashSet<TypeInstance> ifaces)
	{
		for (let i in type.Interfaces)
		{
			if (ifaces.Add(i))
				GenerateType(i, code, ifaces);
		}

		code.AppendF($"//{type.GetName(.. scope .())}\n");
		for (let m in  type.GetMethods())
		{
			if (m.GenericArgCount != 0)
				continue;

			String tmp = scope $"public function [CallingConvention(.Stdcall)] {m.ReturnType} (ThisT* This, ";
			let len = tmp.Length;
			m.GetParamsDecl(tmp);
			if (len == tmp.Length)
				tmp.Length -= 2;

			tmp.AppendF($") {m.Name};\n");

			code.Append(tmp);
		}
	}

	[Comptime, OnCompile(.TypeInit)]
	static void Generate()
	{
		String code = scope .();

		let type = typeof(T);
		GenerateType(type, code, scope .());
		
		Compiler.EmitTypeBody(typeof(Self), code);
	}
}

[CRepr]
struct ComPtr<T>
	where T : interface, IUnknown
{
	protected ComVtbl<T>* _vtbl;

	public Result<ComPtr<IfaceT>*, HResult> QueryInterface<IfaceT>() mut
		where IfaceT : interface, IUnknown
	{
		ComPtr<IfaceT>* pp = default;
		let result = ((ComVtbl<IUnknown>*)_vtbl).QueryInterface(&this, &ComPtr<IfaceT>.IID, (.)&pp);
		if (result.Failed)
			return .Err(result);

		return .Ok(pp);
	}

	[Comptime]
	static void GenerateType(Type type, String code, HashSet<TypeInstance> ifaces)
	{
		for (let i in type.Interfaces)
		{
			if (ifaces.Add(i))
			{
				GenerateType(i, code, ifaces);
			}
		}

		for (let m in  type.GetMethods())
		{
			if (m.GenericArgCount != 0)
				continue;

			String tmp = scope $"public {m.ReturnType} {m.Name} (";
			m.GetParamsDecl(tmp);
			tmp.AppendF($") mut => _vtbl.{m.Name}(&this, ");
			if (m.ParamCount == 0)
				tmp.Length -= 2;
			m.GetArgsList(tmp);
			tmp.Append(");\n");

			code.Append(tmp);
		}
	}

	[Comptime, OnCompile(.TypeInit)]
	static void Generate()
	{
		String code = scope .();
		GenerateType(typeof(T), code, scope .());
		Compiler.EmitTypeBody(typeof(Self), code);
	}

	[Comptime(ConstEval=true)]
	static GUID GetUUID()
	{
		if (typeof(T).GetCustomAttribute<MIDL_INTERFACEAttribute>() case .Ok(let val))
		{
			return ParseUUID(val.UUID);
		}
		return default;
	}

	public static GUID IID = GetUUID();
}

[AttributeUsage(.Struct)]
struct GenerateVTableAttribute : Attribute, IOnTypeInit
{
	public bool GenerateConstructor = true;
	public bool AllowInheritance = true;

	[Comptime]
	public void OnTypeInit(Type type, Self* prev)
	{
		if (GenerateConstructor)
			Compiler.EmitTypeBody(type, "public this() : base(VTable<Self>.Instance) {}");
		if (AllowInheritance)
			Compiler.EmitTypeBody(type, "public this(void* vTable) : base(vTable) {}");
	}
}

[CRepr]
struct ComPtr
{
	[CRepr]
	public struct VTable<T>
	{
		static Self s_Instance = .();
		#unwarn
		public static Self* Instance => &s_Instance;

		[Comptime, OnCompile(.TypeInit)]
		static void Generate()
		{
			if (typeof(Self) == typeof(VTable<>))
				return;

			#unwarn
			String code = scope .();
			String initCode = scope .();
			String typeName = typeof(T).GetFullName(.. scope .());
			int count = 0;

			bool mayOverride = typeof(T).BaseType != typeof(ComPtr);
			HashSet<String> generatedMethods = scope .();

			if (mayOverride)
			{
				code.AppendF($"public using VTable<{typeof(T).BaseType}> __base__;\n");
				initCode.Append("\t__base__ = .();\n");
				count++;

				for (let method in typeof(T).BaseType.GetMethods(.Instance | .Public | .DeclaredOnly))
				{
					if (method.IsConstructor || method.IsDestructor)
						continue;

					if (method.IsStatic)
						continue;

					String methodName = new .();
					methodName.Append(method.Name);
					method.GetMethodSig(methodName);

					if (!generatedMethods.Add(methodName))
						continue;
				}
			}

			for (let method in typeof(T).GetMethods(.Instance | .Public | .DeclaredOnly))
			{
				if (method.IsConstructor || method.IsDestructor)
					continue;

				if (method.IsStatic)
					continue;

				String methodName = new .();
				methodName.Append(method.Name);
				method.GetMethodSig(methodName);

				if (!generatedMethods.Add(methodName))
				{
					if (mayOverride)
					{
						initCode.AppendF($"\t{method.Name} = => {typeName}.{method.Name};\n");
					}
					continue;
				}

				//Runtime.Assert(method.IsMutating, "Struct methods called through VTable need to be marked with `mut`");

				let @mut = method.IsMutating ? "mut " : "";

				let paramsDecl = scope String();
				paramsDecl.Append(", ");
				method.GetParamsDecl(paramsDecl);
				if (paramsDecl.Length == 2)
					paramsDecl.Clear();

				code.AppendF($"public function {method.ReturnType} ({@mut}{typeName} this{paramsDecl}) {method.Name};\n");

				initCode.AppendF($"\t{method.Name} = => {typeName}.{method.Name};\n");

				count++;
			}

			Compiler.EmitTypeBody(typeof(Self), code);

			if (count > 0)
				Compiler.EmitTypeBody(typeof(Self), scope $"public this()\n{{\n{initCode}}}");
		}	
	}


	void* _vTable;

	protected this(void* vtable)
	{
		_vTable = vtable;
	}
}

[GenerateVTable]
public struct GenericComPtr : ComPtr, IUnknown
{
	public uint64 refCount = 0;

	public HResult QueryInterface(GUID* riid, void** ppvObject)
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