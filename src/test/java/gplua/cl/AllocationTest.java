package gplua.cl;

import static org.junit.Assert.assertEquals;
import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;
import java.util.Arrays;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import com.nativelibs4java.opencl.CLEvent;
import com.theincgi.gplua.cl.LuaTypes;

import gplua.HeapVisualizer;

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
	public List<CLEvent> setupProgram( String src, int heapSize, int logSize ) {
		return super.setupProgram(header + src + footer, heapSize, logSize);
	}
	
	@Override
	public List<CLEvent> setupProgram( String src, int heapSize, int logSize, int heapDebugPos ) {
		return super.setupProgram(header + src + footer, heapSize, logSize, heapDebugPos);
	}
	
	@Test
	void heapInit() throws IOException {
		var events = setupProgram("""
		initHeap( heap, maxHeapSize );
		""", 24, 32);
		
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
		var events = setupProgram("""
		initHeap( heap, maxHeapSize );
		href myObj = allocateHeap( heap, maxHeapSize, 6 );
		putHeapInt( errorOutput, 0, myObj );
		""",24, 32);
		
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
		var events = setupProgram("""
		initHeap( heap, maxHeapSize );
		href myObj = allocateHeap( heap, maxHeapSize, 60 );
		putHeapInt( errorOutput, 0, myObj );
		""", 24, 32);
		
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
		var events = setupProgram("""
		initHeap( heap, maxHeapSize );
		href objA = allocateHeap( heap, maxHeapSize, 5 );
		href objB = allocateHeap( heap, maxHeapSize, 5 );
		putHeapInt( errorOutput, 0, objA );
		putHeapInt( errorOutput, 4, objB );
		freeHeap( heap, maxHeapSize, objA, false );
		""", 32, 32);
		
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
		var events = setupProgram("""
		initHeap( heap, maxHeapSize );
		href objA = allocateHeap( heap, maxHeapSize, 5 );
		href objB = allocateHeap( heap, maxHeapSize, 5 );
		putHeapInt( errorOutput, 0, objA );
		putHeapInt( errorOutput, 4, objB );
		freeHeap( heap, maxHeapSize, objB, false );
		freeHeap( heap, maxHeapSize, objA, false );
		""", 32, 32);
		
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
		var events = setupProgram("""
		initHeap( heap, maxHeapSize );
		href objA = allocateHeap( heap, maxHeapSize, 5 );
		href objB = allocateHeap( heap, maxHeapSize, 5 );
		putHeapInt( errorOutput, 0, objA );
		putHeapInt( errorOutput, 4, objB );
		
		_setMarkTag( heap, objB-4, true ); //keep objB
		
		sweepHeap( heap, maxHeapSize );
		""", 32, 32);
		
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
	
	/**
	 * This test is about a specifc bug that occured
	 * @throws IOException 
	 * */
	@Test
	void exactFitDoesntAlterNextTag() throws IOException {
		var events = setupProgram("""
		initHeap( heap, maxHeapSize );
		
		href a = allocateHeap( heap, maxHeapSize, 72 ); //some object(s)
		href b = allocateHeap( heap, maxHeapSize, 29 - 4 ); //to be deleted
		href c = allocateHeap( heap, maxHeapSize, 14 - 4 ); //end of test region
		freeHeap( heap, maxHeapSize, b, false );            //works as expected
		href d = allocateHeap( heap, maxHeapSize, 15 - 4 ); //some object that fits in b
		href e = allocateHeap( heap, maxHeapSize, 14 - 4 ); //between d and c perfectly, puts a new tag for c?
		//href f = allocateHeap( heap, maxHeapSize, 13 - 4 ); //in the bug this overwrites c which should be inUse
		

		errorOutput[0] = c;
		""", 800, 32);
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		
		DataInputStream log = new DataInputStream(new ByteArrayInputStream(errOut.readData(queue)));
		
		var objC = log.read();
		
		var cTagPos = objC - 4;
		int tag = readIntAt(data, cTagPos);
		System.out.println(Integer.toHexString(tag)); //00 01 00 01
		assertEquals(0x80_00_00_0e, tag);
	}

	@Test
	void allocatesOnSequentialFree() throws IOException {
		var events = setupProgram("""
		initHeap( heap, maxHeapSize );
		
		href a = allocateHeap( heap, maxHeapSize, 10 ); //14 bytes with tag
		href b = allocateHeap( heap, maxHeapSize, 10 ); //14 bytes with tag
		href c = allocateHeap( heap, maxHeapSize, 10 );
		freeHeap( heap, maxHeapSize, a, false );
		freeHeap( heap, maxHeapSize, b, false );
		href d = allocateHeap( heap, maxHeapSize, 24 ); //should go at a, 28 bytes with tag
		
		errorOutput[0] = a;
		errorOutput[1] = d;
		""", 800, 32);
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		
		DataInputStream log = new DataInputStream(new ByteArrayInputStream(errOut.readData(queue)));
		
		var objA = log.read();
		var objD = log.read();
		
		assertEquals(objA, objD, "objD should fit where objA was");
	}
	
	@Test
	void allocatesAfterTinyGap() throws IOException {
		var events = setupProgram("""
		initHeap( heap, maxHeapSize );
		
		href a = allocateHeap( heap, maxHeapSize, 20 ); //some object
		href b = allocateHeap( heap, maxHeapSize, 2 );  //tiny object
		href c = allocateHeap( heap, maxHeapSize, 10 ); //some object
		
		freeHeap( heap, maxHeapSize, b, false ); //free the tiny object
		
		href d = allocateHeap( heap, maxHeapSize, 24 ); //too big for tiny gap
		
		errorOutput[0] = d;
		""", 100, 32);
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		
		//new HeapVisualizer(data, 1000).show();
		DataInputStream log = new DataInputStream(new ByteArrayInputStream(errOut.readData(queue)));
		//dumpHeap(data);
		
		var objD = log.read();
		
		assertNotEquals(0, objD, "objD be allocated somewhere");
	}
}
