package com.theincgi.gplua.cl;

import java.util.ArrayList;
import java.util.List;

import org.bridj.Pointer;

import com.nativelibs4java.opencl.CLBuffer;
import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.CLMem.Usage;
import com.nativelibs4java.opencl.CLQueue;

public class ByteArray3D {
	
	CLBuffer<Byte> buffer;
	CLBuffer<Integer> indexBuffer;
	CLBuffer<Integer> secondaryIndexBuffer;
	
	Pointer<Byte> pointer;
	Pointer<Integer> indexPointer;
	Pointer<Integer> secondaryIndexPointer;
	
	/*
	 * data: [
	 *    f1: [
	 *      [4x,5,6,7]
	 *      
	 *    ]
	 *    f2: [
	 *    	[z,y,x],
	 *      [w,u,v],
	 *      [0]
	 *    ]
	 * ]
	 * 
	 * packed: [41,5,6,7,z,y,x,w,u,v,0]
	 * primary: [0, 2,   2, 2] //index in secondary, len, length of primary is #functions or defined elsewhere
	 * secondary: [0, 2,   1, 1,  |   2,1,  3,1  ...] //index in data, length
	 * */
	
	private CLContext context;
	private Usage usage;
	
	public ByteArray3D(CLContext context, Usage usage) {
		this.context = context;
		this.usage = usage;
	}
	
	
	public static int flattenedLength3D(ArrayList<ArrayList<byte[]>> data) {
		int sum = 0;
		for(var al : data)
			sum += flattenedLength2D(al);
		
		return sum;
	}
	public static int flattenedLength2D(ArrayList<byte[]> data) {
		int sum = 0;
		for(var a : data)
			sum += a.length;
		
		return sum;
	}
	
	public static int secondaryLength(ArrayList<ArrayList<byte[]>> data) {
		int len = 0;
		for(var a : data)
			len += a.size();
		
		return len;
	}
	
	public List<CLEvent> loadData( ArrayList<ArrayList<byte[]>> data, CLQueue queue ) {
		if(buffer != null)
			close();
		
		
		int flatLen = flattenedLength3D(data);
		int secondaryLen = secondaryLength(data);
		
		if(flatLen == 0) {
			indexBuffer = context.createIntBuffer(usage, 2);
			secondaryIndexBuffer = context.createIntBuffer(usage, 2);
			buffer = context.createByteBuffer(usage, 1);
			
			pointer = Pointer.pointerToArray(new int[] {0});
			indexPointer = Pointer.pointerToArray(new int[] {0,0});
			secondaryIndexPointer = Pointer.pointerToArray(new int[] {0,0});
			
			var bufferWrite = buffer.write(queue, pointer, false);
			var indexWrite = indexBuffer.write(queue, indexPointer, false);
			var indexWrite2 = secondaryIndexBuffer.write(queue, secondaryIndexPointer, false);
			return List.of(bufferWrite, indexWrite, indexWrite2);
		}
		
		indexBuffer = context.createIntBuffer(usage, data.size() * 2);
		secondaryIndexBuffer = context.createIntBuffer(usage, secondaryLen * 2);
		buffer = context.createByteBuffer(usage, flatLen);
		
		var indexes = new int[data.size() * 2];
		var secondary = new int[secondaryLen * 2];
		var flatData = new byte[flatLen];
		
		int primary = 0;
		int secondaryWrite = 0;
		int dataWrite = 0;
		for(int f = 0; f < data.size(); f++) {
			
			var fArraylist = data.get(f);
			indexes[ primary * 2    ] = secondaryWrite;
			indexes[ primary * 2 + 1] = fArraylist.size();
			primary ++;
			
			for(int i = 0; i < fArraylist.size(); i++) {
				var byteData = fArraylist.get(i);
				secondary[ secondaryWrite * 2     ] = dataWrite;
				secondary[ secondaryWrite * 2 + 1 ] = byteData.length;
				secondaryWrite ++;
				
				System.arraycopy(byteData, 0, flatData, dataWrite, byteData.length);
				dataWrite += byteData.length;
			}
		}
		
		pointer = Pointer.pointerToArray(flatData);
		indexPointer = Pointer.pointerToArray(indexes);
		secondaryIndexPointer = Pointer.pointerToArray(secondary);
		
		var bufferWrite = buffer.write(queue, pointer, false);
		var indexWrite = indexBuffer.write(queue, indexPointer, false);
		var indexWrite2 = secondaryIndexBuffer.write(queue, secondaryIndexPointer, false);
		
		return List.of(bufferWrite, indexWrite, indexWrite2);
	}
	
	public CLBuffer<Byte> arg() {
		return buffer;
	}
	
	public CLBuffer<Integer> indexArg() {
		return indexBuffer;
	}
	
	public CLBuffer<Integer> secondaryIndexArg() {
		return secondaryIndexBuffer;
	}
	
	public void close() {
		buffer.release();
		indexPointer.release();
	}
}
