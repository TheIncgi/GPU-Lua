package com.theincgi.gplua.cl;

import java.util.ArrayList;
import java.util.List;

import org.bridj.Pointer;

import com.nativelibs4java.opencl.CLBuffer;
import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.CLMem.Usage;
import com.nativelibs4java.opencl.CLQueue;

public class ByteArray1D {
	
	CLBuffer<Byte> buffer;
	Pointer<Byte> pointer;
	
	private CLContext context;
	private Usage usage;
	
	public ByteArray1D(CLContext context, Usage usage) {
		this.context = context;
		this.usage = usage;
	}
	
	public void noData(long size) {
		buffer = context.createByteBuffer(usage, size);
	}
	
	public CLEvent fillEmpty(int size, CLQueue queue) {
		if(buffer != null)
			close();
		buffer = context.createByteBuffer(usage, size);
		pointer = Pointer.pointerToArray(new byte[size]);
		
		return buffer.write(queue, pointer, false);
	}
	
	public CLEvent loadData( List<Byte> data, CLQueue queue ) {
		if(buffer != null)
			close();
		
		buffer = context.createByteBuffer(usage, data.size());
		
		var unboxedData = new byte[data.size()];
		for(int i = 0; i<data.size(); i++) 
			unboxedData[i] = data.get(i);
		
		pointer = Pointer.pointerToArray(unboxedData);
		
		return buffer.write(queue, pointer, false);
	}
	
	public byte[] readData(CLQueue queue, CLEvent... waitFor) {
		var ptr = buffer.read(queue, waitFor);
		return ptr.getBytes();
	}
	
	public CLBuffer<Byte> arg() {
		return buffer;
	}
	
	
	public void close() {
		buffer.release();
	}
}
