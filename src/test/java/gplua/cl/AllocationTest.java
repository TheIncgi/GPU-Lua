package gplua.cl;

import static org.junit.jupiter.api.Assertions.*;

import java.awt.image.Kernel;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.CLKernel;
import com.nativelibs4java.opencl.CLProgram;
import com.nativelibs4java.opencl.CLQueue;
import com.nativelibs4java.opencl.JavaCL;
import com.nativelibs4java.opencl.CLMem.Usage;
import com.theincgi.gplua.cl.ByteArray1D;
import com.theincgi.gplua.cl.IntArray1D;
import com.theincgi.gplua.cl.LuaKernelArgs;

public class AllocationTest {
	
	public static final String header = 
	"""
	#include"heapUtils.h"
	
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
	
	static CLProgram program;
	static CLQueue queue;
	static CLContext context;
	static CLKernel kernel;
	
	static ByteArray1D heap, errOut;
	static IntArray1D stackSizes;
	
	
	@BeforeAll
	static void setup() {
		context = JavaCL.createBestContext();
		queue = context.createDefaultOutOfOrderQueue();
		heap = new ByteArray1D(context, Usage.InputOutput);
		errOut = new ByteArray1D(context, Usage.InputOutput);
		stackSizes = new IntArray1D(context, Usage.Input);
	}
	
	public void setupProgram( String src ) {
		program = context.createProgram(header + src + footer);
//		program.addInclude(System.getProperty("user.dir")+"/src/main/resources/com/theincgi/gplua");
		program.addInclude("src/main/resources/com/theincgi/gplua");
		program = program.build();
		kernel = program.createKernel("exec");
		kernel.setArgs(stackSizes.arg(), heap.arg(), errOut.arg());
	}
	
	public List<CLEvent> setBufferSizes( int heap, int err ) {
		var eList = new ArrayList<CLEvent>();
		eList.add(this.heap.fillEmpty(heap, queue));
		eList.add(this.errOut.fillEmpty(err, queue));
		eList.add(stackSizes.loadData(new int[] {heap, err}, queue));
		return eList;
	}
	
	@Test
	void heapInit() {
		var events = setBufferSizes( 24, 512 );
		setupProgram("""
		initHeap( heap, maxHeapSize );
		""");
		
		var done = kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
		
		var data = heap.readData(queue, done);
		
		System.out.println(Arrays.toString(data));
		
	}
	
}
