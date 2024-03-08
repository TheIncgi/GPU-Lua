package gplua;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;

import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.CLProgram;
import com.nativelibs4java.opencl.JavaCL;
import com.nativelibs4java.opencl.CLMem.Usage;
import com.theincgi.gplua.cl.IntArray1D;
import com.theincgi.gplua.cl.LuaKernelArgs;
import com.theincgi.gplua.cl.LuaSrcUtil;

public class CLBytecodeChecking {
	
	public static void main(String[] args) throws FileNotFoundException, IOException {
		CLContext context = JavaCL.createBestContext();
//		
//		var srcURL = CLBytecodeChecking.class.getResource("luavm.cl");
//		var file = srcURL.getFile();
		
		var srcCode = """
			#include"example.cl"
			
			__kernel void exec(
			    __global int* output    
			) {
				if( get_global_id(0) != 0 )
					return;
				
				output[0] = exampleValue;
				
			}		
			""";
		CLProgram program = context.createProgram(srcCode);
		program.addInclude( System.getProperty("user.dir")+"/cl" );
		program.build();
		
		IntArray1D output = new IntArray1D(context, Usage.Output);
		var queue = context.createDefaultOutOfOrderQueue();
		var event = output.fillEmpty(1, queue);
		
		var kernel = program.createKernel("exec");
		kernel.setArgs(output.arg());
		
		event = kernel.enqueueNDRange(queue, new int[] {1}, event);
		
		var data = output.readData(queue, event);
		
		//flat for debug
		
		
		System.out.println( context.getDevices()[0].getName() );
		System.out.println( context.getDevices()[0].getVersion() );
		
		System.out.println( Arrays.toString( data ) );
	}
	
}
