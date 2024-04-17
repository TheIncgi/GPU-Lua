package gplua.cl;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
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
			
//			dumpHeap(heap);
			
			assertEquals(2, results.length, "expected 2 return values");
			assertEquals(LuaTypes.CLOSURE, results[0].type(), "return 1 value is not a closure");
			assertEquals(LuaTypes.INT, results[1].type(), "return 2 is not an int");
			
			var closure = results[0];
			var expectedInt = results[1];
			
			assertEquals(1, closure.closureFunction());
			
			var upvalArray = getChunkData(heap, closure.closureUpvalArray());
			assertEquals(1, upvalArray.arraySize(), "expected 1 upval for foo()");
			
			var upval = getChunkData(heap, upvalArray.arrayRef(0) );
			assertEquals(LuaTypes.UPVAL, upval.type(), "upval has unexpected type");
			
			var stack = getChunkData(heap, upval.upvalStack());
			assertEquals(LuaTypes.LUA_STACK, stack.type(), "stack has unexpected type");
			
			var regVal = getChunkData(heap, stack.lsGetRegister( upval.upvalRegister() ));
			assertEquals(expectedInt.allocationIndex(), regVal.allocationIndex());
	}
	
	@Test
	public void nonStackClosure() throws IOException, InterruptedException { 
		var events = setupProgram("""
			local u,v = 99, 105
			function p() 
				u=1
				local function q()
					return v 
				end 
				return q
			end
			
			local foo = p()
			return foo, v, p
			""", 6000);
		var results = runAndReturn(events);
		
//		dumpHeap(heap);
		
		assertEquals(3, results.length, "expected 3 return values");
		assertEquals(LuaTypes.CLOSURE, results[0].type(), "return 1 value is not a closure");
		assertEquals(LuaTypes.INT, results[1].type(), "return 2 is not an int");
		
		var closureFoo = results[0];
		var expectedInt = results[1];
		var closureP = results[2];
		
		assertEquals(1, closureP.closureFunction());
		assertEquals(2, closureFoo.closureFunction());
		
		var upvalArray = getChunkData(heap, closureFoo.closureUpvalArray());
		assertEquals(1, upvalArray.arraySize(), "expected 1 upval for foo()");
		
		var upval = getChunkData(heap, upvalArray.arrayRef(0) );
		assertEquals(LuaTypes.UPVAL, upval.type(), "upval has unexpected type");
		
		var stack = getChunkData(heap, upval.upvalStack());
		assertEquals(LuaTypes.LUA_STACK, stack.type(), "stack has unexpected type");
		
		var regVal = getChunkData(heap, stack.lsGetRegister( upval.upvalRegister() ));
		assertEquals(expectedInt.allocationIndex(), regVal.allocationIndex());
	}
	
	@Test
	public void setList() throws IOException, InterruptedException { 
		var events = setupProgram("""
			return {4,5,6}
			""", 6000);
		var results = runAndReturn(events);
		
//		dumpHeap(heap);
		
		assertEquals(1, results.length, "expected 1 return values");
		
		var table = results[0];
		
		assertEquals(LuaTypes.TABLE, table.type());
		var arrayPart = getChunkData(heap, table.tableArrayPart());
		assertEquals(3, arrayPart.arraySize(), "wrong array size");
		
		for(int i = 0; i<arrayPart.arraySize(); i++)
			assertEquals(4 + i, getChunkData(heap, arrayPart.arrayRef(i)).intValue());
	}
	
	@Test
	public void loadBool() throws IOException, InterruptedException { 
		var events = setupProgram("""
			return false, true
			""", 6000);
		var results = runAndReturn(events);
		
//		dumpHeap(heap);
		
		assertEquals(2, results.length, "expected 2 return values");
		
		assertFalse(results[0].boolValue());
		assertTrue(results[1].boolValue());
	}
	
	@Test
	public void loadNil() throws IOException, InterruptedException { 
		var events = setupProgram("""
			local x = 10
			x = nil
			return x
			""", 6000);
		var results = runAndReturn(events);
		
//		dumpHeap(heap);
		
		assertEquals(1, results.length, "expected 1 return values");
		assertEquals(LuaTypes.NIL, results[0].type());
	}

	@Test
	public void forLoop() throws IOException, InterruptedException { 
		var events = setupProgram("""
			i = 0
			for _ = 1, 4 do
				i = i + 1
			end
			return i
			""", 6000);
		var results = runAndReturn(events);
		
//		dumpHeap(heap);
		
		var val = results[0];
		assertEquals(LuaTypes.INT, val.type());
		assertEquals(4, val.intValue());
	}
	
	@Test
	public void stringLength() throws IOException, InterruptedException { 
		var events = setupProgram("""
			local str = "hello"
			return #str
			""", 6000);
		var results = runAndReturn(events);
		
//		dumpHeap(heap);
		
		var val = results[0];
		assertEquals(LuaTypes.INT, val.type());
		assertEquals(5, val.intValue());
	}
	
	@Test
	public void tableLength() throws IOException, InterruptedException { 
		var events = setupProgram("""
			local t = {}
			local a = #t
			
			t[1] = true
			local b = #t
			
			t[5] = true
			local c = #t
			
			return t, a, b, c
			""", 6000);
		var results = runAndReturn(events);
		
//		dumpHeap(heap);
		
		var table = results[0];
//		System.out.println("T: " + table.allocationIndex());
		
		var valA = results[1];
		assertEquals(LuaTypes.INT, valA.type());
		assertEquals(0, valA.intValue(), "empty should have len 0");
		
		var valB = results[2];
		assertEquals(LuaTypes.INT, valB.type());
		assertEquals(1, valB.intValue(), "element at index 1 should be len 1");
		
		var valC = results[3];
		assertEquals(LuaTypes.INT, valC.type());
		assertEquals(1, valC.intValue(), "hashed index should not change len");
	}
	
	@Test
	public void truthy() throws IOException, InterruptedException { 
		var events = setupProgram("""
			local a,b,c,d,e,f,g = false, false, false, false, false, false, false
			
			-- case 1
			if false then
			  a = true
			end
			
			-- case 2
			if true then
			  b = true
			end
			
			-- case 3
			if nil then
			  c = true
			end
			
			-- case 4
			if 0 then
			  d = true
			end
			
			-- case 5
			if {} then
			  e = true
			end
			
			-- case 6
			if "" then
			  f = true
			end
			
			-- case 7
			if math.log then
			  g = true
			end
			
			return a,b,c,d,e,f,g
			""", 6000);
		var results = runAndReturn(events);
		
//		dumpHeap(heap);
		
		boolean[] expected = new boolean[] {false, true, false, true, true, true, true};
		
		for(int i = 0; i<expected.length; i++) {
			var val = results[i];
			assertEquals(LuaTypes.BOOL, val.type());
			assertEquals(expected[i], val.boolValue(), "case %d expected %s".formatted(i+1, expected[i]));			
		}
	}

	@Test
	public void varargs() throws IOException, InterruptedException { 
		var events = setupProgram("""
			function foo( a, ... )
			  local b, c, d = ...
			  return c, d
			end
			
			function bar( a, ... )
			  return ...
			end
			
			local x, y, z = foo( 1, 2, 3, 4, 5, 6, 7 )
			local t, u, v = bar( 1, 2, 3, 4, 5, 6, 7 )
			
			return x,y,z, t,u,v
			""", 6000);
		var results = runAndReturn(events);
		
		dumpHeap(heap);
		
		Integer[] expected = new Integer[] { 2, 3, null, 2, 3, 4 };
		
		for(int i = 0; i < expected.length; i++) {
			var val = results[i];
			if( expected[i] == null ) {
				assertEquals(LuaTypes.NIL, val.type());
			} else {
				assertEquals(LuaTypes.INT, val.type());				
				assertEquals(expected[i], val.intValue());
			}
		}
		
		
	}
}
