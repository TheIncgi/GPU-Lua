package gplua.cl;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.CLKernel;
import com.nativelibs4java.opencl.CLProgram;
import com.nativelibs4java.opencl.CLQueue;
import com.nativelibs4java.opencl.JavaCL;
import com.nativelibs4java.opencl.CLMem.Usage;
import com.theincgi.gplua.cl.ByteArray1D;
import com.theincgi.gplua.cl.IntArray1D;

public class TestBase {
	CLProgram program;
	CLQueue queue;
	CLContext context;
	CLKernel kernel;
	
	ByteArray1D heap, errOut;
	IntArray1D stackSizes;
	
	public static final int USE_FLAG  = 0x80000000,
							MARK_FLAG = 0x40000000,
							SIZE_MASK = 0x3FFFFFFF;
	
	void setup() {
		System.out.println("\n==========SETUP==========");
		context = JavaCL.createBestContext();
		queue = context.createDefaultOutOfOrderQueue();
		heap = new ByteArray1D(context, Usage.InputOutput);
		errOut = new ByteArray1D(context, Usage.InputOutput);
		stackSizes = new IntArray1D(context, Usage.Input);
	}
	
	public void setupProgram( String src ) {
		program = context.createProgram( src );
//		program.addInclude(System.getProperty("user.dir")+"/src/main/resources/com/theincgi/gplua");
		program.addInclude("src/main/resources/com/theincgi/gplua");
		program = program.build();
		kernel = program.createKernel("exec");
		kernel.setArgs(stackSizes.arg(), heap.arg(), errOut.arg());
	}
	
	public List<CLEvent> setBufferSizes( int heap, int err ) {
		var eList = new ArrayList<CLEvent>();
		eList.add(this.heap.fillEmpty(heap, queue));
		eList.add(errOut.fillEmpty(err, queue));
		eList.add(stackSizes.loadData(new int[] {heap, err}, queue));
		return eList;
	}
	
	boolean isUseFlag( int tag ) {
		return (tag & USE_FLAG) != 0;
	}
	
	boolean isMarkFlag( int tag ) {
		return (tag & MARK_FLAG) != 0;
	}
	
	int chunkSize( int tag ) {
		return (tag & SIZE_MASK);
	}
	
	int readIntAt(byte[] data, int offset) throws IOException {
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(data));
		dis.skip(offset);
		return dis.readInt();
	}
	
	TaggedMemory getChunkData( byte[] heap, int allocationIndex ) throws IOException {
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(heap));
		int tagPos = allocationIndex - 4;
		dis.skip(tagPos);
		int tag = dis.readInt();
		int size = chunkSize( tag );
		var data = dis.readNBytes(size - 4);
		return new TaggedMemory(isUseFlag(tag), isMarkFlag(tag), data);
	}
	
	record TaggedMemory(boolean inUse, boolean marked, byte[] data) {}
}
