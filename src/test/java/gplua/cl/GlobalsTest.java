package gplua.cl;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.nativelibs4java.opencl.CLEvent;
import com.theincgi.gplua.cl.LuaTypes;

class GlobalsTest extends TestBase {
	
	public static final String header = 
			"""
			#include"heapUtils.h"
			#include"table.h"
			#include"strings.h"
			#include"globals.cl"
			
			#include"table.cl"
			#include"array.cl"
			#include"hashmap.cl"
			#include"heapUtils.cl"
			#include"strings.cl"
			
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
	void checkContents() throws IOException {
		var events = setBufferSizes( 4096, 512 );
		long start = System.currentTimeMillis();
		setupProgram("""
		initHeap( heap, maxHeapSize );
		href strTable = newTable( heap, maxHeapSize );
		
		href globals = createGlobals(heap, maxHeapSize, strTable);
		
		putHeapInt( log, 0, strTable );
		putHeapInt( log, 4, globals );
		""");
		long compiled = System.currentTimeMillis();
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		long result = System.currentTimeMillis();
		var log  = errOut.readData(queue);
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(log));
		
		System.out.println(compiled - start);
		System.out.println(result - compiled);
		
		int strTableIndex = dis.readInt();
		int globalsIndex  = dis.readInt();
//		int nfTest        = dis.readInt();
		
		var debug = getChunkData(data, 1000);
		System.out.println(debug);
		
		dumpHeap(data);
		
		var tableInfo = getChunkData(data, globalsIndex);
		var globalHashIndex = tableInfo.tableHashedPart();
		assertNotEquals(0, globalHashIndex);
		
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
					System.out.println("  KEY: "+modKey);
				}
			}
		}
		
		
		assertTrue(true);
	}

}
