#if BF_PLATFORM_LINUX

using System;
using System.Interop;

using MQTTCommon;

namespace MQTTCompanion;

public class LinuxPathHelper
{
	typealias uid_t = uint32;
	typealias gid_t = uint32;

	[CRepr]
	struct passwd
	{
		public c_char   *pw_name;       /* username */
		public c_char   *pw_passwd;     /* user password */
		public uid_t   pw_uid;        /* user ID */
		public gid_t   pw_gid;        /* group ID */
		public c_char   *pw_gecos;      /* user information */
		public c_char   *pw_dir;        /* home directory */
		public c_char   *pw_shell;      /* shell program */
	}

	[CLink]
	static extern uid_t getuid();

	[CLink]
	static extern passwd* getpwuid(uid_t uid);

	static String sUserHomeDir ~ delete _;

	static void Init()
	{
		if (sUserHomeDir != null)
			return;

		sUserHomeDir = new .();

		let user = getuid();
		if (let pwd = getpwuid(user))
		{
			sUserHomeDir.Append(pwd.pw_dir);
			Log.Trace(sUserHomeDir);
		}
	}


	public static void MakeAbsolute(String path)
	{
		if (path.StartsWith('~'))
		{
			Init();
			path.Replace(0, 1, sUserHomeDir);
		}
	}
}

#endif // BF_PLATFORM_LINUX