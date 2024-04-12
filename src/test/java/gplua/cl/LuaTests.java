package gplua.cl;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.io.IOException;
import java.util.List;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.junit.jupiter.api.TestInstance.Lifecycle;

import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.JavaCL;
import com.theincgi.gplua.CLLuaException;
import com.theincgi.gplua.cl.HeapUtils;
import com.theincgi.gplua.cl.LuaKernelArgs;
import com.theincgi.gplua.cl.LuaSrcUtil;
import com.theincgi.gplua.cl.LuaTypes;

//Need to inspect the bytecode?
//check out https://www.luac.nl/

@TestInstance(Lifecycle.PER_CLASS)
public class LuaTests extends KernelTestBase {
	
	byte[] heap;
	
	@BeforeAll
	void beforeAll() throws IOException {
		try {
			System.out.println("\n==========SETUP==========");
			context = JavaCL.createBestContext();
			queue = context.createDefaultOutOfOrderQueue();
			
			program = context.createProgram( "#include\"luavm.cl\"" );
			program.addInclude("src/main/resources/com/theincgi/gplua");
			program.build();
			kernel = program.createKernel("exec");
		}catch (Exception e) {
			e.printStackTrace();
			throw e;
		}
	}
	
	
	public List<CLEvent> setupProgram(String luaSrc, int heapSize) throws IOException, InterruptedException {
		var byteCode = LuaSrcUtil.compile(luaSrc);
		
		args = new LuaKernelArgs(context);
		
		var events = args.loadBytecode(byteCode, queue);
		events.add(args.heap.fillEmpty(heapSize, queue));
		events.addAll(args.setStackSizes(queue, heapSize, workSize));
		events.add(args.setMaxExecution(queue, 30_000));
		
		args.applyArgs(kernel);
		
		return events;
	}
	
	public TaggedMemory[] runAndReturn(List<CLEvent> afterEvents) throws IOException {
		var event = run( afterEvents );
		//TODO async read
		heap = args.heap.readData(queue);
		var returnRange = args.returnInfo.readData(queue);
		
		int errHref = returnRange[0];
		int returnStart = returnRange[1];
		int nReturn = returnRange[2];
		
		if( errHref > 0 ) {
			throw new CLLuaException( getChunkData(heap, errHref) );
		}
		
		var values = new TaggedMemory[ nReturn ];
		for(int i = 0; i < values.length; i++) {
			int href = readIntAt(heap, returnStart + i * REGISTER_SIZE);
			values[i] = getChunkData(heap, href);
		}
		return values;
	}
	
	@Test
	public void add() throws IOException, InterruptedException {
		var events = setupProgram("""
		local y = 5
		return 3 + y	
		""", 6000);
		var results = runAndReturn(events);
		
		assertEquals(1, results.length);
		assertEquals(LuaTypes.INT, results[0].type());
		assertEquals(8, results[0].intValue());
	}
	
	@Test
	public void multiply() throws IOException, InterruptedException {
		var events = setupProgram("""
		local y = 5
		return 3 * y	
		""", 6000);
		var results = runAndReturn(events);
		
		assertEquals(1, results.length);
		assertEquals(LuaTypes.INT, results[0].type());
		assertEquals(15, results[0].intValue());
	}
	
	@Test
	public void subtract() throws IOException, InterruptedException {
		var events = setupProgram("""
		local y = 5
		return 3 - y	
		""", 6000);
		var results = runAndReturn(events);
		
		assertEquals(1, results.length);
		assertEquals(LuaTypes.INT, results[0].type());
		assertEquals(-2, results[0].intValue());
	}
	
	@Test
	public void divide() throws IOException, InterruptedException {
		var events = setupProgram("""
		local y = 5
		return 3 / y	
		""", 6000);
		var results = runAndReturn(events);
		
		assertEquals(1, results.length);
		assertEquals(LuaTypes.NUMBER, results[0].type());
		assertEquals(3d/5, results[0].doubleValue(), .0000001);
	}
	
	@Test
	public void pow() throws IOException, InterruptedException {
		var events = setupProgram("""
		local y = 2
		return 3 ^ y	
		""", 6000);
		var results = runAndReturn(events);
		
		assertEquals(1, results.length);
		assertEquals(LuaTypes.INT, results[0].type());
		assertEquals(9, results[0].intValue());
	}
	
	@Test
	public void mod() throws IOException, InterruptedException {
		var events = setupProgram("""
		local y = 9
		return 29 % y	
		""", 6000);
		var results = runAndReturn(events);
		
		assertEquals(1, results.length);
		assertEquals(LuaTypes.INT, results[0].type());
		assertEquals(2, results[0].intValue());
	}
	
	@Test
	public void unaryMinus() throws IOException, InterruptedException {
		var events = setupProgram("""
		local y = 9
		return -y	
		""", 6000);
		var results = runAndReturn(events);
		
		assertEquals(1, results.length);
		assertEquals(LuaTypes.INT, results[0].type());
		assertEquals(-9, results[0].intValue());
	}
	
	@Test
	public void stackOnlyClosure() throws IOException, InterruptedException { 
	var events = setupProgram("""
			local u, v = 45, 51
			function foo()
				return v
			end
			
			return foo, v
			""", 6000);
			var results = runAndReturn(events);
			
			dumpHeap(heap);
			
			assertEquals(2, results.length, "expected 2 return values");
			assertEquals(LuaTypes.CLOSURE, results[0].type(), "return 1 value is not a closure");
			assertEquals(LuaTypes.INT, results[1].type(), "return 2 is not an int");
			
			var closure = results[0];
			var expectedInt = results[1];
			
			var upvalArray = getChunkData(heap, closure.closureUpvalArray());
			assertEquals(1, upvalArray.arraySize(), "expected 1 upval for foo()");
			
			var upval = getChunkData(heap, upvalArray.arrayRef(0) );
			assertEquals(LuaTypes.UPVAL, upval.type(), "upval has unexpected type");
			
			var stack = getChunkData(heap, upval.upvalStack());
			assertEquals(LuaTypes.LUA_STACK, stack.type(), "tack has unexpected type");
			
			var regVal = getChunkData(heap, stack.lsGetRegister( upval.upvalRegister() ));
			assertEquals(expectedInt.allocationIndex(), regVal.allocationIndex());
	}
	
}
