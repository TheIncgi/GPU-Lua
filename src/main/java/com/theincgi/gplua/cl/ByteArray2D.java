package com.theincgi.gplua.cl;

import java.util.ArrayList;
import java.util.List;

import org.bridj.Pointer;

import com.nativelibs4java.opencl.CLBuffer;
import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.CLMem.Usage;
import com.nativelibs4java.opencl.CLQueue;

public class ByteArray2D {
	
	CLBuffer<Byte> buffer;
	CLBuffer<Integer> indexBuffer;
	Pointer<Byte> pointer;
	Pointer<Integer> indexPointer;
	
	private CLContext context;
	private Usage usage;
	
	public ByteArray2D(CLContext context, Usage usage) {
		this.context = context;
		this.usage = usage;
	}
	
	public static int flattenedLength(ArrayList<byte[]> data) {
		int sum = 0;
		for(var a : data)
			sum += a.length;
		
		return sum;
	}
	
	public List<CLEvent> loadData( ArrayList<byte[]> data, CLQueue queue ) {
		if(buffer != null)
			close();
		
		if( data.size() == 0 || (data.size()  == 1 && data.get(0).length == 0)) {
			buffer = context.createByteBuffer(usage, 1);
			indexBuffer = context.createIntBuffer(usage, 2);
			
			pointer = Pointer.pointerToArray(new byte[] {0});
			indexPointer = Pointer.pointerToArray(new byte[] {0,0});
			
			var bufferWrite = buffer.write(queue, pointer, false);
			var indexWrite = indexBuffer.write(queue, indexPointer, false);
			
			return List.of(bufferWrite, indexWrite);
		}
		
		int flatLen = flattenedLength(data);
		buffer = context.createByteBuffer(usage, flatLen);
		indexBuffer = context.createIntBuffer(usage, data.size() * 2);
		
		var flatData = new byte[flatLen];
		var indexes = new int[data.size() * 2];
		int i = 0;
		int j = 0;
		for(var a : data) {
			System.arraycopy(a, 0, flatData, i, a.length);
			indexes[ j*2    ] = i;
			indexes[ j*2 + 1] = a.length;
			i += a.length;
			j += 1;
		}
		
		pointer = Pointer.pointerToArray(flatData);
		indexPointer = Pointer.pointerToArray(indexes);
		
		var bufferWrite = buffer.write(queue, pointer, false);
		var indexWrite = indexBuffer.write(queue, indexPointer, false);
		
		return List.of(bufferWrite, indexWrite);
	}
	
	public CLBuffer<Byte> arg() {
		return buffer;
	}
	
	public CLBuffer<Integer> indexArg() {
		return indexBuffer;
	}
	
	public void close() {
		buffer.release();
		indexPointer.release();
	}
}
