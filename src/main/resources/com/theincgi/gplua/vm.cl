#include"vm.h"
#include"common.cl"
#include"closure.h"
#include"stackUtils.h"
#include"heapUtils.h"
#include"opUtils.cl"
#include"types.cl"
#include"natives.cl"

void getConstDataRange( struct WorkerEnv* env, uint index, uint* start, uint* len ) {
    uint fConstStart = env->constantsPrimaryIndex[ env->func * 2     ];
    uint fConstLen   = env->constantsPrimaryIndex[ env->func * 2 + 1 ];

    uint secondaryIndex = fConstStart + index * 2;
    //if secondaryIndex > >= len return 0, 1 indexed ? 0 indexed?
    *start = env->constantsSecondaryIndex[ secondaryIndex     ];
    *len   = env->constantsSecondaryIndex[ secondaryIndex + 1 ];
}

bool op_move( struct WorkerEnv* env, uchar dstReg, ushort srcReg ) {
    if(setRegister( env->luaStack, env->stackSize, dstReg, getRegister( env->luaStack, srcReg ) )) {
        env->pc++;
        return true;
    }
    return false;
}

//TODO cache hrefs using env->constTable;
href kToHeap( struct WorkerEnv* env, uint index ) {
    uint constStart; 
    uint constLen;
    getConstDataRange( env, index, &constStart, &constLen );

    if( constLen == 0 )
        return 0; //const should have at minium 1 byte for type

    href k = allocateHeap( env->heap, env->maxHeapSize, constLen );
    if( k == 0 ) { return false; } //TODO err OOM

    uint limit = constStart + constLen;
    for( uint r = constStart, w = 0; r < limit; r++, w++ ) {
        env->heap[ k + w ] = env->constantsData[ r ];
    }

    return k;
}

bool loadk( struct WorkerEnv* env, uchar reg, uint index ) { 
    href k = kToHeap( env, index );
    if( k == 0 ) return false;

    //nil bool number str
    if( setRegister( env->luaStack, env->stackSize, reg, k ) ) {
        env->pc++;
        return true;
    } else {
        freeHeap( env->heap, env->maxHeapSize, k, false ); //TODO return href instead?
        return false;
    }
}

href _getUpVal( struct WorkerEnv* env, href closureRef, uint upval ) {
    if( closureRef == 0 ) return 0;
    return getClosureUpval( env, closureRef, upval );
}

// GETTABLE A B C   R(A) := R(B)[RK(C)]       //table comes from heap
// GETTABUP A B C   R(A) := UpValue[B][RK(C)] //table comes from upval

//the table is an upval
bool getTabUp( struct WorkerEnv* env, uchar reg, uint upvalIndexOfTable, uint tableKey ) {
    href closure = getStackClosure( env->luaStack );
    if( closure == 0 ) return false;
    
    href table = getClosureUpval( env, closure, upvalIndexOfTable );
    if( table == 0 ) return false;

    if( env->heap[ table ] != T_TABLE )
        return false; //attempt to index TYPE
    
    href value = 0;
    if( isK(tableKey) ) { //use constant
        int index = indexK( tableKey );
        value = tableGetByConst( env, table, index );
    } else { //use register
        href key = getRegister( env->luaStack, (uchar)tableKey );
        value = tableGetByHeap( env, table, key );
    }

    env->pc++;
    setRegister( env->luaStack, env->stackSize, reg, value );
    return true;
}

//the table is a register value
bool op_getTable( struct WorkerEnv* env, uchar destReg, ushort tableReg, ushort tableKey) { //FIXME
    href table = getRegister( env->luaStack, tableReg );
    if( table == 0 ) return false; //attempt to index nil

    if( env->heap[ table ] != T_TABLE )
        return false; //attempt to index TYPE

    href value = 0;
    if( isK( tableKey )) {
        int index = indexK( tableKey );
        value = tableGetByConst( env, table, index );
    } else {
        href key = getRegister( env->luaStack, (uchar)tableKey );
        value = tableGetByHeap( env, table, key );
    }

    env->pc++;
    setRegister( env->luaStack, env->stackSize, destReg, value );
    return true;
}

//set table upval
// UpVal[A][RK(B)] := RK(C) | UpVal[ tableUpvalIndex A ][ tableKey B ] := tableValue C
bool op_settabup( struct WorkerEnv* env, uchar a, ushort b, ushort c ) { 
    href closure = getStackClosure( env->luaStack ); //active function
    if( closure == 0 ) return false;

    href table = _getUpVal( env, closure, a ); //table upval of current function
    if( env->heap[table] != T_TABLE ) return false; //attempt to assign to TYPE

    return _settable( env, table, b, c );    
}

//R(A)[RK(B)] := RK(C) | Registers[ A ][ tableKey B ] := tableValue C
bool op_settable( struct WorkerEnv* env, uchar a, ushort b, ushort c ) {
    href table = getRegister( env->luaStack, a );
    if( env->heap[table] != T_TABLE ) return false; //attempt to assign to TYPE

    bool ok = _settable( env, table, b, c );
    if( ok ) env->pc++;
    return ok;
}

//shared logic of settabup and settable
bool _settable( struct WorkerEnv* env, href table, ushort b, ushort c ) {
    href key, value;

    if( isK( b ) ) {
        key = kToHeap( env, indexK( b ));
        if( key == 0 ) return false; //failed to allocate key to heap or attempt to index using nil
    } else {
        key = getRegister( env->luaStack, b );
        if( key == 0 ) return false; //attempt to index using nil
    }

    if( isK( c )) {
        value = kToHeap( env, indexK( c ));
        if( value == 0 ) return false; //failed to allocate value to heap
    } else {
        value = getRegister( env->luaStack, c );
    }

    href newindex = tableGetMetaNewIndex( env, table ); //check for meta event
    if( env->heap[newindex] == T_CLOSURE ) { //T_FUNC isn't callable, needs upvals & such
        bool isNew = false;

        isNew = tableGetByHeap( env, table, key ) == 0; //check if current value is nil

        if( isNew ) { //current value is nil
            href args[3]; // __newindex( myTable, key, value )
            args[0] = table;
            args[1] = key;

            if( isK( c ) ) { // c is a constant
                args[2] = kToHeap( env, indexK( c ) );
                if(args[2] == 0) return false; //failed to allocate space for constant
            } else { //c is a register
                args[2] = getRegister( env->luaStack, c );
            }

            return callWithArgs( env, newindex, args, 3 );
        }
    } //else no usable meta-event __newindex

    return tableRawSet( env->heap, env->maxHeapSize, table, key, value );
}

void returnRange( struct WorkerEnv* env, uchar a, uchar b ) {
    env->returnFlag = true;
    if( b == 0 ) {        //a to top of stack
        env->returnStart = getRegisterPos( env->luaStack, a );
        env->nReturn = getNRegisters( env-> luaStack );
    } else if( b == 1 ) { //no return values
        env->returnStart = 0;
        env->nReturn = 0;
    } else { //b >= 2, b-1 return values
        env->returnStart = getRegisterPos( env->luaStack, a );
        env->nReturn = b - 1;
    }
}

bool op_call( struct WorkerEnv* env, uchar a, ushort b, ushort c ) {
    
    if( env->returnFlag ) { //already called, handle result
        uint keep = 0;
        if( c == 0 ) {//top
            keep = env->nReturn;
        } else {
            keep = c - 1;
        }
        keep = keep < env->nReturn ? keep : env->nReturn;
        for(uint r = 0; r < keep; r++) //overwrites function ref on stack used to call
            if(!setRegister( env->luaStack, env->stackSize, a + r, env->luaStack[ env->returnStart + r ] ))
                return false; //can't imagine this happening, but checked anyway
        
        env->returnFlag = false;
        env->pc++;
        return true;
             // ===========================================================================================
    } else { // | New call
             // ===========================================================================================
        href func = getRegister( env->luaStack, a ); //should be closure or native func
        uint nargs = 0;
        if(b == 0) { //TOP
            nargs = getNRegisters( env-> luaStack ) - a;
        } else if(b == 1) {
            nargs = b-1;
        }

        uchar fType = env->heap[ func ];
        sref srefA = getRegisterPos( env->luaStack, a );

        if( fType == T_CLOSURE ) {
            uint fID = getClosureFunction( env, func );
            uint namedArgs = env->numParams[ fID ];
            bool isVararg = env->isVararg[ fID ];
            uint nVarargs = nargs - namedArgs;

            //stores old pc for return, fID = funciton index, func = closure
            if(!pushStackFrame( env->luaStack, env->stackSize, env->pc, fID, func, isVararg ? nVarargs : 0 )) return false;
            env->func = fID;
            env->pc = 0;

            sref argI = srefA + 1;
            for(uint i = 0; i < namedArgs; i++) { //copy function args to fixed registers
                href argRef = getRegister( env->luaStack, argI++ );
                if(!setRegister( env->luaStack, env->stackSize, i, argRef ))
                    return false;
            }

            if( isVararg ) {                         //if needed
                for(uint i = 0; i < nVarargs; i++) { //copy additonal args to varargs
                    href argRef = getRegister( env->luaStack, argI++ );
                    setVararg( env->luaStack, i, argRef );
                }
            }

            //next program step should continue in the new stack frame
            return true;

        } else if ( fType == T_NATIVE_FUNC ) {
            uint nativeID = getHeapInt( env->heap, func + 1 );
            bool ok = callNative( env, nativeID, srefA, nargs ); //should read args and put return values
            if( !ok ) return false;
            env->pc++;
            return true;
        } else {
            return false; //attempt to call TYPE
        }
    }
}

bool _readAsDouble( uchar* dataSource, uint start, double* result ) {
    if( dataSource[start] == T_INT ) {
        *result = (double)getHeapInt( dataSource, start +1 );
        return true;
    } else if( dataSource[start] == T_NUMBER ) {
        union doubleUnion d;
        uint hi = ((ulong)getHeapInt( dataSource, start + 1 )) << 32;
        uint lo = ((ulong)getHeapInt( dataSource, start + 5 )) & 0xFFFFFFFF;
        d.lbits = hi | lo;
        *result = d.dbits;
        return true;
    } else {
        return false;
    }
}

bool op_math( struct WorkerEnv* env, LuaInstruction instruction, OpCode op ) {
    uchar a = getA( instruction );
    ushort rkb = getB( instruction );
    ushort rkc = getC( instruction );

    double x, y, ans;
    if( isK( rkb ) ) {
        uint constStart; 
        uint constLen;
        getConstDataRange( env, indexK(rkb), &constStart, &constLen );
        if( constLen == 0 )
            return false; //const should have at minium 1 byte for type

        if( !_readAsDouble( env->constantsData, constStart, &x ))
            return false; //attempt to op with type
    } else {
        href val = getRegister( env->luaStack, rkb );
        if( !_readAsDouble( env->heap, val, &x ))
            return false; //attempt to op with type
    }

    if( OP_ADD <= op && op <= OP_POW ) { //math ops with 2 values
        if( isK( rkc ) ) {
            uint constStart; 
            uint constLen;
            getConstDataRange( env, indexK(rkc), &constStart, &constLen );
            if( constLen == 0 )
                return false; //const should have at minium 1 byte for type

            if( !_readAsDouble( env->constantsData, constStart, &y ))
                return false; //attempt to op with type
        } else {
            href val = getRegister( env->luaStack, rkc );
            if( !_readAsDouble( env->heap, val, &y ))
                return false; //attempt to op with type
        }
    }

    // R(A) := RK(B) op RK(C)
    switch( op ) {
        //2 values
        case OP_ADD:
            ans = x + y; 
            break;

        case OP_SUB:
            ans = x - y; 
            break;

        case OP_MUL:
            ans = x * y; 
            break;

        case OP_DIV:
            ans = x / y; 
            break;

        case OP_MOD:
            ans = fmod( x, y ); 
            break;

        case OP_POW:
            ans = pow( x, y );
            break;

        //1 value
        case OP_UNM:
            ans = -x; 
            break;

        default:
            return false;
    }
    
    href ansRef = allocateNumber( env->heap, env->maxHeapSize, ans );
    if( setRegister( env->luaStack, env->stackSize, a, ansRef ) ) {
        env->pc++;
        return true;
    }
    return false;
}

bool isTruthy( href value ) {
    return value >= TRUE_HREF; //[0] nil | [1,2] false | [3:4] true | [5+] heap values
}

bool doOp( struct WorkerEnv* env, LuaInstruction instruction ) {
    // LuaInstruction instruction = code[ codeIndexes[func] + pc ];
    OpCode op = getOpcode( instruction );
    switch( op ) {
        
        case OP_MOVE: { // R(A) := R(B)
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            return op_move( env, a, b );       // ok? pc++
        }

        case OP_LOADK: { // R(A) := Kst(Bx)
            uchar  a  = getA( instruction );
            ushort bx = getBx( instruction );
            return loadk( env, a, bx );        //ok? pc++
        }

        case OP_LOADKX: { return false; } //not implemented

        case OP_LOADBOOL: { // R(A) := (Bool)B; if(C) pc++ (skip next)
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            ushort c = getC( instruction );
            if(!setRegister( env->luaStack, env->stackSize, a, b == 0 ? 1 : 3 )) //Heap reserve: 0 nil, 1 false, 3 true
                return false;
            env->pc += c != 0 ? 2 : 1;
        }

        case OP_LOADNIL: { // R(A ... A+B) := nil
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            uint limit = a + b;
            for(uint r = a; r <= limit; r++) {
                if(!setRegister( env->luaStack, env->stackSize, r, 0 ))
                    return false;
            }
            env->pc++;
            return true;
        }

        case OP_GETUPVAL: { // R(A) := upval[B]
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            href closure = getStackClosure( env->luaStack );
            href upval = _getUpVal( env, closure, b );
            if(!setRegister( env->luaStack, env->stackSize, a, upval ))
                return false;
            env->pc++;
            return true;
        }

        //table is an upval
        case OP_GETTABUP: { // R(A) := UpValue[B][RK(C)]
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            ushort c = getC( instruction );
            return getTabUp( env, a, b, c );   //ok? pc++
        }

        //table is heap ref in a register
        case OP_GETTABLE: { //R(A) := R(B)[RK(C)]
            uchar  a = getA( instruction ); //target register
            ushort b = getB( instruction ); //table register
            ushort c = getC( instruction ); //RK(C) const/register table key
            return op_getTable( env, a, b, c ); //ok? pc++
        }

        case OP_SETTABUP: { //UpVal[A][RK(B)] := RK(C) | UpVal[ tableUpvalIndex ][ tableKey ] := tableValue
            uchar  a = getA( instruction ); //target upval
            ushort b = getB( instruction ); //RK(B) table key
            ushort c = getC( instruction ); //RK(C) value
            return op_settabup( env, a, b, c );
        }

        case OP_SETUPVAL: { //UpValue[B] := R(A)
            uchar  a = getA( instruction ); //value register
            ushort b = getB( instruction ); //upval index
            href closure = getStackClosure( env->luaStack );
            setClosureUpval( env, closure, b, getRegister( env->luaStack, a ) );
            return true;
        }

        case OP_SETTABLE: { //R(A)[RK(B)] := RK(C)
            uchar  a = getA( instruction ); //target register
            ushort b = getB( instruction ); //RK(B) table key
            ushort c = getC( instruction ); //RK(C) value
            return op_settable( env, a, b, c );
        }

        case OP_NEWTABLE: { // R(A) := {} (size = B,C)
            uchar a = getA( instruction );
            int arraySize = floatingPointByte( getB( instruction ) );
            int hashSize  = floatingPointByte( getC( instruction ) );

            href table = newTable( env->heap, env->maxHeapSize );
            if(table == 0) return false;

            if( arraySize > 0 ) {
                if( tableCreateArrayPartWithSize( env->heap, env->maxHeapSize, table, arraySize ) == 0 )
                    return false;
            }

            if( hashSize > 0 ) {
                if( tableCreateHashedPartWithSize( env->heap, env->maxHeapSize, table, hashSize ) == 0 )
                    return false;
            }
            
            if(!setRegister( env->luaStack, env->stackSize, a, table ))
                return false;
            env->pc++;
            return true;
        }

        case OP_SELF: { //R(A+1) := R(B);   R(A) := R(B)[RK(C)]
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            ushort c = getC( instruction );

            if( !setRegister( env->luaStack, env->stackSize, a + 1, getRegister( env->luaStack, b ) ) )
                return false;
            
            return op_getTable( env, a, b, c ); // ok? pc++
        }

        case OP_CALL: {
            uchar a = getA( instruction );
            ushort b = getB( instruction );
            ushort c= getC( instruction );
            return op_call( env, a, b, c );    //if(native || env.returnFlag && ok) pc++;
        }

        case OP_RETURN: { // R(A) := Kst(Bx)
            uchar a = getA( instruction );
            ushort b = getB( instruction );
            returnRange( env, a, b );
            env->pc = getPreviousPC( env->luaStack );
            popStackFrame( env->luaStack );
            env->func = getCurrentFunctionFromStack( env->luaStack ); //frame popped, don't care about pc++
            return true;
        }

        case OP_ADD: 
        case OP_SUB:
        case OP_MUL:
        case OP_DIV:
        case OP_MOD:
        case OP_POW:
        case OP_UNM:
        { // R(A) := RK(B) op RK(C)
            return op_math( env, instruction, op ); // ok? pc++
        }

        case OP_NOT: {
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            href val = getRegister( env->luaStack, b );
            //2 is constant ref for 
            if( setRegister( env->luaStack, env->stackSize, a, isTruthy( val ) ? FALSE_HREF : TRUE_HREF ) ) {
                env->pc++;
                return true;
            }
            return false;
        }

        case OP_LEN: { // R(A) := # R(B)
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            href val = getRegister( env->luaStack, b );

            switch( env->heap[ val ] ) {
                case T_STRING: {
                    uint length = getHeapInt( env->heap, val+1 );
                    href r = allocateInt( env->heap, env->maxHeapSize, length );
                    if( r == 0 ) return false;
                    if( setRegister( env->luaStack, env->stackSize, a, r ) ) {
                        env->pc++;
                        return true;
                    }
                    return false;
                }
                case T_TABLE: {
                    string metaEventName = "__len";
                    href metaEvent = tableGetMetaEvent( env, val, metaEventName );
                    if( env->heap[metaEvent] == T_CLOSURE ) {
                        href args[1];
                        args[0] = val;
                        if( callWithArgs( env, metaEvent, args, 1 )) {
                            if( env->returnFlag ) {
                                href r1 = env->luaStack[ env->returnStart ];
                                if(setRegister( env->luaStack, env->stackSize, a, r1 )) {
                                    env->pc++;
                                    return true;
                                }
                            }
                        }
                        return false;
                    } else {
                        uint length = tableLen( env->heap, val );
                        href r = allocateInt( env->heap, env->maxHeapSize, length );
                        if( r == 0 ) return false; //out of memory
                        if( setRegister( env->luaStack, env->stackSize, a, r )) {
                            env->pc++;
                            return true;
                        }
                        return false;
                    }
                }
                default: {
                    return false; //attempt to get length of type
                }
            }
        }

        case OP_CONCAT: { // R(A) : = R(B).. ... ..R(C)
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            ushort c = getC( instruction );

            //todo length of each type as a string
            return false;
        }

        case OP_JMP: { // pc += sBx; if (A) "close" all upvals >= R(A-1)
            uchar a = getA( instruction );
            int  sBx = getsBx( instruction ); //signed, (B & C)
            env->pc += sBx + 1;

            //no closable resources like files
            return true;
        }


        case OP_EQ: // if ((RK(B) == RK(C)) ~= A) then pc++
        case OP_LT:        //        A B C   if ((RK(B) <  RK(C)) ~= A) then pc++           
        case OP_LE:        //        A B C   if ((RK(B) <= RK(C)) ~= A) then pc++           
        case OP_TEST:      //      A C     if not (R(A) <=> C) then pc++                  
        case OP_TESTSET:   //   A B C   if (R(B) <=> C) then R(A) := R(B) else pc++    
        case OP_TAILCALL:  //  A B C   return R(A)(R(A+1), ... ,R(A+B-1))             
        case OP_FORLOOP:   //   A sBx   R(A)+=R(A+2);
                           //     if R(A) <?= R(A+1) then { pc+=sBx; R(A+3)=R(A) }
        case OP_FORPREP:   //   A sBx   R(A)-=R(A+2); pc+=sBx                          
        case OP_TFORCALL:  //  A C     R(A+3), ... ,R(A+2+C) := R(A)(R(A+1), R(A+2)); 
        case OP_TFORLOOP:  //  A sBx   if R(A+1) ~= nil then { R(A)=R(A+1); pc += sBx }
        case OP_SETLIST:   //   A B C   R(A)[(C-1)*FPF+i] := R(A+i), 1 <= i <= B       
        case OP_CLOSURE:   //   A Bx    R(A) := closure(KPROTO[Bx])                    
        case OP_VARARG:    //    A B     R(A), R(A+1), ..., R(A+B-2) = vararg           
        case OP_EXTRAARG:  //  Ax      extra (larger) argument for previous opcode    

        default:
            return false;
    }
}

bool stepProgram( struct WorkerEnv* env ) {
    LuaInstruction instruction = env->code[ env->codeIndexes[ env->func ] + env->pc ];

    return doOp( env, instruction );
}

bool call( struct WorkerEnv* env, href closure ) {
    href args[0];
    return callWithArgs( env, closure, args, 0 );
}
bool callWithArgs( struct WorkerEnv* env, href closure, href* args, uint nargs ) {
    env->func = getClosureFunction( env, closure );

    uint namedArgs = env->numParams[ env->func ];
    bool isVararg = env->isVararg[ env->func ];
    uint nVarargs = nargs - namedArgs;

    if(!pushStackFrame( env->luaStack, env->stackSize, env->pc, env->func, closure, nVarargs ))
        return false;

    if( nargs > 0 ) {
        for( uint n = 0; n < namedArgs; n++ ) {
            if(!setRegister( env->luaStack, env->stackSize, n, args[n] ))
                return false;
        }
        if( isVararg ) {
            uint a = namedArgs;
            for(uint v = 0; v < nVarargs; v++) {
                setVararg( env->luaStack, v, args[a] );
            }
        }
    }
    
    env->returnFlag = false;
    sref callFrame = env->luaStack[0];

    while( callFrame <= env->luaStack[0] ) { //wait till popped
        if(!stepProgram( env )) {
            return false;
        } 
    }

    return true;
}