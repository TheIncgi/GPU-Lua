package com.theincgi.gplua.cl;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Scanner;
import java.util.function.IntFunction;

//https://www.luac.nl/ is handy for viewing human readable bytecode
public class LuaSrcUtil {
	
	public static String LUA52 = "lua52";
	public static String LUAC = "luac52";
	
	/** format corresponding to non-number-patched lua, all numbers are floats or doubles<br>
	 * <br>
	 * <code>#define FORMAT          0               // this is the official format </code><br>
	 *  - https://www.lua.org/source/5.2/lundump.c.html#FORMAT
	 */
	public static final int NUMBER_FORMAT_FLOATS_OR_DOUBLES    = 0;

	/** format corresponding to non-number-patched lua, all numbers are ints */
	public static final int NUMBER_FORMAT_INTS_ONLY            = 1;
	
	/** format corresponding to number-patched lua, all numbers are 32-bit (4 byte) ints */
	public static final int NUMBER_FORMAT_NUM_PATCH_INT32      = 4;
	
	//function show(src) a = string.dump(load(src)) t = {} for a in a:gmatch"." do table.insert(t, string.format( "%02X", string.byte(a))) if #t%16==8 then table.insert(t, "  ") elseif #t%16==0 then print(table.concat(t," ")) t = {} end end print(table.concat(t, " ")) end
	
	/**
	 * string.dump can be used instead if a lua env is available
	 * bytecode = string.dump( load( src ) ) --convert from string to function to bytecode (string of bytes)
	 * @param file where to save the temp file to
	 * @throws IOException 
	 * @throws InterruptedException 
	 * */
	public static void compile(String srcCode, String file) throws IOException, InterruptedException {
		var rt = Runtime.getRuntime();
		var proc = rt.exec(new String[] { LUAC, "-o", file, "-" });
		proc.getOutputStream().write(srcCode.getBytes());
		proc.getOutputStream().flush();
		proc.getOutputStream().close();
		proc.waitFor();
		if( proc.getErrorStream().available() > 0 ) {
			throw new LuaCompileException( new String(proc.getErrorStream().readAllBytes()) );
		}
	}
	
	
	public static byte[] compile(String srcCode) throws IOException, InterruptedException {
		srcCode = "function SRC()\n" + srcCode + "\nend local b = string.dump( SRC )";
		boolean asBinary = false; //somehow the output is messed up when binary output is used :\ 
		                          //an embeded lua env would be best, like LuaJ or some other option.
		if( asBinary  ) { 
			srcCode += " print(b)";
		} else {
			srcCode += " print(string.byte(b,1,#b))";
		}
		var rt = Runtime.getRuntime();
		var proc = rt.exec(new String[] {LUA52, "-"});
		proc.getOutputStream().write(srcCode.getBytes());
		proc.getOutputStream().flush();
		proc.getOutputStream().close();
		proc.waitFor();
		if( proc.getErrorStream().available() > 0 ) {
			throw new LuaCompileException( new String(proc.getErrorStream().readAllBytes()) );
		}
		
		if( asBinary ) {
			return proc.getInputStream().readAllBytes();
		}
		Scanner s = new Scanner(proc.getInputStream());
		var list = new ArrayList<Byte>();
		while(s.hasNextInt()) {
			list.add((byte) s.nextInt());
		}
		s.close();
		var bytes = new byte[list.size()];
		for(int i = 0; i<bytes.length; i++)
			bytes[i] = list.get(i);
		return bytes;
	}
	
	public static boolean isUpdated(File src, File compiled) {
        if (!src.exists()) {
            throw new IllegalArgumentException("Source file does not exist.");
        }
        // If the compiled file doesn't exist, or if it's older than the source file, return false
        if (!compiled.exists() || compiled.lastModified() < src.lastModified()) {
            return false;
        }
        
        return true;
    }
	
	public static byte[] readBytecode(String file) throws FileNotFoundException, IOException {
		try(FileInputStream fis = new FileInputStream(file)) {
			return fis.readAllBytes();
		}
	}
	
	
	/** datastream reads ints in as (Big Endian): <br>
	 * (((a & 0xff) << 24) | ((b & 0xff) << 16) | ((c & 0xff) <<  8) | (d & 0xff))<br>
	 * <br>
	 * <b>Big Endian</b> - Most significant byte first
	 * <b>Little Endian</b> - Least significant byte first
	 */
	public static int intAsLittleEndian( int raw, boolean littleEndian ) {
		if( !littleEndian )
			return raw;
		
		return Integer.reverseBytes(raw); 
//			((raw & 0xFF) << 16) | ( (raw & 0xFF_00) << 8) | ((raw & 0xFF_00_00) >> 8) | ((raw & 0xFF_00_00_00) >> 16);
	}
	
	/**
	 * Adapted from LuaJ source which is based closely on Lua's source<br>
	 * Returned array will be { numberType, bytes... }
	 * @throws IOException 
     */
	public static byte[] readNumber(DataInputStream dis, int numberFormat, boolean littleEndian) throws IOException {
		if( numberFormat == NUMBER_FORMAT_INTS_ONLY ) {
			var buf = new byte[5];
			dis.read(buf, 1, 4);
			return buf;
		}
		//else long bits to number
		dis.mark(8);
		var longBits = dis.readLong();
		if(littleEndian)
			longBits = Long.reverseBytes(longBits);
		byte[] buf = new byte[9];
		dis.reset();
		dis.readNBytes(buf, 1, 8); //TODO Swap order?
		
		//
		if ( ( longBits & ( ( 1L << 63 ) - 1 ) ) == 0L ) {
			return new byte[] {(byte) LuaTypes.INT, 0, 0, 0, 0}; //return LuaValue.ZERO, type as int here
		}
		
		int e = (int)((longBits >> 52) & 0x7ffL) - 1023; //exponent?
		
		if ( e >= 0 && e < 31 ) {
			long f = longBits & 0xFFFFFFFFFFFFFL;
			int shift = 52 - e;
			long intPrecMask = ( 1L << shift ) - 1;
			if ( ( f & intPrecMask ) == 0 ) {
				int intValue = (int)( f >> shift ) | ( 1 << e );
//				return LuaInteger.valueOf( ( ( bits >> 63 ) != 0 ) ? -intValue : intValue );
				int value = ( ( ( longBits >> 63 ) != 0 ) ? -intValue : intValue );
				return intAsLuaNumber(value, false); //already flip'd
			}
		}
		
//		Double.longBitsToDouble(longBits);
		buf[0] = LuaTypes.NUMBER; //double
		return buf;
	}
	
	
	private static byte[] intAsLuaNumber(int value, boolean littleEndian) {
		var buf = new byte[5];
		if(littleEndian)
			value = Integer.reverseBytes(value);
		
		//like Big Endian, most significant first
		buf[0] = (byte) LuaTypes.INT;
		buf[1] = (byte) (value >> 24 & 0xFF);
		buf[2] = (byte) (value >> 16 & 0xFF);
		buf[3] = (byte) (value >>  8 & 0xFF);
		buf[4] = (byte) (value       & 0xFF);
		return buf;
	}

	public static FlattenedBytecode parseBytecode(byte[] bytecode) throws IOException {
		DataInputStream dis = new DataInputStream(new ByteArrayInputStream(bytecode)); //mark supported
		
		//ignoring first 4 chars (0x1B L u a), better code might verify those
		dis.skip( 0x04 );
		
		
		if( dis.read() != 0x52 ) { //0x04
			throw new RuntimeException("Expected lua bytecode compiled by version 5.2 (0x52 | 82)");
		}
		
		if( dis.read() != 0) { //0x05
			throw new RuntimeException("Expected binary data");
		}
		
		boolean isLittleEndian = dis.readBoolean();	  	 //0x06
		int sizeOfInt = dis.read();						 //0x07
		int sizeOfSizeT = dis.read();              		 //0x08
		int sizeOfInstruction = dis.read();       		 //0x09
		int sizeOfLuaNumber = dis.read();         		 //0x0A
		
		int numberFormat = dis.read();
		if( numberFormat != 0 && numberFormat != 1 && numberFormat != 4 ) {	//0x0B
			throw new RuntimeException("Unexpected number format defined from bytecode. expected 0 1 or 4, got " + bytecode[ 0x0B ]);
		}
		
		
		//tail 0x19 0x93 \r \n 0x1A \n, don't care skipping
		dis.skipNBytes(6);
		
		var flat = new FlattenedBytecode();
		
		while( dis.available() > 0 ) {
			parseFunction(dis, isLittleEndian, sizeOfSizeT, numberFormat, flat);
		}
		
		return flat;
	}

	private static void parseFunction(DataInputStream dis, boolean isLittleEndian, int sizeOfSizeT, int numberFormat,
			FlattenedBytecode flat) throws IOException {
		flat.linesDefined.add(intAsLittleEndian(dis.readInt(), isLittleEndian ));
		flat.lastLinesDefined.add(intAsLittleEndian(dis.readInt(), isLittleEndian));
		flat.numParams.add((byte) dis.read());
		flat.isVararg.add(dis.readByte());
		flat.maxStackSize.add((byte) dis.read());
		
		//instructions
		int codeLen = intAsLittleEndian(dis.readInt(), isLittleEndian);
		int[] code = new int[codeLen];
		for(int i = 0; i<codeLen; i++)
			code[i] = intAsLittleEndian(dis.readInt(), isLittleEndian);
		flat.codeLengths.add(codeLen);
		flat.code.add(code);
		
		//constants
		int constLen = intAsLittleEndian(dis.readInt(), isLittleEndian);
		ArrayList<byte[]> constData = new ArrayList<>();
		for(int c = 0; c < constLen; c++) {
			byte type = (byte) dis.read();
			switch (type) {
				case 0: //nil
					constData.add(new byte[] {type});
					break;
				
				case 1: //boolean
					constData.add(new byte[] {type, (byte) dis.read()});
					break;
					
				case 3: //number
					constData.add(readNumber(dis, numberFormat, isLittleEndian));
					break;
					
				case 4: //string
					constData.add(readString(dis, sizeOfSizeT, isLittleEndian));
					break;
				
//				case 2: //light user data, can't be a constant
//				case 5: //table
//				case 6: //function
//				case 7: //user data
//				case 8: //thread
				default:
					throw new RuntimeException("Unhandled constant type "+ type);
			}
		}
		flat.constantsLengths.add(constLen);
		flat.constants.add(constData);
		
		//protos
		int protosLen = intAsLittleEndian(dis.readInt(), isLittleEndian);
		int setIndex = flat.upvals.size();
		flat.upvalsLengths.add(null); //placeholders for recursion
		flat.upvals.add(null);
		flat.numProtos.add(protosLen);
		//TODO: allocate for debug if included here
		
		for(int proto = 0; proto < protosLen; proto++) {
			parseFunction(dis, isLittleEndian, sizeOfSizeT, numberFormat, flat);
		}
		
		//upvals
		int upvalsLen = intAsLittleEndian(dis.readInt(), isLittleEndian);
		byte[] upvals = new byte[upvalsLen * 2];
		for(int u = 0; u < upvalsLen; u++) {
			upvals[u*2    ] = dis.readByte(); //boolean
			upvals[u*2 + 1] = dis.readByte(); //index
		}
		flat.upvalsLengths.set(setIndex, upvalsLen);
		flat.upvals.set(setIndex, upvals);
		
		
		
		//debug - skipped
		//source
		byte[] sourceName = readString(dis, sizeOfSizeT, isLittleEndian);
		//line info
		int lineInfoLen = intAsLittleEndian(dis.readInt(), isLittleEndian);
		int[] lineInfo = new int[lineInfoLen];
		for(int i = 0; i < lineInfoLen; i++)
			lineInfo[i] = intAsLittleEndian(dis.readInt(), isLittleEndian);
		//local vars
		int localVarsLen = intAsLittleEndian(dis.readInt(), isLittleEndian);
		byte[][] varNames = new byte[localVarsLen][];
		int[] startPCs = new int[localVarsLen];
		int[] endPCs = new int[localVarsLen];
		for(int v = 0; v < localVarsLen; v++) {
			varNames[v] = readString(dis, sizeOfSizeT, isLittleEndian);
			startPCs[v] = intAsLittleEndian(dis.readInt(), isLittleEndian);
			endPCs[v]   = intAsLittleEndian(dis.readInt(), isLittleEndian);
		}
		//debug upvals
		int debugUpvalsLen = intAsLittleEndian(dis.readInt(), isLittleEndian);
		byte[][] upvalNames = new byte[debugUpvalsLen][];
		for(int d = 0; d < debugUpvalsLen; d++) {
			upvalNames[d] = readString(dis, sizeOfSizeT, isLittleEndian);
		}
	}
	
	
	private static byte[] readString(DataInputStream dis, int sizeOfSizeT, boolean isLittleEndian) throws IOException {
		int len = sizeOfSizeT == 8? (int) 
				(isLittleEndian ? Long.reverseBytes(dis.readLong()) : dis.readLong())
				: intAsLittleEndian(dis.readInt(), isLittleEndian);
			
		len--;
		byte[] buf = new byte[Math.max(len+6, 2)]; //type, len and null terminated, but the data is already null terminated
		buf[0] = 4; //string type
		buf[1] = (byte) ((len >> 24) & 0xFF); 
		buf[2] = (byte) ((len >> 16) & 0xFF); 
		buf[3] = (byte) ((len >>  8) & 0xFF); 
		buf[4] = (byte) ((len      ) & 0xFF); 
		
		for(int i = 0; i < len; i++){
			buf[i+5] = dis.readByte();
		}
		dis.skip(1);
		return buf;
	}

	
	
	
	public static class FlattenedBytecode {
		public ArrayList<Integer> linesDefined			= new ArrayList<>();
		public ArrayList<Integer> lastLinesDefined		= new ArrayList<>();
		public ArrayList<Byte>   numParams				= new ArrayList<>();  //probably unsigned
		public ArrayList<Byte> isVararg					= new ArrayList<>();
		public ArrayList<Byte> maxStackSize				= new ArrayList<>(); //propbably unsigned
		
		public ArrayList<Integer> codeLengths			= new ArrayList<>(); //can be calculated
		public ArrayList<int[]> code					= new ArrayList<>();
		
		public ArrayList<Integer> constantsLengths		= new ArrayList<>(); //can beCalculated
		public ArrayList<ArrayList<byte[]>> constants	= new ArrayList<>(); //constants lengths is unknown, dependend on data types, [function]
		public ArrayList<Integer> numProtos            	= new ArrayList<>();
		
		public ArrayList<Integer> upvalsLengths			= new ArrayList<>(); //can be calculated
		public ArrayList<byte[]> upvals					= new ArrayList<>(); //*2, onStack, index
		
		public FlattenedBytecode() {
		}
		
		
	}
	
}
