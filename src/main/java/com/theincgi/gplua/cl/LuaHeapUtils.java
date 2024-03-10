package com.theincgi.gplua.cl;

import static com.theincgi.gplua.cl.LuaTypes.*;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.concurrent.atomic.AtomicInteger;

import com.theincgi.gplua.Main;

public class LuaHeapUtils {
	
	public static void createGlobals() {
		LuaTable g = new LuaTable();
		LuaTable math = new LuaTable();
		LuaTable string = new LuaTable();
		LuaTable os = new LuaTable();
		LuaTable table = new LuaTable();
		LuaTable bit32 = new LuaTable();
		
		//about 1286 bytes will be used in just function definitions
		//+ 13 per table entry + (0 or 5 + array part size * 4) + (0 or 9 + hash part size * 8)
		//table object + hash entries will be about 1320
		//in total at least 2606 bytes used
		
		int nID = 1;
		g.hashed.put("_VERSION", Main.VERSION);
		
		g.hashed.put("assert", 			new NativeFunction(nID++));
		g.hashed.put("collectgarbage", 	new NativeFunction(nID++));
		g.hashed.put("error", 			new NativeFunction(nID++));
		g.hashed.put("getmetatable", 	new NativeFunction(nID++));
		g.hashed.put("ipairs", 			new NativeFunction(nID++));
		g.hashed.put("next", 			new NativeFunction(nID++));
		g.hashed.put("pairs", 			new NativeFunction(nID++));
		g.hashed.put("pcall", 			new NativeFunction(nID++));
		g.hashed.put("rawequal", 		new NativeFunction(nID++));
		g.hashed.put("rawget", 			new NativeFunction(nID++));
		g.hashed.put("rawlen", 			new NativeFunction(nID++));
		g.hashed.put("rawset", 			new NativeFunction(nID++));
		g.hashed.put("select", 			new NativeFunction(nID++));
		g.hashed.put("setmetatable", 	new NativeFunction(nID++));
		g.hashed.put("tonumber", 		new NativeFunction(nID++));
		g.hashed.put("tostring", 		new NativeFunction(nID++));
		g.hashed.put("type", 			new NativeFunction(nID++));
		g.hashed.put("xpcall", 			new NativeFunction(nID++));
		
		g.hashed.put("math", math);
		g.hashed.put("string", string);
		g.hashed.put("os", os);
		g.hashed.put("table", table);
		g.hashed.put("bit32", bit32);
		
		
		
		//math
		for(var func : new String[] {
			"log",
			"exp",
			"acos",
			"atan",
			"ldexp",
			"deg",
			"rad",
			"tan",
			"cos",
			"cosh",
			"random",
			"frexp",
			"randomseed",
			"ceil",
			"tanh",
			"floor",
			"abs",
			"max",
			"sqrt",
			"modf",
			"sinh",
			"asin",
			"min",
			"fmod",
			"pow",
			"atan2",
			"sin"
		}) {
			math.hashed.put(func, new NativeFunction(nID++));
		}
		
		//string
		for(var func : new String[] {
			"sub",
			"find",
			"rep",
			"match",
			"gmatch",
			"char",
			"reverse",
			"upper",
			"len",
			"gsub",
			"byte",
			"format",
			"lower"
		}) {
			math.hashed.put(func, new NativeFunction(nID++));
		}
	}
	
	public static void putBoolConstants(byte[] heap) {
		heap[1] = BOOL;
		heap[2] = 0x00; //false
		heap[3] = BOOL;
		heap[4] = 0x01; //true
	}
	
//	public static void putGlobals(LuaTable globals, byte[] heap, HashMap<String, Integer> stringMap) {
//		globals.serializeTo(stringMap, heap, 3);
//	}
	
	public static byte[] serialize(String string) {
		var bytes = string.getBytes();
		byte[] out = new byte[bytes.length + 5];
		out[0] = STRING;
		putInt(bytes.length, out, 1);
		System.arraycopy(bytes, 0, out, 5, bytes.length);
		return out;
	}
	public static byte[] serialize(int i) {
		var bytes = new byte[5];
		bytes[0] = (byte) INT;
		putInt(i, bytes, 1);
		return bytes;
	}
	public static byte[] serialize(float f) {
		return serialize((double) f);
	}
	public static byte[] serialize(double d) {
		long bits = Double.doubleToLongBits(d);
		var out = new byte[9];
		out[0] = NUMBER;
		putInt((int) (bits >> 32), out, 1);
		putInt((int) (bits & 0xFFFFFF), out, 5);
		return out;
	}
	public static byte[] serialize(long l) {
		return serialize((double) l);
	}
	
	public static class NativeFunction {
		int id;
		public NativeFunction(int id) {
			this.id = id;
		}
		
		public byte[] serialize() {
			var bytes = new byte[5];
			bytes[0] = NATIVE_FUNC;
			putInt(id, bytes, 1);
			return bytes;
		}
	}
	
	
//	public static byte[] serialize(boolean b) {
////		throw new 
//	}
	
	/** Compute the hash code of a sequence of bytes within a byte array using
	 * lua's rules for string hashes.  For long strings, not all bytes are hashed.
	 * @param bytes  byte array containing the bytes.
	 * @param offset  offset into the hash for the first byte.
	 * @param length number of bytes starting with offset that are part of the string.
	 * @return hash for the string defined by bytes, offset, and length.
	 * <br>
	 * Sourced from LuaJ
	 */
	public static int hashCode(byte[] bytes, int offset, int length) {
		int h = length;  /* seed */
		int step = (length>>5)+1;  /* if string is too long, don't hash all its chars */
		for (int l1=length; l1>=step; l1-=step)  /* compute hash */
		    h = h ^ ((h<<5)+(h>>2)+(((int) bytes[offset+l1-1] ) & 0x0FF ));
		return h;
	}
	
	public static int hashCode(String string) {
		var bytes = string.getBytes();
		return hashCode( bytes, 0, bytes.length );
	}
	
	//big endian
	private static void putInt(int value, byte[] heap, int pos) {
		heap[pos  ] = (byte) ((value >> 24) & 0xFF); 
		heap[pos+1] = (byte) ((value >> 16) & 0xFF); 
		heap[pos+2] = (byte) ((value >>  8) & 0xFF); 
		heap[pos+3] = (byte) ((value      ) & 0xFF); 
	}
	
	private static int getInt(int index, byte[] heap) {
		return heap[index] << 24 | heap[index+1] << 16 | heap[index+2] << 8 | heap[index+3];
	}
	
	public static class LuaTable {
		public ArrayList<byte[]> array = new ArrayList<>();
		public HashMap<String, Object> hashed = new HashMap<>();
		public int metatable = 0;
		
		/**loads values on to heap and returns array data*/
		byte[] serializeArrayPart(byte[] heap, AtomicInteger i) {
			byte[] out = new byte[ 5 + array.size() * 4 ];
			out[0] = ARRAY; //array type
			putInt(array.size(), out, 1);
			
			int j = 5;
			for(var val : array) {
				System.arraycopy(val, 0, heap, i.get(), val.length);
				putInt(i.get(), out, j * 4);
				j++;
				i.addAndGet( val.length );
			}
			
			return out;
		}
		byte[] serializeHashedPart(HashMap<String, Integer> stringMap, byte[] heap, AtomicInteger i) {
			int capcacity = hashed.size() * 4/3;
			byte[] out = new byte[ 5 + capcacity * 8 ];
			out[0] = HASHMAP; //hashmap
			putInt(capcacity, out, 1);
			
			final int k = 5;
			final int v = k + capcacity * 4;
			
			for(var entry : hashed.entrySet()) {
				var key = entry.getKey();
				var val = entry.getValue();
				
				//key
				int hash = LuaHeapUtils.hashCode(key);
				int stringIndex = 0;
				if(stringMap.containsKey(key)) {
					stringIndex = stringMap.get(key);
				} else {
					byte[] string = serialize(key);
					System.arraycopy(string, 0, heap, i.get(), string.length);
					stringIndex = i.getAndAdd(string.length);
				}
				int offset = hash % capcacity;
				//simple collision handling
				while( getInt(offset * 4, out) != 0 )
					offset++;
				
				putInt(stringIndex, out, offset*4 + k);
				
				//value
				int valIndex = 0;
				if(val instanceof String str) {
					if( stringMap.containsKey(str) ) {
						valIndex = stringMap.get(str);
					} else {
						byte[] string = serialize(str);
						System.arraycopy(string, 0, heap, i.get(), string.length);
						valIndex = i.getAndAdd(string.length);
					}
				} else {
					byte[] valData;
					if(val instanceof Integer iVal) {
						valData = serialize(iVal);
					} else if(val instanceof Long lVal) {
						valData = serialize(lVal);
					} else if(val instanceof Double dVal) {
						valData = serialize(dVal);
					} else if(val instanceof Float fVal) {
						valData = serialize(fVal);
					} else if(val instanceof Boolean bVal) {
						valData = null;
						valIndex = bVal ? 2 : 1; //see putBoolConstants
					} else if(val instanceof NativeFunction nf) {
						valData = nf.serialize();
					} else {
						throw new RuntimeException("Type "+val.getClass().getName()+" isn't supported");
					}
					
					if(valData != null) {
						System.arraycopy(valData, 0, heap, i.get(), valData.length);
						valIndex = i.getAndAdd(valData.length);
					}
					
					putInt(valIndex, out, offset*4 + v);
				}
				
			}
			return out;
		}
		
		public int serializeTo(HashMap<String, Integer> stringMap,byte[] heap, int index) {
			AtomicInteger i = new AtomicInteger(index);
			heap[i.getAndIncrement()] = 0x05; //Lua Table type
			int arrayPartIndex = i.get();
			int hashedPartIndex = i.get() + 4;
			int metatbleIndex = i.get() + 8;
			i.addAndGet(12);
			
			if(array.size() > 0) {
				byte[] arrayData = serializeArrayPart(heap, i);
				System.arraycopy(arrayData, 0, heap, i.get(), arrayData.length);
				putInt(i.get(), heap, arrayPartIndex);
				i.addAndGet( arrayData.length );
			} //else index = 0
			
			if(!hashed.isEmpty() ) {
				byte[] hashData = serializeHashedPart(stringMap, heap, i);
				System.arraycopy(hashData, 0, heap, i.get(), hashData.length);
				putInt(i.get(), heap, hashedPartIndex);
				i.addAndGet( hashData.length );
			} //else index = 0
			
			putInt(metatable, heap, metatbleIndex);
			
			return i.get();
		}
	}
	
}
