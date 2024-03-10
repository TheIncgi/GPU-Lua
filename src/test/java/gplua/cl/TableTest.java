package gplua.cl;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;

import static org.junit.Assert.assertEquals;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.nativelibs4java.opencl.CLEvent;
import com.theincgi.gplua.cl.LuaTypes;

class TableTest extends TestBase {

	public static final String header = 
	"""
	#include"heapUtils.h"
	#include"table.h"
	
	#include"table.cl"
	#include"array.cl"
	#include"hashmap.cl"
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
	void createTable( ) throws IOException {
		var events = setBufferSizes( 32, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href myObj = newTable( heap, maxHeapSize );
		putHeapInt( errorOutput, 0, myObj );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		var log  = errOut.readData(queue);
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(log));
		
		int tableIndex = dis.readInt();
		assertNotEquals(0, tableIndex, "failed to allocate table, more memory or missing return?");
		
		var tableInfo = getChunkData(data, tableIndex);
		
		assertTrue(tableInfo.inUse(), "table chunk should be in use");
		assertFalse(tableInfo.marked(), "table chunk shouldn't be marked");
		assertEquals("type isn't table type", LuaTypes.TABLE, tableInfo.data()[0]);
	}
	
	@Test
	void createTableWithArray( ) throws IOException {
		var events = setBufferSizes( 128, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href myTable = newTable( heap, maxHeapSize );
		href arrayPart = tableCreateArrayPart( heap, maxHeapSize, myTable ); 
		putHeapInt( errorOutput, 0, myTable );
		putHeapInt( errorOutput, 4, arrayPart );
		putHeapInt( errorOutput, 8, TABLE_INIT_ARRAY_SIZE );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		var log  = errOut.readData(queue);
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(log));
		
		int tableIndex = dis.readInt();
		assertNotEquals(0, tableIndex, "failed to allocate table, more memory or missing return?");
		int arrayPart = dis.readInt();
		assertNotEquals(0, arrayPart, "failed to allocate array part, more memory or missing return?");
		int initArraySize = dis.readInt();
		
		var tableInfo = getChunkData(data, tableIndex);
		var arrayInfo = getChunkData(data, arrayPart);
		
		assertTrue(tableInfo.inUse(), "table chunk should be in use");
		assertFalse(tableInfo.marked(), "table chunk shouldn't be marked");
		assertEquals("type isn't table type", LuaTypes.TABLE, tableInfo.data()[0]);
		
		assertTrue(arrayInfo.inUse(), "array part should be in use");
		assertFalse(arrayInfo.marked(), "array part should not be marked");
		assertEquals("type isn't array", LuaTypes.ARRAY, arrayInfo.data()[0]);
		
		assertEquals("array size doesn't match init setting", initArraySize, readIntAt(arrayInfo.data(), 5) );
	}
	
	@Test
	void createTableWithHashmap( ) throws IOException {
		var events = setBufferSizes( 128, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href myTable = newTable( heap, maxHeapSize );
		href hashedPart = tableCreateHashedPart( heap, maxHeapSize, myTable ); 
		putHeapInt( errorOutput, 0, myTable );
		putHeapInt( errorOutput, 4, hashedPart );
		putHeapInt( errorOutput, 8, HASHMAP_INIT_SIZE ); //warnings are from wrong type, but it's fine
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		var log  = errOut.readData(queue);
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(log));
		
		int tableIndex = dis.readInt();
		assertNotEquals(0, tableIndex, "failed to allocate table, more memory or missing return?");
		int arrayPart = dis.readInt();
		assertNotEquals(0, arrayPart, "failed to allocate array part, more memory or missing return?");
		int initHashSize = dis.readInt();
		
		var tableInfo = getChunkData(data, tableIndex);
		var hashedInfo = getChunkData(data, arrayPart);
		
		assertTrue(tableInfo.inUse(), "table chunk should be in use");
		assertFalse(tableInfo.marked(), "table chunk shouldn't be marked");
		assertEquals("type isn't table type", LuaTypes.TABLE, tableInfo.data()[0]);
		
		assertTrue(hashedInfo.inUse(), "hashed part should be in use");
		assertFalse(hashedInfo.marked(), "hashed part should not be marked");
		assertEquals("type isn't hashmap", LuaTypes.HASHMAP, hashedInfo.data()[0]);
		
		int keysPartIndex = readIntAt(hashedInfo.data(), 1);
		assertNotEquals(0, arrayPart, "failed to allocate keys part of hashmap, more memory or missing return?");
		int valsPartIndex = readIntAt(hashedInfo.data(), 5);
		assertNotEquals(0, arrayPart, "failed to allocate vals part of hashmap, more memory or missing return?");
		
		var keysPartInfo = getChunkData(data, keysPartIndex);
		var valsPartInfo = getChunkData(data, valsPartIndex);
		
		var keysSize = readIntAt(keysPartInfo.data(), 5);
		var valsSize = readIntAt(valsPartInfo.data(), 5);
		
		assertEquals("keys of hashmap should have HASHMAP_INIT_SIZE capacity", initHashSize, keysSize);
		assertEquals("vals of hashmap should have HASHMAP_INIT_SIZE capacity", initHashSize, valsSize);
	}
	
	@Test
	void insertIntoTableArrayCapacity() throws IOException {
		var events = setBufferSizes( 140, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href myTable = newTable( heap, maxHeapSize );
		href arrayPart = tableCreateArrayPart( heap, maxHeapSize, myTable ); 
		
		href myValue = allocateHeap( heap, maxHeapSize, 5 );
		heap[myValue] = T_INT;
		putHeapInt( heap, myValue+1, 0x11223344 );
		
		arraySet( heap, arrayPart, 0, myValue );
		
		putHeapInt( errorOutput, 0, myTable );
		putHeapInt( errorOutput, 4, arrayPart );
		putHeapInt( errorOutput, 8, myValue );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		var log  = errOut.readData(queue);
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(log));
		
		int tableIndex = dis.readInt();
		assertNotEquals(0, tableIndex, "failed to allocate table, more memory or missing return?");
		int arrayPart = dis.readInt();
		assertNotEquals(0, arrayPart, "failed to allocate array part, more memory or missing return?");
		int valueIndex = dis.readInt();
		assertNotEquals(0, valueIndex, "failed to allocate the int value to put into the array");
		
		//var tableInfo = getChunkData(data, tableIndex);
		var arrayInfo = getChunkData(data, arrayPart);
		
		var arraySize = readIntAt(arrayInfo.data(), 1);
		assertEquals(1, arraySize, "array size incorrect");

		var arrayV1Index = readIntAt(arrayInfo.data(), 9 /*+ 4 * 0*/);
		assertEquals(valueIndex, arrayV1Index, "first pointer of array should point to the int value on the heap");
		
		var storedValueChunk = getChunkData(data, arrayV1Index);
		var storedValue = readIntAt(storedValueChunk.data(), 1);
		
		
		assertEquals(0x11223344, storedValue, "stored value doesn't match");
	}
	
	@Test
	void insertOutOfTableArrayCapacity() throws IOException {
		var events = setBufferSizes( 140, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href myTable = newTable( heap, maxHeapSize );
		href arrayPart = tableCreateArrayPart( heap, maxHeapSize, myTable ); 
		
		href myKey = allocateHeap( heap, maxHeapSize, 5 );
		heap[myKey] = T_INT;
		putHeapInt( heap, myKey+1, TABLE_INIT_ARRAY_SIZE );
		
		href myValue = allocateHeap( heap, maxHeapSize, 5 );
		heap[myValue] = T_INT;
		putHeapInt( heap, myValue+1, 0x11223344 );
		
		href newArrayPart = tableCreateArrayPart( heap, maxHeapSize, myTable );
		 
		tableRawSet( heap, maxHeapSize, myTable, myKey, myValue );
		
		putHeapInt( errorOutput, 0, myTable );
		putHeapInt( errorOutput, 4, arrayPart );
		putHeapInt( errorOutput, 8, myKey );
		putHeapInt( errorOutput, 12, myValue );
		putHeapInt( errorOutput, 16, TABLE_INIT_ARRAY_SIZE );
		putHeapInt( errorOutput, 20, resizeRule( TABLE_INIT_ARRAY_SIZE ));
		putHeapInt( errorOutput, 24, newArrayPart);
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		var log  = errOut.readData(queue);
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(log));
		
		int tableIndex = dis.readInt();
		assertNotEquals(0, tableIndex, "failed to allocate table, more memory or missing return?");
		int arrayPart = dis.readInt();
		assertNotEquals(0, arrayPart, "failed to allocate array part, more memory or missing return?");
		int keyIndex = dis.readInt();
		assertNotEquals(0, keyIndex, "failed to allocate the int key to put into the table");
		int valueIndex = dis.readInt();
		assertNotEquals(0, valueIndex, "failed to allocate the int value to put into the table");
		int initArraySize = dis.readInt();
		int expectedResize = dis.readInt();
		assertTrue( initArraySize < expectedResize, "resized array isn't bigger" );
		int newArrayIndex = dis.readInt();
		
		//keeps old array and defaults to hashed part
		//assertNotEquals(0, newArrayIndex, "failed to allocate space for the resized array");
		
		var tableInfo = getChunkData(data, tableIndex);
		var hashedPart = readIntAt(tableInfo.data(), 5);
		assertEquals(0, hashedPart, "hashed part created, may not have been able to resize array part");
		
		var arrayInfo = getChunkData(data, newArrayIndex);
		
		var arraySize = readIntAt(arrayInfo.data(), 1);
		assertEquals(initArraySize + 1, arraySize, "array size incorrect");
		
		var arrayCapacity = readIntAt(arrayInfo.data(), 5);
		assertEquals(expectedResize, arrayCapacity, "array capacity incorrect");
		
		var arrayV5Index = readIntAt(arrayInfo.data(), 9 + 4 * 5);
		assertEquals(valueIndex, arrayV5Index, "first pointer of array should point to the int value on the heap");
		
		var storedValueChunk = getChunkData(data, arrayV5Index);
		var storedValue = readIntAt(storedValueChunk.data(), 1);
		
		assertEquals(0x11223344, storedValue, "stored value doesn't match");
	}
}
