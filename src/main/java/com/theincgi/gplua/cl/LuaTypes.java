package com.theincgi.gplua.cl;

public class LuaTypes {
	public static final byte
		INT = -2,
		NONE = -1,
		NIL = 0,
		BOOL = 1,
		NUMBER = 3, //double
		STRING = 4,
		TABLE = 5,
		FUNC = 6,
		USERDATA = 7,
//		THREAD = 8, //not supported
		ARRAY = 0x50,
		HASHMAP = 0x51,
		CLOSURE = 0x52,
		SUBSTRING = 0x54,
		NATIVE_FUNC = 0x56;
		
}
