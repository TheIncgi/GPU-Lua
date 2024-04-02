package gplua.cl;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.nativelibs4java.opencl.CLEvent;
import com.theincgi.gplua.cl.LuaTypes;

import gplua.HeapVisualizer;

class GlobalsTest extends HeapTestBase {
	
	public static final String header = 
			"""
			// headers & cl files without headers
			#include"types.cl"
			#include"common.cl"
			#include"heapUtils.h"
			#include"array.h"
			#include"table.h"
			#include"opUtils.cl"
			#include"strings.h"
			#include"globals.cl"
			#include"stackUtils.h"
			#include"vm.h"
			#include"closure.h"
			
			
			//manually include .cl for headers since openCL doesn't do that
			#include"vm.cl"
			#include"table.cl"
			#include"array.cl"
			#include"hashmap.cl"
			#include"heapUtils.cl"
			#include"strings.cl"
			#include"stackUtils.cl"
			#include"closure.cl"
			
			__kernel void exec(
			    __global const uint* stackSizes,
			    __global      uchar* heap,
			    __global       char* log
			) {
			    //int dimensions = get_work_dim();
				
				if( get_global_id(0) != 0 )
					return;
					
				uint maxHeapSize = stackSizes[0];
				uint logBufSize = stackSizes[1];
				
				struct WorkerEnv env;
				env.heap = heap;
				env.maxHeapSize = maxHeapSize;
					
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
	public List<CLEvent> setupProgram( String src, int heapSize, int logSize, int debugHeapSize ) {
		return super.setupProgram(header + src + footer, heapSize, logSize, debugHeapSize);
	}
	
	
	@Test
	void checkContents() throws IOException {
		long start = System.currentTimeMillis();
		var events = setupProgram("""
		initHeap( heap, maxHeapSize );
		href strTable = newTable( heap, maxHeapSize );
		
		href globals = createGlobals( &env, strTable);
		
		putHeapInt( log, 0, strTable );
		putHeapInt( log, 4, globals );
		""", 
			8192, //heap 
			32   //log 
			,4096  //debug
		);
		long compiled = System.currentTimeMillis();
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		
		visualizeHeapRecord(data);
		
		long result = System.currentTimeMillis();
		var log  = errOut.readData(queue);
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(log));
		
		System.out.println(compiled - start);
		System.out.println(result - compiled);
		
		int strTableIndex = dis.readInt();
		int globalsIndex  = dis.readInt();
//		int nfTest        = dis.readInt();
		
//		var debug = getChunkData(data, 1000);
//		System.out.println(debug);
		
		dumpHeap(data);
		
		var tableInfo = getChunkData(data, globalsIndex);
		var globalHashIndex = tableInfo.tableHashedPart();
		assertNotEquals(0, globalHashIndex, "may have run out of memory, missing hashed part of globals");
		
		var globalsHash = getChunkData(data, globalHashIndex);
		var keys = getChunkData(data, globalsHash.hashmapKeys());
		var vals = getChunkData(data, globalsHash.hashmapVals());
		
		for(int i = 0; i< keys.arrayCapacity(); i++) {
			var ref = keys.arrayRef(i);
			if(ref == 0) continue;
			var key = getChunkData(data, ref);
			System.out.println("KEY: " + key);
			var valRef = vals.arrayRef(i);
			var val = getChunkData(data, valRef);
			
			if(val.type() == LuaTypes.TABLE) {
				if(val.tableHashedPart() == 0) continue;
				var moduleHash = getChunkData(data, val.tableHashedPart());
				var modKeys = getChunkData(data, moduleHash.hashmapKeys());
				var modVals = getChunkData(data, moduleHash.hashmapVals());
				for(int j = 0; j < modKeys.arrayCapacity(); j++) {
					var modRef = modKeys.arrayRef(j);
					if(modRef == 0) continue;
					var modKey = getChunkData(data, modRef);
					System.out.println("    KEY: "+modKey);
				}
			}
		}
		
		
		assertTrue(true);
	}

}
