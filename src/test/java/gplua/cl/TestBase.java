package gplua.cl;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.CLKernel;
import com.nativelibs4java.opencl.CLProgram;
import com.nativelibs4java.opencl.CLQueue;
import com.nativelibs4java.opencl.JavaCL;
import com.nativelibs4java.opencl.CLMem.Usage;
import com.theincgi.gplua.cl.ByteArray1D;
import com.theincgi.gplua.cl.IntArray1D;
import com.theincgi.gplua.cl.LuaTypes;

import gplua.HeapVisualizer;

public class TestBase {
	CLProgram program;
	CLQueue queue;
	CLContext context;
	CLKernel kernel;
	
	ByteArray1D heap, errOut;
	IntArray1D stackSizes;
	private Integer heapDebugStart = null;
	
	public static final int USE_FLAG  = 0x80000000,
							MARK_FLAG = 0x40000000,
							SIZE_MASK = 0x3FFFFFFF;
	
	void setup() {
		System.out.println("\n==========SETUP==========");
		context = JavaCL.createBestContext();
		queue = context.createDefaultOutOfOrderQueue();
		heap = new ByteArray1D(context, Usage.InputOutput);
		errOut = new ByteArray1D(context, Usage.InputOutput);
		stackSizes = new IntArray1D(context, Usage.Input);
	}
	
	public List<CLEvent> setupProgram( String src, int heapSize, int errSize ) {
		program = context.createProgram( src );
//		program.addInclude(System.getProperty("user.dir")+"/src/main/resources/com/theincgi/gplua");
		program.addInclude("src/main/resources/com/theincgi/gplua");
		program = program.build();
		kernel = program.createKernel("exec");
		var events = setBufferSizes(heapSize, errSize);
		kernel.setArgs(stackSizes.arg(), heap.arg(), errOut.arg());
		return events;
	}
	
	/**heap size reported to the kernel will be heapDebugPos*/
	public List<CLEvent> setupProgram( String src, int heapSize, int errSize, int heapDebugPos ) {
		program = context.createProgram( src );
//		program.addInclude(System.getProperty("user.dir")+"/src/main/resources/com/theincgi/gplua");
		program.addInclude("src/main/resources/com/theincgi/gplua");
		enableHeapDebugging(heapDebugPos);
		program = program.build();
		kernel = program.createKernel("exec");
		var events = setBufferSizes(heapSize, errSize);
		kernel.setArgs(stackSizes.arg(), heap.arg(), errOut.arg());
		return events;
	}
	
	private List<CLEvent> setBufferSizes( int heap, int err ) {
		var eList = new ArrayList<CLEvent>();
		this.heap.noData(heap);
		eList.add(errOut.fillEmpty(err, queue));
		eList.add(stackSizes.loadData(new int[] {
			heapDebugStart == null? heap : heapDebugStart, 
			err
		}, queue));
		return eList;
	}
	
	static boolean isUseFlag( int tag ) {
		return (tag & USE_FLAG) != 0;
	}
	
	static boolean isMarkFlag( int tag ) {
		return (tag & MARK_FLAG) != 0;
	}
	
	static int chunkSize( int tag ) {
		return (tag & SIZE_MASK);
	}
	
	static int readIntAt(byte[] data, int offset) throws IOException {
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(data));
		dis.skip(offset);
		return dis.readInt();
	}
	
	public static TaggedMemory getChunkData( byte[] heap, int allocationIndex ) throws IOException {
		if(allocationIndex == 0)
			return null;
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(heap));
		int tagPos = allocationIndex - 4;
		dis.skip(tagPos);
		int tag = dis.readInt();
		int size = chunkSize( tag );
		var data = dis.readNBytes(size - 4);
		return new TaggedMemory(allocationIndex, isUseFlag(tag), isMarkFlag(tag), data);
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
	
	/**
	 * Choose a number outside the range of the heap that will be used
	 * */
	private void enableHeapDebugging( int startHeapRecordAt ) {
		this.heapDebugStart  = startHeapRecordAt;
		program.defineMacro("DEBUG_ALLOCATION", "true");
		program.defineMacro("DEBUG_ALLOCATION_START", ""+startHeapRecordAt);
	}
	
	/**Call enableHeapDebugging before running
	 * @param data 
	 * @throws IOException */
	public void visualizeHeapRecord(byte[] data) throws IOException {
		Objects.requireNonNull(heapDebugStart);
		new HeapVisualizer(data, heapDebugStart + 4).show();
	}
	
	
	public static record TaggedMemory(int allocationIndex, boolean inUse, boolean marked, byte[] data) {
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
		
		public int stringLength() throws IOException {
			assertType(LuaTypes.STRING);
			return readInt( 1 );
		}
		
		public String stringValue() throws IOException {
			assertType(LuaTypes.STRING);
			return new String(data, 5, stringLength());
		}
		
		public String toString() {
			if(!inUse())
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
					builder.append( data()[1] != 0 ? "TRUE" : "FALSE" );
					break;
				}
				case LuaTypes.NUMBER: {
					builder.append("NUMBER: TODO");
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
						.append("  Upvals: ").append(readInt(1)).append("\n")
						.append("  _ENV:   ").append(readInt(5));
					break;
				}
				case LuaTypes.SUBSTRING: {
					builder.append("SUBSTRING:\n")
						.append("  Ref:     \n").append(readInt(1))
						.append("  Start:   \n").append(readInt(5))
						.append("  Length:  \n").append(readInt(9));
//					.append("  Preview: \"").append().append("\"");
					break;
				}
				case LuaTypes.NATIVE_FUNC: {
					builder.append("NATIVE FUNC:\n")
						.append("  ID: ").append(readInt(1));
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
