package gplua.cl;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.nativelibs4java.opencl.CLEvent;
import com.theincgi.gplua.cl.LuaTypes;

public class GenericTesting extends TestBase {
	
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
			
			struct Args {
				uint maxHeapSize;
				uchar* heap;
				char* log;
			};
			
			void test( struct Args* args ) {
				args->log[0] = 100;
			}
			
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
				
				struct Args args;
				args.maxHeapSize = maxHeapSize;
				args.log = log;
				args.heap = heap;
					
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
	void structTest() throws IOException {
		long start = System.currentTimeMillis();
		var events = setupProgram("""
		test( &args );
		""", 
			8192, //heap 
			32   //log 
		);
		long compiled = System.currentTimeMillis();
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		var data = heap.readData(queue, done);
		
		long result = System.currentTimeMillis();
		var log  = errOut.readData(queue);
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(log));
		
		System.out.println(compiled - start);
		System.out.println(result - compiled);
		
		int test = dis.read();
		
		
		assertEquals(100, test);
	}
	
}
