package gplua.cl;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.file.Files;
import java.util.List;

import com.nativelibs4java.opencl.JavaCL;
import com.nativelibs4java.opencl.CLEvent;
import com.theincgi.gplua.cl.LuaKernelArgs;
import com.theincgi.gplua.cl.LuaSrcUtil;

public class KernelTestBase extends TestCommons {
	
	LuaKernelArgs args;
	
	@Override
	void setup() {
		System.out.println("\n==========SETUP==========");
		context = JavaCL.createBestContext();
		queue = context.createDefaultOutOfOrderQueue();
		
		args = new LuaKernelArgs(context);
	}
	
	public byte[] getSrc(String fileName) throws IOException, InterruptedException {
		var src = KernelTestBase.class.getResource(fileName+".lua");
		var compiled = new File(fileName+"out");
		var srcFile = new File(src.getFile());
		if(!compiled.exists() || LuaSrcUtil.isUpdated(srcFile, compiled)) {
			LuaSrcUtil.compile(Files.readString(srcFile.toPath()), fileName + ".out");
		}
		return LuaSrcUtil.readBytecode(compiled.getPath());
	}
	
	public List<CLEvent> setupProgram( String src, String luaFileName, int heapSize, int stackSize, int errSize ) throws IOException, InterruptedException {
		return setupProgram(src, getSrc(luaFileName), heapSize, stackSize, errSize);
	}
	
	public List<CLEvent> setupProgram( String src, byte[] byteCode, int heapSize, int stackSize, int errSize ) throws IOException {
		program = context.createProgram( src );
		program.addInclude("src/main/resources/com/theincgi/gplua");
		program.build();
		kernel = program.createKernel("exec");
		
		var events = args.loadBytecode(byteCode, queue);
		events.add(args.heap.fillEmpty(heapSize, queue));
		events.add(args.luaStack.fillEmpty(stackSize, queue));
		events.add(args.errorBuffer.fillEmpty(errSize, queue));
		
		return events;
	}
}
