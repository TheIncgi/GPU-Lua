package gplua.cl;

import static org.junit.jupiter.api.Assertions.*;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.nativelibs4java.opencl.CLEvent;

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
		var events = setBufferSizes( 800, 512 );
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
		int nfTest        = dis.readInt();
		
		dumpHeap(data);
		
		assertTrue(true);
	}

}
