package gplua.cl;

import static org.junit.Assert.assertEquals;
import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;
import java.util.Arrays;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import com.nativelibs4java.opencl.CLEvent;
import com.theincgi.gplua.cl.LuaTypes;

public class AllocationTest extends TestBase {
	
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
	
	
	
	@BeforeEach
	void setup() {
		super.setup();
	}
	
	@Override
	public void setupProgram( String src ) {
		super.setupProgram(header + src + footer);
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
		
		//System.out.println(Arrays.toString(data));
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(data));
		
		dis.skip(5);
		
		//Check tag 1
		int tag = dis.readInt();
		//System.out.println( "Tag 1: " + tag + " | 0x"+Integer.toHexString(tag) + " | " + Integer.toBinaryString(tag));
		assertTrue(isUseFlag(tag), "First tag must be in use");
		assertEquals("First tag must not be marked", 0, tag & MARK_FLAG);
		assertEquals("First tag size must be 10", 10, tag & SIZE_MASK); //tag size of 4 + request size
		
		//Check new tag 2
		dis.skip( 6 );
		tag = dis.readInt();
		//System.out.println( "Tag 2: " + tag + " | 0x"+Integer.toHexString(tag) + " | " + Integer.toBinaryString(tag));
		assertFalse(isUseFlag(tag), "First tag must not be in use");
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
		assertFalse(isUseFlag(tag), "First tag must not be in use");
		assertEquals("First tag must not be marked", 0, tag & MARK_FLAG);
		assertEquals("Tag size wrong", 19, tag & SIZE_MASK); //buffer size - 5 - (requested allocation size+4) | 24 - 5 - (6+4)
		
		
		dis = new DataInputStream(new ByteArrayInputStream(errOut.readData(queue)));
		int allocatedIndex = dis.readInt();
		assertEquals("Allocated index incorrect", 0, allocatedIndex); //reserve size of 5 + tag size of 4
	} 

	@Test
	void free() throws IOException {
		var events = setBufferSizes( 32, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href objA = allocateHeap( heap, maxHeapSize, 5 );
		href objB = allocateHeap( heap, maxHeapSize, 5 );
		putHeapInt( errorOutput, 0, objA );
		putHeapInt( errorOutput, 4, objB );
		freeHeap( heap, maxHeapSize, objA, false );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		
		//System.out.println(Arrays.toString(data));
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(data));
		
		dis.skip(5);
		
		//Check tag 1
		int tag = dis.readInt();
		//System.out.println( "Tag 1: " + tag + " | 0x"+Integer.toHexString(tag) + " | " + Integer.toBinaryString(tag));
		assertFalse( isUseFlag(tag), "First tag must not be in use");
		assertEquals("First tag must not be marked", 0, tag & MARK_FLAG);
		assertEquals("Tag size wrong", 9, tag & SIZE_MASK); //buffer size - 5 - (requested allocation size+4) | 24 - 5 - (6+4)
		
		dis.skip(5);
		tag = dis.readInt();
		//System.out.println( "Tag 2: " + tag + " | 0x"+Integer.toHexString(tag) + " | " + Integer.toBinaryString(tag));
		assertTrue(isUseFlag(tag), "Second tag must be in use");
	}
	
	@Test
	void freeAndMerge() throws IOException {
		var events = setBufferSizes( 32, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href objA = allocateHeap( heap, maxHeapSize, 5 );
		href objB = allocateHeap( heap, maxHeapSize, 5 );
		putHeapInt( errorOutput, 0, objA );
		putHeapInt( errorOutput, 4, objB );
		freeHeap( heap, maxHeapSize, objB, false );
		freeHeap( heap, maxHeapSize, objA, false );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		
		System.out.println(Arrays.toString(data));
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(data));
		
		dis.skip(5);
		
		//Check tag 1
		int tag = dis.readInt();
		System.out.println( "Tag 1: " + tag + " | 0x"+Integer.toHexString(tag) + " | " + Integer.toBinaryString(tag));
		assertFalse( isUseFlag(tag), "First tag must not be in use");
		assertEquals("First tag must not be marked", 0, tag & MARK_FLAG);
		assertEquals("Tag size wrong", 27, tag & SIZE_MASK);
		
		dis.skip(5);
		tag = dis.readInt();
		System.out.println( "Tag 2: " + tag + " | 0x"+Integer.toHexString(tag) + " | " + Integer.toBinaryString(tag));
		assertFalse(isUseFlag(tag), "Second tag must not be in use");
		assertEquals("Second tag must not be marked", 0, tag & MARK_FLAG);
		assertEquals("Tag size wrong", 18, tag & SIZE_MASK); //merges with unused section 
	}
	
	@Test
	void markAndSweep() throws IOException {
		var events = setBufferSizes( 32, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href objA = allocateHeap( heap, maxHeapSize, 5 );
		href objB = allocateHeap( heap, maxHeapSize, 5 );
		putHeapInt( errorOutput, 0, objA );
		putHeapInt( errorOutput, 4, objB );
		
		_setMarkTag( heap, objB-4, true ); //keep objB
		
		sweepHeap( heap, maxHeapSize );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		
		System.out.println(Arrays.toString(data));
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(data));
		
		dis.skip(5);
		
		//Check tag 1
		int tag1 = dis.readInt();
		dis.skip(5);
		int tag2 = dis.readInt();
		System.out.println( "Tag 1: " + tag1 + " | 0x"+Integer.toHexString(tag1) + " | " + Integer.toBinaryString(tag1));
		System.out.println( "Tag 2: " + tag2 + " | 0x"+Integer.toHexString(tag2) + " | " + Integer.toBinaryString(tag2));
		//System.out.println("Debug: " + Arrays.toString(errOut.readData(queue)));
		
		assertFalse( isUseFlag(tag1), "First tag must not be in use");
		assertEquals("First tag must not be marked", 0, tag1 & MARK_FLAG);
		assertEquals("Tag size wrong", 9, tag1 & SIZE_MASK);
		
		assertTrue(isUseFlag(tag2), "Second tag must be in use");
		assertEquals("Second tag must not be marked", 0, tag2 & MARK_FLAG);
		assertEquals("Tag size wrong", 9, tag2 & SIZE_MASK); //merges with unused section 
	}
	
	


}
