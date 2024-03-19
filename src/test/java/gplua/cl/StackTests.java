package gplua.cl;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.file.Files;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.nativelibs4java.opencl.CLEvent;
import com.theincgi.gplua.cl.LuaSrcUtil;

public class StackTests extends KernelTestBase {
	
	public static final String header = 
			"""
			#include"heapUtils.h"
			#include"table.h"
			#include"strings.h"
			#include"globals.cl"
			#include"vm.h"
			#include"stackUtils.h"
			
			#include"table.cl"
			#include"array.cl"
			#include"hashmap.cl"
			#include"heapUtils.cl"
			#include"strings.cl"
			#include"vm.cl"
			#include"stackUtils.cl"
			
			__kernel void exec(
			    __global        uint* luaStack,
			    __global const ulong* stackSizes,
			    __global        char* errorOutput,
			    __global const  long* maxExecutionTime,
			    __global       uchar* heap,
			    
			    /*Byte code pieces*/
			    __global unsigned int* numFunctions,
			    __global unsigned int* linesDefined,
			    __global unsigned int* lastLinesDefined,
			    __global        uchar* numParams,
			    __global         bool* isVararg, //could be true or passed number of args & set that way
			    __global        uchar* maxStackSizes, //from bytecode, poor name planning, oops, different than stackSizes[0]
			
			    //code
			    __global          int* codeIndexes,
			    __global unsigned int* code, //[function #][instruction] = code[ codeIndexes[function] + instruction ]
			    
			    //constants
			    __global            int* constantsPrimaryIndex,
			    __global            int* constantsSecondaryIndex,
			    __global          uchar* constantsData, //[function #][byte] - single byte type, followed by value, strings are null terminated
			    __global            int* protoLengths,
			    
			    //upvals
			    __global           int* upvalsIndex,
			    __global         uchar* upvals
			) {
			    //int dimensions = get_work_dim();
				
				if( get_global_id(0) != 0 )
					return;
				
				
				
				struct WorkerEnv env;
				env.luaStack                = luaStack;                  //&(luaStack[ maxStackSize * glid ]);
				env.stackSize               = stackSizes[0];
				env.heap                    = heap;
				env.maxHeapSize             = stackSizes[1];
				env.error                   = errorOutput;
				env.errorSize               = stackSizes[2];
				env.constantsPrimaryIndex   = constantsPrimaryIndex;
				env.constantsSecondaryIndex = constantsSecondaryIndex;
				env.constantsData           = constantsData;
				
				initHeap( heap, env.maxHeapSize );
				
				href stringTable = newTable(      heap, env.maxHeapSize );
				href globals     = createGlobals( heap, env.maxHeapSize, stringTable );
				
				env.stringTable             = stringTable;
				env.globals                 = globals;
				env.func = 0;
				env.pc = 0;
				
				
					
			""";
	public static final String footer = "\n}";
	
	@BeforeEach
	void setup() {
		super.setup();
	}
	
	@Override
	public List<CLEvent> setupProgram(String src, byte[] byteCode, int heapSize, int stackSize, int errSize)
			throws IOException {
		return super.setupProgram(header + src + footer, byteCode, heapSize, stackSize, errSize);
	}
	
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
	void initStack() throws FileNotFoundException, IOException {
		var events = setupProgram("""
		initStack( env.luaStack, 1, 2, 3 );
		
		for(int i = 0; i < env.stackSize; i++)
			putHeapInt( errorOutput, i * 4, env.luaStack[ i ] );
		""", 
		LuaSrcUtil.readBytecode("print.out"),
		4096, //heap
		1024, //stack
		1024*4    //log/err
		);
		
		var done = run(events);
		var log  = args.errorBuffer.readData(queue, done);
		
		int[] validation = new int[] {1, 8, 5, 1, 2};
		for(int i = 0; i < validation.length; i++) {
			assertEquals(validation[i], readIntAt(log, i*4), "validation["+i+"] failed");
		}
	}
	
	void loadK() {
		
	}
	
}
