using System;
using System.Collections;

static
{
	public static mixin DeleteKeysAndValues<K, V>(Dictionary<K, V> dict)
		where K : IHashable, delete
		where V : delete
	{
		for (let (k, v) in dict)
		{
			delete k;
			delete v;
		}
	}
}
