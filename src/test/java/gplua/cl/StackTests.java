package gplua.cl;

import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.nativelibs4java.opencl.CLEvent;

public class StackTests extends KernelTestBase {
	
	public static final String header = 
			"""
			#include"heapUtils.h"
			#include"table.h"
			#include"strings.h"
			#include"globals.cl"
			#include"vm.h"
			
			#include"table.cl"
			#include"array.cl"
			#include"hashmap.cl"
			#include"heapUtils.cl"
			#include"strings.cl"
			#include"vm.cl"
			
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
				
				int dummyStack[1024];
				
				struct WorkerEnv env;
				env.luaStack = &dummyStack;
				env.stackSize = 1024;
				env.heap = heap;
				env.maxHeapSize = maxHeapSize;
				env
					
			""";
	public static final String footer = "\n}";
	
//	@BeforeEach
//	void setup() {
//		super.setup();
//	}
//	
//	@Override
//	public List<CLEvent> setupProgram( String src, int heapSize, int logSize ) {
//		return super.setupProgram(header + src + footer, heapSize, logSize);
//	}
//	
//	@Override
//	public List<CLEvent> setupProgram( String src, int heapSize, int logSize, int debugHeapSize ) {
//		return super.setupProgram(header + src + footer, heapSize, logSize, debugHeapSize);
//	}
	
	@Test
	void initStack() {
		
	}
	
	void loadK() {
		
	}
	
}
