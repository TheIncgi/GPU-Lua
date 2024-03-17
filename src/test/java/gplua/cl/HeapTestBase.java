package gplua.cl;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.JavaCL;
import com.nativelibs4java.opencl.CLMem.Usage;
import com.theincgi.gplua.cl.ByteArray1D;
import com.theincgi.gplua.cl.IntArray1D;

import gplua.HeapVisualizer;

public class HeapTestBase extends TestCommons {
	
	
	ByteArray1D heap, errOut;
	IntArray1D stackSizes;
	private Integer heapDebugStart = null;
	
	
	
	void setup() {
		System.out.println("\n==========SETUP==========");
		context = JavaCL.createBestContext();
		queue = context.createDefaultOutOfOrderQueue();
		heap = new ByteArray1D(context, Usage.InputOutput);
		errOut = new ByteArray1D(context, Usage.InputOutput);
		stackSizes = new IntArray1D(context, Usage.Input);
	}
	
	public List<CLEvent> setupProgram( String src, int heapSize, int errSize ) {
		program = context.createProgram( src );
//		program.addInclude(System.getProperty("user.dir")+"/src/main/resources/com/theincgi/gplua");
		program.addInclude("src/main/resources/com/theincgi/gplua");
		program = program.build();
		kernel = program.createKernel("exec");
		var events = setBufferSizes(heapSize, errSize);
		kernel.setArgs(stackSizes.arg(), heap.arg(), errOut.arg());
		return events;
	}
	
	/**heap size reported to the kernel will be heapDebugPos*/
	public List<CLEvent> setupProgram( String src, int heapSize, int errSize, int debugHeapSize ) {
		program = context.createProgram( src );
//		program.addInclude(System.getProperty("user.dir")+"/src/main/resources/com/theincgi/gplua");
		program.addInclude("src/main/resources/com/theincgi/gplua");
		enableHeapDebugging(heapSize);
		program = program.build();
		kernel = program.createKernel("exec");
		var events = setBufferSizes(heapSize + debugHeapSize, errSize);
		kernel.setArgs(stackSizes.arg(), heap.arg(), errOut.arg());
		return events;
	}
	
	private List<CLEvent> setBufferSizes( int heap, int err ) {
		var eList = new ArrayList<CLEvent>();
		this.heap.noData(heap);
		eList.add(errOut.fillEmpty(err, queue));
		eList.add(stackSizes.loadData(new int[] {
			heapDebugStart == null? heap : heapDebugStart, 
			err
		}, queue));
		return eList;
	}
	
	/**
	 * Choose a number outside the range of the heap that will be used
	 * */
	private void enableHeapDebugging( int startHeapRecordAt ) {
		this.heapDebugStart  = startHeapRecordAt;
		program.defineMacro("DEBUG_ALLOCATION", "true");
		program.defineMacro("DEBUG_ALLOCATION_START", ""+startHeapRecordAt);
	}
	
	/**Call enableHeapDebugging before running
	 * @param data 
	 * @return 
	 * @throws IOException */
	public HeapVisualizer visualizeHeapRecord(byte[] data) throws IOException {
		Objects.requireNonNull(heapDebugStart);
		var hv = new HeapVisualizer(data, heapDebugStart + 4);
		hv.show();
		return hv;
	}
	
	
	
}
