package gplua.cl;

import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLKernel;
import com.nativelibs4java.opencl.CLProgram;
import com.nativelibs4java.opencl.CLQueue;
import com.theincgi.gplua.cl.HeapUtils;

public abstract class TestCommons extends HeapUtils {
	public CLProgram program;
	public CLQueue queue;
	public CLContext context;
	public CLKernel kernel;
	
	
	
	abstract void setup();
	
	
}
