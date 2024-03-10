package gplua.cl;

import static org.junit.Assert.assertEquals;
import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
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

public class AllocationTest {
	
	public static final String header = 
	"""
	#include"heapUtils.h"
	
	#include"heapUtils.cl"
	
	__kernel void exec(
	    __global const uint* stackSizes,
	    __global      uchar* heap,
	    __global       char* errorOutput
	) {
	    //int dimensions = get_work_dim();
		
		if( get_global_id(0) != 0 )
			return;
			
		uint maxHeapSize = stackSizes[0];
		uint errBufSize = stackSizes[1];
			
	""";
	
	public static final String footer = "\n}";
	
	public static final int USE_FLAG  = 0x80000000,
							MARK_FLAG = 0x40000000,
							SIZE_MASK = 0x3FFFFFFF;
	
	static CLProgram program;
	static CLQueue queue;
	static CLContext context;
	static CLKernel kernel;
	
	static ByteArray1D heap, errOut;
	static IntArray1D stackSizes;
	
	
	@BeforeAll
	static void setup() {
		System.out.println("\n==========SETUP==========");
		context = JavaCL.createBestContext();
		queue = context.createDefaultOutOfOrderQueue();
		heap = new ByteArray1D(context, Usage.InputOutput);
		errOut = new ByteArray1D(context, Usage.InputOutput);
		stackSizes = new IntArray1D(context, Usage.Input);
	}
	
	public void setupProgram( String src ) {
		program = context.createProgram(header + src + footer);
//		program.addInclude(System.getProperty("user.dir")+"/src/main/resources/com/theincgi/gplua");
		program.addInclude("src/main/resources/com/theincgi/gplua");
		program = program.build();
		kernel = program.createKernel("exec");
		kernel.setArgs(stackSizes.arg(), heap.arg(), errOut.arg());
	}
	
	public List<CLEvent> setBufferSizes( int heap, int err ) {
		var eList = new ArrayList<CLEvent>();
		eList.add(this.heap.fillEmpty(heap, queue));
		eList.add(this.errOut.fillEmpty(err, queue));
		eList.add(stackSizes.loadData(new int[] {heap, err}, queue));
		return eList;
	}
	
	@Test
	void heapInit() throws IOException {
		var events = setBufferSizes( 24, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		
		var data = heap.readData(queue, done);
		
		//System.out.println(Arrays.toString(data));
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(data));
		
		assertEquals("heap[0] must be 0", 0, dis.readByte());
		assertEquals("heap[1] must be T_BOOL", LuaTypes.BOOL, dis.read());
		assertEquals("heap[2] be false", 0, dis.read());
		assertEquals("heap[3] must be T_BOOL", LuaTypes.BOOL, dis.read());
		assertEquals("heap[4] be true", 1, dis.read());
		
		int tag = dis.readInt();
		//System.out.println( tag + " | 0x"+Integer.toHexString(tag) + " | " + Integer.toBinaryString(tag));
		assertEquals("First tag must not be in use", 0, tag & USE_FLAG);
		assertEquals("First tag must not be marked", 0, tag & MARK_FLAG);
		assertEquals("First tag size must be BUF_SIZE - RESERVED", 19, tag & SIZE_MASK);
		
	}
	
	@Test
	void heapAllocate() throws IOException {
		var events = setBufferSizes( 24, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href myObj = allocateHeap( heap, maxHeapSize, 6 );
		putHeapInt( errorOutput, 0, myObj );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		
		var data = heap.readData(queue, done);
		
		System.out.println(Arrays.toString(data));
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(data));
		
		dis.skip(5);
		
		//Check tag 1
		int tag = dis.readInt();
		//System.out.println( "Tag 1: " + tag + " | 0x"+Integer.toHexString(tag) + " | " + Integer.toBinaryString(tag));
		assertTrue(0 != (tag & USE_FLAG), "First tag must be in use");
		assertEquals("First tag must not be marked", 0, tag & MARK_FLAG);
		assertEquals("First tag size must be 10", 10, tag & SIZE_MASK); //tag size of 4 + request size
		
		//Check new tag 2
		dis.skip( 6 );
		tag = dis.readInt();
		//System.out.println( "Tag 2: " + tag + " | 0x"+Integer.toHexString(tag) + " | " + Integer.toBinaryString(tag));
		assertTrue(0 == (tag & USE_FLAG), "First tag must not be in use");
		assertEquals("First tag must not be marked", 0, tag & MARK_FLAG);
		assertEquals("First tag size must be 9", 9, tag & SIZE_MASK); //buffer size - 5 - (requested allocation size+4) | 24 - 5 - (6+4)
		
		
		dis = new DataInputStream(new ByteArrayInputStream(errOut.readData(queue)));
		int allocatedIndex = dis.readInt();
		assertEquals("Allocated index incorrect", 9, allocatedIndex); //reserve size of 5 + tag size of 4
	}
	
	@Test
	void overAllocate() throws IOException {
		var events = setBufferSizes( 24, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href myObj = allocateHeap( heap, maxHeapSize, 60 );
		putHeapInt( errorOutput, 0, myObj );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		
		//System.out.println(Arrays.toString(data));
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(data));
		
		dis.skip(5);
		
		//Check tag 1
		int tag = dis.readInt();
		//System.out.println( "Tag 1: " + tag + " | 0x"+Integer.toHexString(tag) + " | " + Integer.toBinaryString(tag));
		assertTrue(0 == (tag & USE_FLAG), "First tag must not be in use");
		assertEquals("First tag must not be marked", 0, tag & MARK_FLAG);
		assertEquals("Tag size wrong", 19, tag & SIZE_MASK); //buffer size - 5 - (requested allocation size+4) | 24 - 5 - (6+4)
		
		
		dis = new DataInputStream(new ByteArrayInputStream(errOut.readData(queue)));
		int allocatedIndex = dis.readInt();
		assertEquals("Allocated index incorrect", 0, allocatedIndex); //reserve size of 5 + tag size of 4
	} 
}
