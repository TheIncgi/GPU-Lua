package gplua.cl;

import static org.junit.Assert.assertTrue;
import static org.junit.jupiter.api.Assertions.assertEquals;

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
			#include"stackUtils.h"
			#include"closure.h"
			
			#include"table.cl"
			#include"array.cl"
			#include"hashmap.cl"
			#include"heapUtils.cl"
			#include"strings.cl"
			#include"vm.cl"
			#include"stackUtils.cl"
			#include"closure.cl"
			
			__kernel void exec(
			    __global        uint* luaStack,
			    __global const  uint* stackSizes,
			    __global        char* errorOutput,
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
			    __global         uchar* upvals
			) {
			    //int dimensions = get_work_dim();
				
				if( get_global_id(0) != 0 )
					return;
				
				struct WorkerEnv env;
				env.luaStack                = luaStack;                  //&(luaStack[ maxStackSize * glid ]);
				env.stackSize               = stackSizes[0];
				env.heap                    = heap;
				env.maxHeapSize             = stackSizes[1];
				env.error                   = errorOutput;
				env.errorSize               = stackSizes[2];
				
				env.codeIndexes             = codeIndexes;
				env.code                    = code;
				env.numParams               = numParams;
				env.isVararg                = isVararg;
				
				env.constantsPrimaryIndex   = constantsPrimaryIndex;
				env.constantsSecondaryIndex = constantsSecondaryIndex;
				env.constantsData           = constantsData;
				
				initHeap( heap, env.maxHeapSize );
				
				href stringTable = newTable(      heap, env.maxHeapSize );
				href globals     = createGlobals( heap, env.maxHeapSize, stringTable );
				
				env.stringTable             = stringTable;
				env.globals                 = globals;
				
				env.func = 0;
				env.pc = 0;
				env.returnFlag = false;
				
					
			""";
	public static final String footer = "\n}";
	
	@BeforeEach
	void setup() {
		super.setup();
	}
	
	@Override
	public List<CLEvent> setupProgram(String src, byte[] byteCode, int heapSize, int stackSize, int errSize)
			throws IOException {
		return super.setupProgram(header + src + footer, byteCode, heapSize, stackSize, errSize);
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
		initStack( env.luaStack, func, closure, varargs );
		""", 
		LuaSrcUtil.readBytecode("print.out"),
		4096, //heap
		1024, //stack
		32    //log/err
		);
		
		var done = run(events);
		var stack  = args.luaStack.readData(queue, done);
		
		int[] validation = new int[] {1, 8, 8, 1, 2};
		for(int i = 0; i < validation.length; i++) {
			assertEquals(validation[i], stack[i], "validation["+i+"] failed");
		}
	}
	
	@Test
	void pushStack() throws FileNotFoundException, IOException {
		var events = setupProgram("""
		initStack( env.luaStack, 1, 2, 3 );
		
		//pc func, closure, varargs
		pushStackFrame( env.luaStack, env.stackSize, 45, 11, 12, 4 );
		
		
		""", 
		LuaSrcUtil.readBytecode("print.out"),
		4096, //heap
		1024, //stack
		32    //log/err
		);
		
		var done  = run(events);
		var stack = args.luaStack.readData(queue, done);
		
		var frames = readStackFrames(stack);
		
//		printFrames( frames );
		
		var topFrame = frames.peekLast();
		var firstFrame = frames.peekFirst();
		
		
		assertEquals(4, topFrame.varargs.length);
		assertEquals(0, topFrame.registers.length);
		assertEquals(45, topFrame.returnPC);
		assertEquals(1, topFrame.returnBase);
		assertEquals(11, topFrame.function);
		assertEquals(12, topFrame.closure);
		
		assertEquals(3, firstFrame.varargs.length);
		assertEquals(0, firstFrame.registers.length);
		assertEquals(1, firstFrame.function);
		assertEquals(2, firstFrame.closure);
		
	}
	
	@Test
	void setVararg() throws FileNotFoundException, IOException {
		var events = setupProgram("""
		initStack( env.luaStack, 1, 2, 3 ); //3 varargs
		
		setVararg( env.luaStack, 0, 97 );
		setVararg( env.luaStack, 1, 98 );
		setVararg( env.luaStack, 2, 99 );
		""", 
		LuaSrcUtil.readBytecode("print.out"),
		4096, //heap
		1024, //stack
		32    //log/err
		);
		
		var done  = run(events);
		var stack = args.luaStack.readData(queue, done);
		
		var frames = readStackFrames(stack);
		
		printFrames( frames );
		
		var firstFrame = frames.peekFirst();
		
		assertEquals(97, firstFrame.varargs[0]);
		assertEquals(98, firstFrame.varargs[1]);
		assertEquals(99, firstFrame.varargs[2]);
	}
	
	@Test
	void setRegister() throws FileNotFoundException, IOException {
		var events = setupProgram("""
		initStack( env.luaStack, 1, 2, 3 ); //3 varargs
		
		setRegister( env.luaStack, env.stackSize, 3, 105 );
		""", 
		LuaSrcUtil.readBytecode("print.out"),
		4096, //heap
		1024, //stack
		32    //log/err
		);
		
		var done  = run(events);
		var stack = args.luaStack.readData(queue, done);
		
		var frames = readStackFrames(stack);
		
		printFrames( frames );
		
		var firstFrame = frames.peekFirst();
		
		assertEquals(4,   firstFrame.registers.length);
		assertEquals(0,   firstFrame.registers[0]);
		assertEquals(0,   firstFrame.registers[1]);
		assertEquals(0,   firstFrame.registers[2]);
		assertEquals(105, firstFrame.registers[3]);
	}
	
	@Test
	void loadK() throws FileNotFoundException, IOException {
		var events = setupProgram("""
		initStack( env.luaStack, 1, 2, 3 ); //3 varargs
		
		bool ok = loadk( &env, 3, 0 ); //reg 3, const 0
		env.error[ 0 ] = ok ? 1 : 0; //log
		""", 
		LuaSrcUtil.readBytecode("print.out"), //print"hello"
		5112, //heap
		1024, //stack
		32    //log/err
		);
		
		var done  = run(events);
		var stack = args.luaStack.readData(queue, done);
		var heap = args.heap.readData(queue);
		var log  = args.errorBuffer.readData(queue);
		
		var frames = readStackFrames(stack);
		
//		printFrames( frames );
//		dumpHeap(heap);
		
		assertEquals(1, log[0], "allocation failed");
		
		var firstFrame = frames.peekFirst();
		var regHref = firstFrame.registers[3];
		var heapValue = getChunkData(heap, regHref);
		
//		System.out.println(heapValue);
		
		assertEquals("print", heapValue.stringValue());
	}
	
	@Test
	void getTabUp() throws FileNotFoundException, IOException {
		var events = setupProgram("""		
		href mainClosure = createClosure( &env, 0, globals, 1 );
		setClosureUpval( &env, mainClosure, 0, env.globals );
		
		initStack( env.luaStack, 0, mainClosure, 0 ); //func 0, mainClosure, 0 varargs
		
		bool ok = getTabUp( &env, 2, 0, 0 | 0x100 );
		env.error[ 0 ] = ok ? 1 : 0; //log
		""", 
		LuaSrcUtil.readBytecode("returnMath.out"), //return math
		6000, //heap
		1024, //stack
		32    //log/err
		);
		
		var done  = run(events);
		var stack = args.luaStack.readData(queue, done);
		var heap = args.heap.readData(queue);
		var log  = args.errorBuffer.readData(queue);
		
		var frames = readStackFrames(stack);
		
		printFrames( frames );
		dumpHeap(heap);
		
		assertEquals(1, log[0], "allocation failed");
		
		var firstFrame = frames.peekFirst();
		var regHref = firstFrame.registers[2];
		var heapValue = getChunkData(heap, regHref);
		
//				System.out.println(heapValue);
		
		assertEquals( LuaTypes.TABLE, heapValue.type() );
	}
	
	@Test
	void readInstruction() throws FileNotFoundException, IOException {
		var events = setupProgram("""		
		
		LuaInstruction inst = env.code[ env.codeIndexes[ env.func ] + env.pc ];
		
		putHeapInt( env.error,  0,            inst   );
		putHeapInt( env.error,  4, getOpcode( inst ) );
		putHeapInt( env.error,  8, getA(      inst ) );
		putHeapInt( env.error, 12, getB(      inst ) );
		putHeapInt( env.error, 16, getC(      inst ) );
		
		""", 
		LuaSrcUtil.readBytecode("math.log.out"), //return math.log( 10 )
		6000, //heap
		1024, //stack
		2048    //log/err
		);
		
		var done  = run(events);
//		var stack = args.luaStack.readData(queue, done);
//		var heap = args.heap.readData(queue);
		var log  = args.errorBuffer.readData(queue);
		
		int inst 	= readIntAt(log,  0);
		int opCode 	= readIntAt(log,  4);
		int a 		= readIntAt(log,  8);
		int b 		= readIntAt(log, 12);
		int c 		= readIntAt(log, 16);
//		var frames = readStackFrames(stack);
		
		
		assertEquals(     6, opCode, "opcode wrong");
		assertEquals(     0,      a, "a (target register)");
		assertEquals(     0,      b, "b (table upval index (_ENV)) ");
		assertEquals( 0x100,      c, "c (key, const or reg) ");
		
		
	}
	
	@Test
	void nativeCall() throws FileNotFoundException, IOException {
		var events = setupProgram("""		
		href mainClosure = createClosure( &env, 0, globals, 1 ); //upvals, 1 (_ENV)
		setClosureUpval( &env, mainClosure, 0, env.globals );    //_ENV
		
		//initStack( env.luaStack, 0, mainClosure, 0 ); //func 0, mainClosure, 0 varargs
		
		bool ok = 
		  call( &env, mainClosure );
		
		env.error[ 0 ] = ok ? 1 : 0; //log
		env.error[ 1 ] = env.returnFlag ? 1 : 0;
		putHeapInt( env.error, 2, env.code[ env.codeIndexes[ env.func ] + env.pc ] );
		
		if( !env.returnFlag ) return;
		
		putHeapInt( env.error, 6, env.luaStack[ env.returnStart ] );
		""", 
		LuaSrcUtil.readBytecode("math.log.out"), //return math.log( 10 )
		6000, //heap
		1024, //stack
		2048    //log/err
		);
		
		var done  = run(events);
		var stack = args.luaStack.readData(queue, done);
		var heap = args.heap.readData(queue);
		var log  = args.errorBuffer.readData(queue);
		
		var ok = log[0] == 1;
		var returned = log[1] == 1;
		//debug
//		var lastInst = readIntAt(log, 2);
//		System.out.println("last instr: ");
//		System.out.println("  OP: " + (lastInst & 0x3F));
//		System.out.println("   A: " + ((lastInst >> 6) & 0xFF));
//		System.out.println("   B: " + ((lastInst >> 23) & 0x1FF));
//		System.out.println("   C: " + ((lastInst >> 14) & 0x1FF));
//		System.out.println("K(C): " + ((lastInst >> 14) & 0xFF));
		var returnValueHref = readIntAt(log, 6);
		
		var frames = readStackFrames(stack);
		
		printFrames( frames );
		dumpHeap(heap);
		
		assertTrue("call says it failed", ok);
		assertTrue("should have returnFlag true", returned);
		
		var result = getChunkData(heap, returnValueHref);
		assertEquals(LuaTypes.NUMBER, result.type());
		assertEquals(Math.log(10), result.doubleValue(), .0000001d);	
	}
	
}
