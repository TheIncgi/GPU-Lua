package com.theincgi.gplua.cl;

import java.util.ArrayList;
import java.util.List;

import org.bridj.Pointer;

import com.nativelibs4java.opencl.CLBuffer;
import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.CLMem.Usage;
import com.nativelibs4java.opencl.CLQueue;

public class IntArray1D {
	
	CLBuffer<Integer> buffer;
	Pointer<Integer> pointer;
	
	private CLContext context;
	private Usage usage;
	
	public IntArray1D(CLContext context, Usage usage) {
		this.context = context;
		this.usage = usage;
	}
	
	public CLEvent loadData( List<Integer> data, CLQueue queue ) {
		var unboxedData = new int[data.size()];
		for(int i = 0; i<data.size(); i++) 
			unboxedData[i] = data.get(i);
		
		return loadData(unboxedData, queue);
	}
	public CLEvent loadData(int[] data, CLQueue queue) {
		if(buffer != null)
			close();
		
		buffer = context.createIntBuffer(usage, data.length);
		pointer = Pointer.pointerToArray(data);
		
		return buffer.write(queue, pointer, false);
	}
	
	public CLBuffer<Integer> arg() {
		return buffer;
	}
	
	
	public void close() {
		buffer.release();
	}

	public CLEvent fillEmpty(int size, CLQueue queue) {
		buffer = context.createIntBuffer(usage, size);
		pointer = Pointer.pointerToArray(new int[size]);
		return buffer.write(queue, pointer, false);
	}
}
