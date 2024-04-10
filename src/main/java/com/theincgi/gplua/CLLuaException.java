package com.theincgi.gplua;

import com.theincgi.gplua.cl.HeapUtils.TaggedMemory;

public class CLLuaException extends RuntimeException {

	public final TaggedMemory chunk;

	public CLLuaException(TaggedMemory chunkData) {
		super( chunkData.toString() );
		this.chunk = chunkData;
	}
	
}
