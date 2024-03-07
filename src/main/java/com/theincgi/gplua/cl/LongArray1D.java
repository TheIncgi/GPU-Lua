package com.theincgi.gplua.cl;

import java.util.ArrayList;
import java.util.List;

import org.bridj.Pointer;

import com.nativelibs4java.opencl.CLBuffer;
import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.CLMem.Usage;
import com.nativelibs4java.opencl.CLQueue;

public class LongArray1D {
	
	CLBuffer<Long> buffer;
	Pointer<Long> pointer;
	
	private CLContext context;
	private Usage usage;
	
	public LongArray1D(CLContext context, Usage usage) {
		this.context = context;
		this.usage = usage;
	}
	
	public CLEvent fillEmpty(int size, CLQueue queue) {
		if(buffer != null)
			close();
		buffer = context.createLongBuffer(usage, size);
		pointer = Pointer.pointerToArray(new long[size]);
		
		return buffer.write(queue, pointer, false);
	}
	
	public CLEvent loadData( List<Long> data, CLQueue queue ) {
		if(buffer != null)
			close();
		
		buffer = context.createLongBuffer(usage, data.size());
		
		var unboxedData = new long[data.size()];
		for(int i = 0; i<data.size(); i++) 
			unboxedData[i] = data.get(i);
		
		pointer = Pointer.pointerToArray(unboxedData);
		
		return buffer.write(queue, pointer, false);
	}
	
	public CLBuffer<Long> arg() {
		return buffer;
	}
	
	
	public void close() {
		buffer.release();
	}
}
