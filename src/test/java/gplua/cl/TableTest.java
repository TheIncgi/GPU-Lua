package gplua.cl;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.StringJoiner;

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
	#include"strings.h"
	
	#include"table.cl"
	#include"array.cl"
	#include"hashmap.cl"
	#include"heapUtils.cl"
	#include"strings.cl"
	
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
		putHeapInt( heap, myKey+1, TABLE_INIT_ARRAY_SIZE + 1 ); //table is 1 indexed
		
		href myValue = allocateHeap( heap, maxHeapSize, 5 );
		heap[myValue] = T_INT;
		putHeapInt( heap, myValue+1, 0x11223344 );
		
		tableRawSet( heap, maxHeapSize, myTable, myKey, myValue );
		 
		href newArrayPart = tableGetArrayPart( heap, myTable );
		
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
		
		var oldArrayInfo = getChunkData(data, arrayPart);
		assertFalse(oldArrayInfo.inUse(), "old array part should not be in use after resize");
		
		var arrayInfo = getChunkData(data, newArrayIndex);
		
		var arrayCapacity = readIntAt(arrayInfo.data(), 5);
		assertEquals(expectedResize, arrayCapacity, "array capacity incorrect");
		
		var arraySize = readIntAt(arrayInfo.data(), 1);
		assertEquals(0, arraySize, "array size incorrect, should be 0 since there's no elements 1..N-1");
		
		var arrayV5Index = readIntAt(arrayInfo.data(), 9 + 4 * initArraySize);
		assertEquals(valueIndex, arrayV5Index, "first pointer of array should point to the int value on the heap");
		
		var storedValueChunk = getChunkData(data, arrayV5Index);
		var storedValue = readIntAt(storedValueChunk.data(), 1);
		
		assertEquals(0x11223344, storedValue, "stored value doesn't match");
	}
	
	@Test
	void insertIntoHashmap() throws IOException {
		var events = setBufferSizes( 128, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href myTable = newTable( heap, maxHeapSize );
		href hashedPart = tableCreateHashedPart( heap, maxHeapSize, myTable ); 
		
		string str = "example";
		uint slen = strLen( str );
		href hstr = heapString(heap, maxHeapSize, myTable, str); 
		uint hash = hashString( str, slen );
		uint hashObj = heapHash( heap, hstr );
		
		
		putHeapInt( errorOutput, 0, myTable );
		putHeapInt( errorOutput, 4, slen );
		putHeapInt( errorOutput, 8, hstr );
		putHeapInt( errorOutput, 12, hash );
		putHeapInt( errorOutput, 16, hashObj );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		//dumpHeap(data);
		var log  = errOut.readData(queue);
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(log));
		
		int tableIndex = dis.readInt(); // 0
		assertNotEquals(0, tableIndex, "failed to allocate table, more memory or missing return?");
		int hstrLen = dis.readInt(); //4
		assertEquals("example".length(), hstrLen);
		int hstrIndex = dis.readInt(); // 8
		long hash = ((long)dis.readInt()) & 0x00_00_00_00_FF_FF_FF_FFL; //12
		long hashObj = ((long)dis.readInt()) & 0x00_00_00_00_FF_FF_FF_FFL; //16
		
		assertEquals(hash, hashObj, "The hash for string vs heap'd string should match");
		
		var tableInfo = getChunkData(data, tableIndex);
		var hashedInfo = getChunkData(data, tableInfo.tableHashedPart());
		var keysInfo = getChunkData(data, hashedInfo.hashmapKeys());
		var valsInfo = getChunkData(data, hashedInfo.hashmapVals());
		
//		var keysSize = keysInfo.readInt(1);
		var keysCapacity = keysInfo.arrayCapacity();
		
		int expectedHashSlot = (int)(hash % keysCapacity);
		
		var keyX = keysInfo.arrayRef(expectedHashSlot);
		assertEquals(hstrIndex, keyX, "expected key of hashmap in expected slot to point to example string");
	}
	
	@Test
	void getStringFromHashmap() throws IOException {
		var events = setBufferSizes( 128, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href myTable = newTable( heap, maxHeapSize );
		href hashedPart = tableCreateHashedPart( heap, maxHeapSize, myTable ); 
		
		string str = "example";
		uint slen = strLen( str );
		href hstr = heapString(heap, maxHeapSize, myTable, str); 
		href hstrCopy = heapString(heap, maxHeapSize, myTable, str); //checks in hashmap
		
		putHeapInt( errorOutput, 0, myTable );
		putHeapInt( errorOutput, 4, slen );
		putHeapInt( errorOutput, 8, hstr );
		putHeapInt( errorOutput, 12, hstrCopy );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		//dumpHeap(data);
		var log  = errOut.readData(queue);
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(log));
		
		int tableIndex = dis.readInt(); // 0
		assertNotEquals(0, tableIndex, "failed to allocate table, more memory or missing return?");
		int hstrLen = dis.readInt(); //4
		assertEquals("example".length(), hstrLen);
		int hstrIndex = dis.readInt(); // 8
		int hstrCopyIndex = dis.readInt(); // 12
		
		assertEquals(hstrIndex, hstrCopyIndex, "Duplicate strings should return the same index");
		
	}
	
	@Test
	void duplicateEntry() throws IOException {
		var events = setBufferSizes( 128, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href myTable = newTable( heap, maxHeapSize );
		
		href x = allocateHeap( heap, maxHeapSize, 5 );
		heap[x] = T_INT;
		putHeapInt( heap, x + 1, 123 );
		
		tableRawSet( heap, maxHeapSize, myTable, x, x );
		tableRawSet( heap, maxHeapSize, myTable, x, x );
		
		putHeapInt( errorOutput, 0, myTable );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
//		dumpHeap(data);
		var log  = errOut.readData(queue);
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(log));
		
		int tableIndex = dis.readInt(); // 0
		
		var tableInfo = getChunkData(data, tableIndex);
		var hashInfo = getChunkData(data, tableInfo.tableHashedPart());
		var keysInfo = getChunkData(data, hashInfo.hashmapKeys());
		
		int matches = 0;
		for(int i = 0; i < keysInfo.arrayCapacity(); i++) {
			if( keysInfo.arrayRef(i) != 0)
				matches ++;
		}
		assertEquals(1, matches, "found more than one entry in the hashmap");
	}
	
	@Test
	void resize() throws IOException {
		var events = setBufferSizes( 256, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href myMap = newHashmap( heap, maxHeapSize, 4 );
		
		href x = allocateHeap( heap, maxHeapSize, 5 );
		heap[x] = T_INT;
		putHeapInt( heap, x + 1, 123 );
		
		hashmapPut( heap, maxHeapSize, myMap, x, x );
		
		bool worked = resizeHashmap( heap, maxHeapSize, myMap, 8 );
		
		putHeapInt( errorOutput, 0, myMap );
		putHeapInt( errorOutput, 4, x );
		putHeapInt( errorOutput, 8, worked ? 1 : 0 );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
//		dumpHeap(data);
		var log  = errOut.readData(queue);
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(log));
		
		int mapIndex = dis.readInt(); // 0
		int xIndex = dis.readInt(); // 4
		int worked = dis.readInt(); // 8
		
		assertTrue(worked == 1, "resize failed");
		
		var mapInfo = getChunkData(data, mapIndex);
		var keysInfo = getChunkData(data, mapInfo.hashmapKeys());
		
		for( int i = 0; i < keysInfo.arrayCapacity(); i++) {
			if( keysInfo.arrayRef(i) == xIndex )
				return;
		}
		fail("couldn't find x in keys");
		
	}
	
	@Test
	void multiString() throws IOException {
		var events = setBufferSizes( 256, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href myTable = newTable( heap, maxHeapSize );
		href hashedPart = tableCreateHashedPart( heap, maxHeapSize, myTable ); 
		
		string str1 = "ex1";
		href hstr1 = heapString(heap, maxHeapSize, myTable, str1); 
		
		string str2 = "ex2";
		href hstr2 = heapString(heap, maxHeapSize, myTable, str2); 
		
		string str3 = "ex3";
		href hstr3 = heapString(heap, maxHeapSize, myTable, str3); 
		
		string str4 = "ex4";
		href hstr4 = heapString(heap, maxHeapSize, myTable, str4); 
		
		string str5 = "ex5";
		href hstr5 = heapString(heap, maxHeapSize, myTable, str5); 
		
		putHeapInt( errorOutput, 0, myTable );
		putHeapInt( errorOutput, 4, hstr1 );
		putHeapInt( errorOutput, 8, hstr2 );
		putHeapInt( errorOutput, 12, hstr3 );
		putHeapInt( errorOutput, 16, hstr4 );
		putHeapInt( errorOutput, 20, hstr5 );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
//		dumpHeap(data);
		var log  = errOut.readData(queue);
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(log));
		
		int tableIndex = dis.readInt(); // 0
		int str1 = dis.readInt(); // 4
		int str2 = dis.readInt(); // 8
		int str3 = dis.readInt(); // 12
		int str4 = dis.readInt(); // 16
		int str5 = dis.readInt(); // 20
		
		var tableInfo = getChunkData(data, tableIndex);
		var hashedInfo = getChunkData(data, tableInfo.tableHashedPart());
		var keysInfo = getChunkData(data, hashedInfo.hashmapKeys());
		
		HashMap<Integer, String> notFound = new HashMap<>();
		notFound.put(str1, "ex1");
		notFound.put(str2, "ex2");
		notFound.put(str3, "ex3");
		notFound.put(str4, "ex4");
		notFound.put(str5, "ex5");
		
		for(int i = 0; i < keysInfo.arrayCapacity(); i++) {
			var ref = keysInfo.arrayRef(i);
			if(ref == 0) continue;
			notFound.remove(ref);
		}
		
		if(!notFound.isEmpty()) {
			var msg = new StringJoiner(", ");
			for(var e : notFound.values())
				msg.add(e);
			fail("Couldn't find string entries for " + msg);
		}
		
	}
}
