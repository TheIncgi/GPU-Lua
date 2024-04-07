package gplua.cl;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.lang.StackWalker.StackFrame;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;

import com.nativelibs4java.opencl.JavaCL;
import com.nativelibs4java.opencl.CLEvent;
import com.theincgi.gplua.cl.LuaKernelArgs;
import com.theincgi.gplua.cl.LuaSrcUtil;

public class KernelTestBase extends TestCommons {
	
	LuaKernelArgs args;
	int[] workSize = new int[] {1};
	
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
	
	public List<CLEvent> setupProgram( String src, String luaFileName, int heapSize ) throws IOException, InterruptedException {
		return setupProgram(src, getSrc(luaFileName), heapSize);
	}
	
	public List<CLEvent> setupProgram( String src, byte[] byteCode, int heapSize ) throws IOException {
		program = context.createProgram( src );
		program.addInclude("src/main/resources/com/theincgi/gplua");
		program.build();
		kernel = program.createKernel("exec");
		
		var events = args.loadBytecode(byteCode, queue);
		events.add(args.heap.fillEmpty(heapSize, queue));
//		events.add(args.luaStack.fillEmpty(stackSize, queue));
		events.addAll(args.setStackSizes(queue, heapSize, workSize));
		events.add(args.setMaxExecution(queue, 30_000));
		events.add(args.returnInfo.fillEmpty(2, queue));
		
		args.applyArgs(kernel);
		
		return events;
	}
	
	public CLEvent run(List<CLEvent> events) {
		return kernel.enqueueNDRange(queue, new int[] {1}, events.toArray(new CLEvent[events.size()]));
	}
	
//	public LinkedList<StackFrame> readStackFrames( int[] stack ) {
//		var frames = new LinkedList<StackFrame>();
//		var frameStart = stack[0]; //start of top frame
//		
//		//itterate from top of stack going down
//		while(frameStart > 0) {
//			var frame = new StackFrame(stack, frameStart);
//			frames.addFirst(frame);
//			
//			if(frame.returnBase != null) {
//				frameStart = frame.returnBase;
//			} else {
//				break;
//			}
//		}
//		return frames;
//	}
	
//	public void printFrames(LinkedList<StackFrame> frames) {
//		System.out.println("======= STACK =======");
//		for(var it = frames.descendingIterator(); it.hasNext();) {
//			var frame = it.next();
//			System.out.println( frame );
//		}
//	}
//	
//	public static class StackFrame {
//		
//		Integer returnPC;
//		Integer returnBase;
//		
//		int top;
//		int firstFixedRegister;
//		int function;
//		int closure;
//		int[] varargs;
//		int[] registers;
//		public boolean isFirst;
//		public int base;
//		
//		public StackFrame( int[] stack, int frameBase ) {
//			isFirst = frameBase == 1;
//			this.base = frameBase;
//			top = stack[ frameBase ]; //first empty register of this frame or stack pop values
//			firstFixedRegister = stack[ frameBase + 1 ];
//			function = stack[ frameBase + 2 ];
//			closure = stack[ frameBase + 3 ];
//			
//			int nvarargs = firstFixedRegister - frameBase - 4;
//			int nregisters = top - firstFixedRegister;
//			
//			
//			varargs = new int[ nvarargs ];
//			registers = new int[ nregisters ];
//			
//			int i = frameBase + 4;
//			for(int j = 0; i < firstFixedRegister; j++, i++) {
//				varargs[j] = stack[i];
//			}
//			
//			for(int j = 0; i < top; i++, j++) {
//				registers[j] = stack[i];
//			}
//			
//			if(!isFirst) {
//				returnPC   = stack[ frameBase - 2 ];
//				returnBase = stack[ frameBase - 1 ];
//			}
//		}
//		
//		@Override
//		public String toString() {
//			var out = "";
//			if(!isFirst)
//				out = """
//				|- old base: %d
//				|- old PC:   %d
//				------	
//				""".formatted(returnBase, returnPC);
//			
//			out += "FRAME @ " + base+"\n";
//			
//			out += "|Registers: ("+registers.length+")\n";
//			for(int i = registers.length-1; i >= 0; i--) {
//				out += "| %3d | %d\n".formatted(i, registers[i]);
//			}
//			
//			out += "|Varargs: ("+varargs.length+")\n";
//			for(int i = varargs.length-1; i >= 0; i--) {
//				out += "| %3d | %d\n".formatted(i, varargs[i]);
//			}
//			
//			out += """
//			|Closure href: %d
//			|Function: %d
//			""".formatted(closure, function);
//			
//			return out;
//		}
//	}
	
}
