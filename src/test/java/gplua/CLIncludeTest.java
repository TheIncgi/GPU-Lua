package gplua;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;

import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.CLProgram;
import com.nativelibs4java.opencl.JavaCL;
import com.theincgi.gplua.cl.LuaKernelArgs;
import com.theincgi.gplua.cl.LuaSrcUtil;

public class CLIncludeTest {
	
	public static void main(String[] args) throws FileNotFoundException, IOException {
		CLContext context = JavaCL.createBestContext();
//		
//		var srcURL = CLBytecodeChecking.class.getResource("luavm.cl");
//		var file = srcURL.getFile();
		
		var srcCode = """
			__kernel void exec(
//			    __global const uint * workSize, //get_global_size
//			    __global      uchar* callInfoStack,
                __global       uint* luaStack,
			    __global const uint* stackSizes,
			    __global       char* errorOutput,
			    __global const long* maxExecutionTime,
			    __global uchar* heap,
			    __global  long* heapNext,
			    
			    /*Byte code pieces*/
			    __global unsigned int* numFunctions,
			    __global unsigned int* linesDefined,
			    __global unsigned int* lastLinesDefined,
			    __global        uchar* numParams,
			    __global         bool* isVararg,
			    __global        uchar* maxStackSize,
			
			    //code
			    __global          int* codeIndexes,
			    __global unsigned int* code, //[function #][instruction]
			    
			    //constants
			    //__global unsigned int* constantsLen,
			    __global          int* constantsPrimaryIndex,
			    __global          int* constantsSecondaryIndex,
			    __global        uchar* constantsData, //[function #][byte] - single byte type, followed by value, strings are null terminated
			    __global          int* protoLengths,
			    
			    //upvals
			    __global          int* upvalsIndex,
			    __global        uchar* upvals //[function #][ index*2 ] - 2 byte pairs, bool "in stack" & upval index
			    
			    //debug info?
			
			    
			) {
			    //int dimensions = get_work_dim();
				
				if( get_global_id(0) != 0 )
					return;
				
				__local int shared;
				
				int sLen = 0;
				errorOutput[ 2 + sLen++ ] = (uchar) atomic_inc(&shared);
				errorOutput[ 2 + sLen++ ] = (uchar) atomic_inc(&shared);
				
				for(int func = 0; func < *numFunctions; func++) {
				  errorOutput[ 2 + sLen++ ] = '!';
				  errorOutput[ 2 + sLen++ ] = (uchar)constantsData[0];
				  errorOutput[ 2 + sLen++ ] = (uchar)func;
				  int innerStart = constantsPrimaryIndex[ func * 2    ];
				  int innerLen   = constantsPrimaryIndex[ func * 2 + 1];
				  errorOutput[ 2 + sLen++ ] = (uchar)innerStart;
				  errorOutput[ 2 + sLen++ ] = (uchar)innerLen;
				  errorOutput[ 2 + sLen++ ] = '!';
				  for(int c = innerStart; c < innerStart + innerLen; c++) {
				    int byteStart = constantsSecondaryIndex[ c * 2    ];
				    int bytes     = constantsSecondaryIndex[ c * 2 + 1];
				    for( int b = byteStart; b < byteStart + bytes; b++) {
				      errorOutput[ 2 + sLen++ ] = (uchar)constantsData[b];
				    }
				    errorOutput[ 2 + sLen++ ] = ',';
				  } 
			      errorOutput[ 2 + sLen++ ] = '|';
				}
				
				errorOutput[0] = (uchar) ((sLen >> 8) & 0xFF);
				errorOutput[1] = (uchar) ( sLen       & 0xFF);
			}		
			""";
		CLProgram program = context.createProgram(srcCode).build();
		
		LuaKernelArgs kernelArgs = new LuaKernelArgs(context);
		var queue = context.createDefaultOutOfOrderQueue();
		ArrayList<CLEvent> events = new ArrayList<>();
		
//		events.add(    kernelArgs.setWorkSize(queue, 1) 			);
		events.add(    kernelArgs.setMaxExecution(queue, 100) 		);
		events.addAll( kernelArgs.setStackSizes(queue, 10, 10, 256, new int[] {1}) );
		events.addAll( kernelArgs.loadBytecode(LuaSrcUtil.readBytecode("print.out"), queue) );
		
		var kernel = program.createKernel("exec");
		kernelArgs.applyArgs(kernel);
		
		var eventsArray = events.toArray(new CLEvent[events.size()]);
		
		var event = kernel.enqueueNDRange(queue, new int[] {1}, eventsArray);
		
		var data = kernelArgs.errorBuffer.readStrData(queue, event);
		
		//flat for debug
		var flat = LuaSrcUtil.parseBytecode(LuaSrcUtil.readBytecode("print.out"));
		
		System.out.println( context.getDevices()[0].getName() );
		System.out.println( context.getDevices()[0].getVersion() );
		System.out.println( Arrays.toString( flat.constants.get(0).get(0) ) );
		System.out.println( new String( data.getBytes()) );
		System.out.println( Arrays.toString( data.getBytes()) );
	}
	
}
