package com.theincgi.gplua.cl;

import static com.nativelibs4java.opencl.CLMem.Usage.Input;
import static com.nativelibs4java.opencl.CLMem.Usage.InputOutput;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.CLKernel;
import com.nativelibs4java.opencl.CLQueue;

public class LuaKernelArgs {
	
	//general
//	public final IntArray1D workSize;
	//call info stack??
//	public final ByteArray1D luaState;
//	public final IntArray1D luaStack;
	public final IntArray1D heapSize; // [heapSize]
//	public final IntArray1D errorPointer
	/**
	 * Marked for future removal, T_ERROR on the heap combined with stack return values will be prefered moving forward
	 * */
	public final ByteArray1D heap;
	public final LongArray1D maxExecutionTime; //[millis]
	
	
	//from flattened bytecode
	public final IntArray1D linesDefinedBuffer;
	public final IntArray1D lastLinesDefinedBuffer;
	public final ByteArray1D numParamsBuffer;
	public final ByteArray1D isVarargBuffer;
	public final ByteArray1D maxStackSizeBuffer;
	
	public final IntArray2D codeBuffer;
	
	public final ByteArray3D constantsBuffer;
	public final IntArray1D protoLengthsBuffer;
	
	public final ByteArray2D upvals;
	
	/**{start on stack, len}*/
	public final IntArray1D returnInfo;
	//end of bytecode args
	
	IntArray1D nFunctions; //and closures
	public final CLContext context;
	
	public LuaKernelArgs(CLContext context) {
		this.context = context;
		
		heapSize = new IntArray1D(context, Input);
		heap = new ByteArray1D(context, InputOutput);          //io
		maxExecutionTime = new LongArray1D(context, Input);
		
		linesDefinedBuffer = new IntArray1D(context, Input);
		lastLinesDefinedBuffer = new IntArray1D(context, Input);
		numParamsBuffer = new ByteArray1D(context, Input);
		isVarargBuffer = new ByteArray1D(context, Input);
		maxStackSizeBuffer = new ByteArray1D(context, Input);
		
		//codeLengthsBuffer = new IntArray1D(context, Input);
		codeBuffer = new IntArray2D(context, Input);
		
		//constantsLengthsBuffer = new IntArray1D(context, Input);
		constantsBuffer = new ByteArray3D(context, Input);
		protoLengthsBuffer = new IntArray1D(context, Input);
		
		//upvalsLengths = new IntArray1D(context, Input);
		upvals = new ByteArray2D(context, Input);
		
		nFunctions = new IntArray1D(context, Input);
		
		returnInfo = new IntArray1D(context, InputOutput);
	}
	
	public List<CLEvent> loadBytecode( byte[] bytecode, CLQueue queue ) throws IOException {
		var flat = LuaSrcUtil.parseBytecode(bytecode);
		var events = new ArrayList<CLEvent>();
		
		
		events.add( nFunctions.loadData(new int[] {flat.code.size()}, queue) );
		
		events.add( linesDefinedBuffer.loadData(flat.linesDefined, queue));
		events.add( lastLinesDefinedBuffer.loadData(flat.lastLinesDefined, queue));
		events.add( numParamsBuffer.loadData(flat.numParams, queue));
		events.add( isVarargBuffer.loadData(flat.isVararg, queue));
		events.add( maxStackSizeBuffer.loadData(flat.maxStackSize, queue));
		
		//events.add( codeLengthsBuffer.loadData(flat.codeLengths, queue));
		events.addAll( codeBuffer.loadData(flat.code, queue));
		
		//events.add( constantsLengthsBuffer.loadData(flat.constantsLengths, queue));
		events.addAll( constantsBuffer.loadData(flat.constants, queue));
		events.add( protoLengthsBuffer.loadData(flat.numProtos, queue));
		
		//events.add( upvalsLengths.loadData(flat.upvalsLengths, queue));
		events.addAll( upvals.loadData(flat.upvals, queue));
		
		events.add( returnInfo.fillEmpty(3, queue) );
		
		return events;
	}
	
//	public CLEvent setWorkSize(CLQueue queue, int... workSize) {
//		return this.workSize.loadData(workSize, queue);
//	}
	
	public List<CLEvent> setStackSizes(CLQueue queue, int heap, int[] workDim) {
		int x = 0;
		for(var w : workDim) x += w;
		heap *= x;
		
		var eventA = this.heapSize.loadData(List.of( heap ), queue);
		this.heap.noData(heap);
		
		return List.of(eventA);
	}
	
	public CLEvent setMaxExecution(CLQueue queue, long millis) {
		return maxExecutionTime.loadData(List.of(millis), queue);
	}
	
	public void applyArgs(CLKernel kernel) {
		kernel.setArgs(
			heapSize.arg(),
			maxExecutionTime.arg(),
			heap.arg(),
			
			nFunctions.arg(),
			linesDefinedBuffer.arg(),
			lastLinesDefinedBuffer.arg(),
			numParamsBuffer.arg(),
			isVarargBuffer.arg(),
			maxStackSizeBuffer.arg(),
			
			codeBuffer.indexArg(),
			codeBuffer.arg(),
			
			constantsBuffer.indexArg(),
			constantsBuffer.secondaryIndexArg(),
			constantsBuffer.arg(),
			protoLengthsBuffer.arg(),
			
			upvals.indexArg(),
			upvals.arg(),
			returnInfo.arg()
		);
	}
	
}
