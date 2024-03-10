package com.theincgi.gplua.cl;

import java.util.ArrayList;

import org.bridj.Pointer;
import org.bridj.Pointer.StringType;

import com.nativelibs4java.opencl.CLBuffer;
import com.nativelibs4java.opencl.CLContext;
import com.nativelibs4java.opencl.CLEvent;
import com.nativelibs4java.opencl.CLMem.Usage;
import com.nativelibs4java.opencl.CLQueue;

public class StringBuffer extends ByteArray1D {
	
	public StringBuffer(CLContext context, Usage usage) {
		super(context, usage);
	}
	
	public CLEvent loadData( String data, CLQueue queue ) {
		var charList = new ArrayList<Byte>();
		short len = (short) data.length();
		
		charList.add((byte) ((len & 0xFF) >> 8));
		charList.add((byte) ( len & 0xFF      ));
		
		for(var c : data.getBytes())
			charList.add(c);
		return loadData(charList, queue);
	}
	
	public String readStrData(CLQueue queue, CLEvent... waitFor) {
		var ptr = buffer.read(queue, waitFor);
		var bytes = ptr.getBytes();
		var len = (bytes[0] << 8) | bytes[1];
		return new String(bytes, 2, len);
	}
}
