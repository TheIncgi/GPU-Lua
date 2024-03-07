package com.theincgi.gplua.cl;

import java.util.ArrayList;
import java.util.List;

import org.bridj.Pointer;

import com.nativelibs4java.opencl.CLBuffer;
import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.CLMem.Usage;
import com.nativelibs4java.opencl.CLQueue;

public class IntArray2D {
	
	CLBuffer<Integer> buffer;
	CLBuffer<Integer> indexBuffer;
	Pointer<Integer> pointer, indexPointer;
	private CLContext context;
	private Usage usage;
	
	public IntArray2D(CLContext context, Usage usage) {
		this.context = context;
		this.usage = usage;
	}
	
	public static int flattenedLength(ArrayList<int[]> data) {
		int sum = 0;
		for(var a : data)
			sum += a.length;
		
		return sum;
	}
	
	public List<CLEvent> loadData( ArrayList<int[]> data, CLQueue queue ) {
		if(buffer != null)
			close();
		
		int flatLen = flattenedLength(data);
		buffer = context.createIntBuffer(usage, flatLen);
		indexBuffer = context.createIntBuffer(usage, data.size() * 2);
		
		int[] flatData = new int[flatLen];
		int[] indexes = new int[data.size() * 2];
		int i = 0;
		int j = 0;
		for(var a : data) {
			System.arraycopy(a, 0, flatData, i, a.length);
			indexes[ j*2    ] = i;
			indexes[ j*2 + 1] = a.length;
			i += a.length;
			j += 2;
		}
		
		pointer = Pointer.pointerToArray(flatData);
		indexPointer = Pointer.pointerToArray(indexes);
		
		var bufferWrite = buffer.write(queue, pointer, false);
		var indexWrite = indexBuffer.write(queue, indexPointer, false);
		
		return List.of(bufferWrite, indexWrite);
	}
	
	public CLBuffer<Integer> arg() {
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
