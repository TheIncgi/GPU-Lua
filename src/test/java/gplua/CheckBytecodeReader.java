package gplua;

import java.io.IOException;

import com.theincgi.gplua.cl.LuaSrcUtil;

public class CheckBytecodeReader {
	
	public static void main(String[] args) throws IOException {
		var bytecode = LuaSrcUtil.readBytecode("print.out");
		
		var flat = LuaSrcUtil.parseBytecode(bytecode);
		
		System.out.println(flat); //breakpoint
	}
	
}
