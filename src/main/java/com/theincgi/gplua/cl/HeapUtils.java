package com.theincgi.gplua.cl;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

public class HeapUtils {

	public static final int USE_FLAG  = 0x80000000,
			MARK_FLAG = 0x40000000,
			SIZE_MASK = 0x3FFFFFFF;
	public final int REGISTER_SIZE = 4;
	
	public static boolean isUseFlag( int tag ) {
		return (tag & USE_FLAG) != 0;
	}
	
	public static boolean isMarkFlag( int tag ) {
		return (tag & MARK_FLAG) != 0;
	}
	
	public static int chunkSize( int tag ) {
		return (tag & SIZE_MASK);
	}
	
	public static int readIntAt(byte[] data, int offset) throws IOException {
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(data));
		dis.skip(offset);
		return dis.readInt();
	}
	
	public static TaggedMemory getChunkData( byte[] heap, int allocationIndex ) throws IOException {
		if(allocationIndex == 0)
			return new TaggedMemory(0, true, false, new byte[1], heap);
		if(allocationIndex == 1)
			return new TaggedMemory(1, true, false, new byte[] {LuaTypes.BOOL, 0}, heap);
		if(allocationIndex == 3)
			return new TaggedMemory(1, true, false, new byte[] {LuaTypes.BOOL, 1}, heap);
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(heap));
		int tagPos = allocationIndex - 4;
		dis.skip(tagPos);
		int tag = dis.readInt();
		int size = chunkSize( tag );
		var data = dis.readNBytes(size - 4);
		return new TaggedMemory(allocationIndex, isUseFlag(tag), isMarkFlag(tag), data, heap);
	}
	
	public static List<TaggedMemory> getAllChunks( byte[] heap ) throws IOException {
		int i = 5;
		var all = new ArrayList<TaggedMemory>();
		while( i < heap.length-4 ) {
			int chunkSize = readIntAt(heap, i) & SIZE_MASK;
			if(chunkSize == 0) break;
			all.add(getChunkData(heap, i + 4));
			i += chunkSize;
		}
		return all;
	}
	
	public static void dumpHeap( byte[] heap ) throws IOException {
		System.out.println(" == HEAP == ");
		
		for(var chunk  : getAllChunks(heap)) {
			System.out.println(chunk);
			System.out.println();
		}
	}
	
	public static record TaggedMemory(int allocationIndex, boolean inUse, boolean marked, byte[] data, byte[] heap) {
		public static final int STACKFRAME_RESERVE = 1 + (7*4);
		public static final int REGISTER_SIZE = 4;
 
		public int readInt(int offset) throws IOException {
			return readIntAt(data, offset);
		}
		public int type() {
			return ((int)data[0]) & 0xFF;
		}
		private void assertType(int type) {
			if(type() != type)
				throw new RuntimeException("Expected type with ID "+type+", got "+type());
		}
		
		public int arrayRef(int index) throws IOException {
			assertType(LuaTypes.ARRAY);
			return readInt( 9 + index * 4 );
		}
		
		public int arraySize() throws IOException {
			assertType(LuaTypes.ARRAY);
			return readInt( 1 );
		}
		
		public int arrayCapacity() throws IOException {
			assertType(LuaTypes.ARRAY);
			return readInt( 5 );
		}
		
		public int tableArrayPart() throws IOException {
			assertType(LuaTypes.TABLE);
			return readInt( 1 );
		}
		
		public int tableHashedPart() throws IOException {
			assertType(LuaTypes.TABLE);
			return readInt( 5 );
		}
		
		public int tableMetatable() throws IOException {
			assertType(LuaTypes.TABLE);
			return readInt( 9 );
		}
		
		public int hashmapKeys() throws IOException {
			assertType(LuaTypes.HASHMAP);
			return readInt( 1 );
		}
		
		public int hashmapVals() throws IOException {
			assertType(LuaTypes.HASHMAP);
			return readInt( 5 );
		}
		
		public int intValue() throws IOException {
			assertType(LuaTypes.INT);
			return readInt( 1 );
		}
		
		public double doubleValue() throws IOException {
			assertType(LuaTypes.NUMBER);
			long hi = (((long)readIntAt(data, 1)) << 32);
			long lo = ((long)readIntAt(data, 5)) & 0xFFFFFFFFL;
			long bits = hi | lo;
			return Double.longBitsToDouble( bits );
		}
		
		public boolean boolValue() {
			assertType(LuaTypes.BOOL);
			return data()[1] != 0 ? true : false;
		}
		
		public int stringLength() throws IOException {
			assertType(LuaTypes.STRING);
			return readInt( 1 );
		}
		
		public int closureFunction() throws IOException {
			assertType(LuaTypes.CLOSURE);
			return readInt(1);
		}
		
		public int closureUpvalArray() throws IOException {
			assertType(LuaTypes.CLOSURE);
			return readInt(5);
		}
		
		public int closureFenv() throws IOException {
			assertType(LuaTypes.CLOSURE);
			return readInt(9);
		}
		
		public int lsGetPriorStack() throws IOException {
			assertType(LuaTypes.LUA_STACK);
			return readInt( 1 );
		}
		
		public int lsGetPriorPC() throws IOException {
			assertType(LuaTypes.LUA_STACK);
			return readInt( 5 );
		}
		
		public int lsGetTop() throws IOException {
			assertType(LuaTypes.LUA_STACK);
			return readInt( 9 );
		}
		
		public int lsGetFirstRegPos() throws IOException {
			assertType(LuaTypes.LUA_STACK);
			return readInt( 13 );
		}
		
		public int lsGetClosure() throws IOException {
			assertType(LuaTypes.LUA_STACK);
			return readInt( 17 );
		}
		
		public int lsGetMaxStackSize() throws IOException {
			assertType(LuaTypes.LUA_STACK);
			return readInt( 21 );
		}
		
		public int lsGetDepth() throws IOException {
			assertType(LuaTypes.LUA_STACK);
			return readInt( 25 );
		}
		
		public boolean lsHasVarargs() throws IOException {
			assertType(LuaTypes.LUA_STACK);
			return 0 < (lsGetFirstRegPos() - STACKFRAME_RESERVE) / REGISTER_SIZE;
		}
		
		public int lsNVarargs() throws IOException {
			assertType(LuaTypes.LUA_STACK);
			if(!lsHasVarargs()) return 0;
			int ref = readInt( STACKFRAME_RESERVE );
			if(ref == 0) return 0;
			var vargs = getChunkData(heap, ref);
			return vargs.arraySize();
		}
		
		public int lsNRegisters() throws IOException {
			assertType(LuaTypes.LUA_STACK);
			return (lsGetTop() - lsGetFirstRegPos()) / REGISTER_SIZE;
		}
		
		public int lsGetVararg( int i ) throws IOException {
			assertType(LuaTypes.LUA_STACK);
			if(!lsHasVarargs()) return 0;
			int ref = readInt( STACKFRAME_RESERVE );
			if(ref == 0) return 0;
			var vargs = getChunkData(heap, ref);
			return vargs.arrayRef(i);
		}
		
		public int lsGetRegister( int i ) throws IOException {
			assertType(LuaTypes.LUA_STACK);
			int first = lsGetFirstRegPos();
			int pos = first + i * REGISTER_SIZE;
			if( pos >= lsGetTop() )
				throw new ArrayIndexOutOfBoundsException( i );
			return readInt( pos );
		}
		
		public int upvalStack() throws IOException {
			assertType(LuaTypes.UPVAL);
			return readInt(1);
		}
		
		public int upvalRegister() {
			assertType(LuaTypes.UPVAL);
			return ((int)data[5]) & 0xFF;
		}
		
		public String stringValue() throws IOException {
			assertType(LuaTypes.STRING);
			return new String(data, 5, stringLength());
		}
		
		public String toString() {
			if(allocationIndex >= 5 && !inUse())
				return "[%d : %d] FREE".formatted(allocationIndex, allocationIndex + data.length-1);
			StringBuilder builder = new StringBuilder();
			builder.append("[%d : %d] ".formatted(allocationIndex, allocationIndex + data.length-1));
			try {
				switch (type()){
				case LuaTypes.INT: {
					builder.append("INT: ");
					builder.append(intValue());
					break;
				}
				case LuaTypes.NONE: {
					builder.append("NONE");
					break;
				}
				case LuaTypes.NIL: {
					builder.append("NIL");
					break;
				}
				case LuaTypes.BOOL: {
					builder.append("BOOL: ");
					builder.append( Boolean.toString(boolValue()).toUpperCase() );
					break;
				}
				case LuaTypes.NUMBER: {
					builder.append("NUMBER: %f".formatted(doubleValue()) );
					break;
				}
				case LuaTypes.STRING: {
					builder.append("STRING: \"");
					builder.append(stringValue());
					builder.append("\"");
					break;
				}
				case LuaTypes.TABLE: {
					builder.append("TABLE: \n")
						.append("  Array Part:  ").append(tableArrayPart())
						.append("\n  Hashed Part: ").append(tableHashedPart())
						.append("\n  Metatable:   ").append(tableMetatable());
					break;
				}
				case LuaTypes.FUNC: {
					builder.append("LUA FUNCTION: TODO");
					break;
				}
				case LuaTypes.USERDATA: {
					builder.append("USERDATA");
					break;
				}
				case LuaTypes.ARRAY: {
					builder.append("ARRAY:\n")
						.append(  "  Size:     ").append(arraySize())
						.append("\n  Capacity: ").append(arrayCapacity())
						.append("\n  Refs:");
					for(int i = 0; i < arrayCapacity(); i++) {
						builder.append("\n    [%2d] ".formatted(i));
						builder.append(arrayRef(i));
					}
					break;
				}
				case LuaTypes.HASHMAP: {
					builder.append("HASHMAP:\n")
					  .append("  Keys: ").append(hashmapKeys())
					  .append("\n  Vals: ").append(hashmapVals());
					break;
				}
				case LuaTypes.CLOSURE: {
					builder.append("CLOSURE: \n")
						.append("  Function: ").append(closureFunction()).append("\n")
						.append("  Upvals:   ").append(closureUpvalArray()).append("\n")
						.append("  _ENV:     ").append(closureFenv());
					break;
				}
				case LuaTypes.SUBSTRING: {
					builder.append("SUBSTRING:\n")
						.append(  "  Ref:     ").append(readInt(1))
						.append("\n  Start:   ").append(readInt(5))
						.append("\n  Length:  ").append(readInt(9));
//					.append("  Preview: \"").append().append("\"");
					break;
				}
				case LuaTypes.NATIVE_FUNC: {
					builder.append("NATIVE FUNC:\n")
						.append("  ID: ").append(readInt(1));
					break;
				}
				
				case LuaTypes.LUA_STACK: {
					builder.append("LUA STACK:\n")
						.append(  "  PriorStack: ").append( lsGetPriorStack() )
						.append("\n  PriorPC:    ").append( lsGetPriorPC() )
						.append("\n  Top:        ").append( lsGetTop() )
						.append("\n  First:      ").append( lsGetFirstRegPos() )
						.append("\n  Closure:    ").append( lsGetClosure() )
						.append("\n  maxStack:   ").append( lsGetMaxStackSize() )
						.append("\n  depth:      ").append( lsGetDepth() )
						.append("\n  Varargs: ("+ lsNVarargs() +")\n");
					for(int v = 0; v < lsNVarargs(); v++) {
						builder.append("    [%3d] %d\n".formatted(v, lsGetVararg(v)));
					}
					builder.append("  Registers: ("+ lsNRegisters() +")\n");
					for(int r = 0; r < lsNRegisters(); r++) {
						builder.append("    [%3d] %d\n".formatted(r, lsGetRegister(r)));
					}
					break;
				}
				
				case LuaTypes.UPVAL: {
					builder.append("UPVAL:\n")
					.append(  "  Stack:     ").append(upvalStack())
					.append("\n  Register:  ").append(upvalRegister());
					break;
				}
				default:
					throw new IllegalArgumentException("Unexpected chunk type: " + type());
				}
			} catch (IOException e) {
				e.printStackTrace();
			}
			
			return builder.toString();
		}
	}
}
