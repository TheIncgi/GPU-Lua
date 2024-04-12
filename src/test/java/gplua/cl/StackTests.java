package gplua.cl;

import static org.junit.Assert.assertTrue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.file.Files;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.nativelibs4java.opencl.CLEvent;
import com.theincgi.gplua.cl.LuaSrcUtil;
import com.theincgi.gplua.cl.LuaTypes;

public class StackTests extends KernelTestBase {
	
	public static final String header = 
			"""
			#include"heapUtils.h"
			#include"table.h"
			#include"strings.h"
			#include"globals.cl"
			#include"vm.h"
//			#include"stackUtils.h"
			#include"closure.h"
			#include"luaStack.h"
			#include"comparison.h"
			#include"upval.h"
			
			#include"table.cl"
			#include"array.cl"
			#include"hashmap.cl"
			#include"heapUtils.cl"
			#include"strings.cl"
			#include"vm.cl"
//			#include"stackUtils.cl"
			#include"closure.cl"
			#include"luaStack.cl"
			#include"comparison.cl"
			#include"upval.cl"
			
			__kernel void exec(
			    __global const  uint* heapSize,
			    __global const  long* maxExecutionTime,
			    __global       uchar* heap,
			    
			    /*Byte code pieces*/
			    __global unsigned int* numFunctions,
			    __global unsigned int* linesDefined,
			    __global unsigned int* lastLinesDefined,
			    __global        uchar* numParams,
			    __global         bool* isVararg, //could be true or passed number of args & set that way
			    __global        uchar* maxStackSizes, //from bytecode, poor name planning, oops, different than stackSizes[0]
			
			    //code
			    __global          uint* codeIndexes,
			    __global          uint* code, //[function #][instruction] = code[ codeIndexes[function] + instruction ]
			    
			    //constants
			    __global            int* constantsPrimaryIndex,
			    __global            int* constantsSecondaryIndex,
			    __global          uchar* constantsData, //[function #][byte] - single byte type, followed by value, strings are null terminated
			    __global            int* protoLengths,
			    
			    //upvals
			    __global           int* upvalsIndex,
			    __global         uchar* upvals,
			    __global           int* returnInfo
			) {
			    //int dimensions = get_work_dim();
				
				if( get_global_id(0) != 0 )
					return;
				
				struct WorkerEnv env;
				
				env.maxStackSizes           = maxStackSizes;

				env.heap                    = heap;
				env.maxHeapSize             = heapSize[0];
				
				env.codeIndexes             = codeIndexes;
				env.code                    = code;
				env.numParams               = numParams;
				env.isVararg                = isVararg;
				
				env.constantsPrimaryIndex   = constantsPrimaryIndex;
				env.constantsSecondaryIndex = constantsSecondaryIndex;
				env.constantsData           = constantsData;
				
				initHeap( heap, env.maxHeapSize );
				
				href stringTable = newTable( heap, env.maxHeapSize );
				env.stringTable             = stringTable;
				
				href globals     = createGlobals( &env );
				env.globals                 = globals;
				
				env.func = 0;
				env.pc = 0;
				env.returnFlag = false;
				
				href mainClosure = createClosure( &env, 0, env.globals, 1 ); //function 0, 1 upval(_ENV)
				setClosureUpval( &env, mainClosure, 0, env.globals );	
			""";
	public static final String footer = "\n}";
	
	@BeforeEach
	void setup() {
		super.setup();
	}
	
	@Override
	public List<CLEvent> setupProgram(String src, byte[] byteCode, int heapSize)
			throws IOException {
		return super.setupProgram(header + src + footer, byteCode, heapSize );
	}
	
//	@Override
//	public List<CLEvent> setupProgram( String src, int heapSize, int logSize ) {
//		return super.setupProgram(header + src + footer, heapSize, logSize);
//	}
//	
//	@Override
//	public List<CLEvent> setupProgram( String src, int heapSize, int logSize, int debugHeapSize ) {
//		return super.setupProgram(header + src + footer, heapSize, logSize, debugHeapSize);
//	}
	
	@Test
	void initStack() throws FileNotFoundException, IOException {
		var events = setupProgram("""
		uint func = 1;
		uint closure = 2;
		uint varargs = 3;
		
		href stack = allocateLuaStack( &env, 0, 0, mainClosure, varargs );
		returnInfo[0] = stack;
		""", 
		LuaSrcUtil.readBytecode("print.out"),
		6192 //heap
		);
		
		var done = run(events);
		var heap  = args.heap.readData(queue, done);
		var returnInfo = args.returnInfo.readData(queue);
		
		var stack = getChunkData(heap, returnInfo[0]);
		System.out.println( stack );
		
		assertEquals(0, stack.lsGetPriorStack());
		assertEquals(0, stack.lsGetPriorPC());
		assertEquals(3, stack.lsNVarargs());
		
	}
	
	@Test
	void pushStack() throws FileNotFoundException, IOException {
		var events = setupProgram("""
		
		href stack = allocateLuaStack( &env, 0, 0, mainClosure, 3 );
		href pushed = allocateLuaStack( &env, stack, 99, mainClosure, 4 );
		
		//usually returnInfo is {start, length} for a list of registers
		//using it differently for easy testing
		returnInfo[0] = stack;
		returnInfo[1] = pushed;
		""", 
		LuaSrcUtil.readBytecode("print.out"),
		6152 //heap
		);
		
		var done  = run(events);
		var heap  = args.heap.readData(queue, done);
		var returnInfo = args.returnInfo.readData(queue);
		
		var top = getChunkData(heap, returnInfo[1]);
		var first = getChunkData(heap, returnInfo[0]);
		
		
		assertEquals(4, top.lsNVarargs());
		assertEquals(0, top.lsNRegisters());
		assertEquals(99, top.lsGetPriorPC());
		assertEquals(returnInfo[0], top.lsGetPriorStack());
		
		assertEquals(3, first.lsNVarargs() );
		assertEquals(0, first.lsNRegisters() );
	}
	
	@Test
	void setVararg() throws FileNotFoundException, IOException {
		var events = setupProgram("""
		href stack = allocateLuaStack( &env, 0, 0, mainClosure, 3 );
		
		ls_setVararg( &env, stack, 0, 97 );
		ls_setVararg( &env, stack, 1, 98 );
		ls_setVararg( &env, stack, 2, 99 );
		
		returnInfo[0] = stack;
		""", 
		LuaSrcUtil.readBytecode("print.out"),
		6142 //heap
		);
		
		var done  = run(events);
		var heap  = args.heap.readData(queue, done);
		var returnInfo = args.returnInfo.readData(queue);
		
		var stack = getChunkData(heap, returnInfo[0]);

		System.out.println(stack);
		
		assertEquals(97, stack.lsGetVararg(0));
		assertEquals(98, stack.lsGetVararg(1));
		assertEquals(99, stack.lsGetVararg(2));
	}
	
	@Test
	void setRegister() throws FileNotFoundException, IOException, InterruptedException {
		var events = setupProgram("""
		href stack = allocateLuaStack( &env, 0, 0, mainClosure, 3 );
		
		ls_setRegister( &env, stack, 3, 105 );
		returnInfo[0] = stack;
		""", 
		LuaSrcUtil.compile("local a, b, c, d = 1,2,3,4 return a,b,c,d"),
		6172 //heap
		);
		
		var done  = run(events);
		var heap  = args.heap.readData(queue, done);
		var returnInfo = args.returnInfo.readData(queue);
		
		var stack = getChunkData(heap, returnInfo[0]);

		System.out.println(stack);
		
		assertEquals(4,   stack.lsNRegisters());
		assertEquals(0,   stack.lsGetRegister(0));
		assertEquals(0,   stack.lsGetRegister(1));
		assertEquals(0,   stack.lsGetRegister(2));
		assertEquals(105,   stack.lsGetRegister(3));
	}
	
	@Test
	void loadK() throws FileNotFoundException, IOException {
		var events = setupProgram("""
		href stack = allocateLuaStack( &env, 0, 0, mainClosure, 3 );
		env.luaStack = stack;
		
		bool ok = loadk( &env, 1, 0 ); //reg 1, const 0
		returnInfo[ 0 ] = stack;
		""", 
		LuaSrcUtil.readBytecode("print.out"), //print"hello"
		5112 //heap
		);
		
		var done  = run(events);
		var heap  = args.heap.readData(queue, done);
		var returnInfo = args.returnInfo.readData(queue);
		
		var stack = getChunkData(heap, returnInfo[0]);

		System.out.println(stack);
		
//		printFrames( frames );
//		dumpHeap(heap);
		
		var regHref = stack.lsGetRegister(1);
		assertNotEquals(0, regHref);
		
		var value = getChunkData(heap, regHref);
		assertEquals("print", value.stringValue());
	}
	
	@Test
	void getTabUp() throws FileNotFoundException, IOException {
		var events = setupProgram("""		
		href stack = allocateLuaStack( &env, 0, 0, mainClosure, 3 );
		env.luaStack = stack;
		
		getTabUp( &env, 1, 0, 0 | 0x100 );
		returnInfo[ 0 ] = stack;
		""", 
		LuaSrcUtil.readBytecode("returnMath.out"), //return math
		6222 //heap
		);
		
		var done  = run(events);
		var heap  = args.heap.readData(queue, done);
		var returnInfo = args.returnInfo.readData(queue);
		
		var stack = getChunkData(heap, returnInfo[0]);

		System.out.println(stack);
		
		dumpHeap(heap);
		
		
		var regHref = stack.lsGetRegister(1);
		var heapValue = getChunkData(heap, regHref);
		
		assertEquals( LuaTypes.TABLE, heapValue.type() );
	}
	
	@Test
	void readInstruction() throws FileNotFoundException, IOException {
		var events = setupProgram("""		
		
		LuaInstruction inst = env.code[ env.codeIndexes[ env.func ] + env.pc ];
		
		href arr = newArray( env.heap, env.maxHeapSize, 5 );
		returnInfo[0] = arr; 
		
		arraySet( env.heap, arr, 0,            inst );
		arraySet( env.heap, arr, 1, getOpcode( inst ) );
		arraySet( env.heap, arr, 2, getA(      inst ) );
		arraySet( env.heap, arr, 3, getB(      inst ) );
		arraySet( env.heap, arr, 4, getC(      inst ) );
		""", 
		LuaSrcUtil.readBytecode("math.log.out"), //return math.log( 10 )
		6000 //heap
		);
		
		var done  = run(events);
		var heap  = args.heap.readData(queue, done);
		var returnInfo = args.returnInfo.readData(queue);
		
		var arr = getChunkData(heap, returnInfo[0]);
		
		int inst    = arr.arrayRef(0);
		int opCode  = arr.arrayRef(1);
		int a       = arr.arrayRef(2);
		int b       = arr.arrayRef(3);
		int c       = arr.arrayRef(4);
				
		assertEquals(     6, opCode, "opcode wrong");
		assertEquals(     0,      a, "a (target register)");
		assertEquals(     0,      b, "b (table upval index (_ENV)) ");
		assertEquals( 0x100,      c, "c (key, const or reg) ");
		
		
	}
	
	@Test
	void nativeCall() throws FileNotFoundException, IOException {
		var events = setupProgram("""		
//		href stack = allocateLuaStack( &env, 0, 0, mainClosure, 3 );
//		env.luaStack = stack;
		
		printf("CALL\\n");
		bool ok = call( &env, mainClosure );
		printf("POST_CALL\\n");
		
		//propper usage, from luavm.cl
		if( ok && env.returnFlag ) {
			printf("RETURN\\n");
	        returnInfo[ 0 ] = 0; //no err
	        returnInfo[ 1 ] = env.returnStart;
	        returnInfo[ 2 ] = env.nReturn;
	    } else if( env.error ) {
			printf("ERROR\\n");
	        returnInfo[ 0 ] = env.error;
	        returnInfo[ 1 ] = 0;
	        returnInfo[ 2 ] = 0;
	    } else {
			printf("NO RETURN VALUE\\n OK: %d\\n RF: %d\\n", ok? 1 : 0, env.returnFlag ? 1 : 0 );
	        returnInfo[ 0 ] = 0;
	        returnInfo[ 1 ] = 0;
	        returnInfo[ 2 ] = 0;
	    }
		""", 
		LuaSrcUtil.readBytecode("math.log.out"), //return math.log( 10 )
		8000 //heap
		);
		
		var done  = run(events);
		var heap  = args.heap.readData(queue, done);
		var returnInfo = args.returnInfo.readData(queue);

		dumpHeap(heap);
		
		var err = getChunkData(heap, returnInfo[0]);
		assertEquals(1, returnInfo[2], err.toString() );
		
		var r1Href = readIntAt(heap, returnInfo[1]);
		var val = getChunkData(heap, r1Href);
		
		
		assertEquals(LuaTypes.NUMBER, val.type());
		assertEquals(Math.log(10), val.doubleValue(), .0000001d);	
	}
	
}
