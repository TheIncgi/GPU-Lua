#include"vm.h"
#include"common.cl"
#include"closure.h"
#include"table.h"
// #include"stackUtils.h"
#include"luaStack.h"
#include"heapUtils.h"
#include"opUtils.cl"
#include"types.cl"
#include"natives.cl"
#include"comparison.h"
#include"errorMsg.cl"
#include"upval.h"

void getConstDataRange( struct WorkerEnv* env, uint index, uint* start, uint* len ) {
    uint fConstStart = env->constantsPrimaryIndex[ env->func * 2     ];
    uint fConstLen   = env->constantsPrimaryIndex[ env->func * 2 + 1 ];

    uint secondaryIndex = fConstStart + index * 2;
    //if secondaryIndex > >= len return 0, 1 indexed ? 0 indexed?
    *start = env->constantsSecondaryIndex[ secondaryIndex     ];
    *len   = env->constantsSecondaryIndex[ secondaryIndex + 1 ];
}

bool op_move( struct WorkerEnv* env, uchar dstReg, ushort srcReg ) {
    if(cls_setRegister( env, dstReg, cls_getRegister( env, srcReg ) )) {
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
    if( cls_setRegister( env, reg, k ) ) {
        env->pc++;
        return true;
    } else {
        freeHeap( env->heap, env->maxHeapSize, k, false ); //TODO return href instead?
        return false;
    }
}

//deprecated
href _getUpVal( struct WorkerEnv* env, href closureRef, uint upval ) {
    if( closureRef == 0 ) return 0;
    return getClosureUpval( env, closureRef, upval );
}

// GETTABLE A B C   R(A) := R(B)[RK(C)]       //table comes from heap
// GETTABUP A B C   R(A) := UpValue[B][RK(C)] //table comes from upval

//the table is an upval
bool getTabUp( struct WorkerEnv* env, uchar reg, uint upvalIndexOfTable, uint tableKey ) {
    href closure = cls_getClosure( env );
    if( closure == 0 ) return false;
    
    href table = getClosureUpval( env, closure, upvalIndexOfTable );
    if( table == 0 ) return false;

    if( env->heap[table] == T_UPVAL ) {
        table = getUpvalValue( env, table );
    }

    if( env->heap[ table ] != T_TABLE )
        return false; //attempt to index TYPE
    
    href value = 0;
    if( isK(tableKey) ) { //use constant
        int index = indexK( tableKey );
        value = tableGetByConst( env, table, index );
    } else { //use register
        href key = cls_getRegister( env, (uchar)tableKey );
        value = tableGetByHeap( env, table, key );
    }

    env->pc++;
    cls_setRegister( env, reg, value );
    return true;
}

//the table is a register value
bool op_getTable( struct WorkerEnv* env, uchar destReg, ushort tableReg, ushort tableKey) { //FIXME
    href table = cls_getRegister( env, tableReg );
    if( table == 0 ) return false; //attempt to index nil

    if( env->heap[ table ] != T_TABLE )
        return false; //attempt to index TYPE

    href value = 0;
    if( isK( tableKey )) {
        int index = indexK( tableKey );
        value = tableGetByConst( env, table, index );
    } else {
        href key = cls_getRegister( env, (uchar)tableKey );
        value = tableGetByHeap( env, table, key );
    }

    env->pc++;
    cls_setRegister( env, destReg, value );
    return true;
}

//set table upval
// UpVal[A][RK(B)] := RK(C) | UpVal[ tableUpvalIndex A ][ tableKey B ] := tableValue C
bool op_settabup( struct WorkerEnv* env, uchar a, ushort b, ushort c ) { 
    if( env->returnFlag ) {
        env->pc++;
        env->returnFlag = false;
        return true;
    }
    href closure = cls_getClosure( env ); //active function
    if( closure == 0 ) return false;
    href table = getClosureUpval( env, closure, a );
    
    if( env->heap[table] == T_UPVAL ) {
        table = getUpvalValue( env, table );
    }

    if( env->heap[table] != T_TABLE ) return false; //attempt to assign to TYPE

    char result = _settable( env, table, b, c );
    if( result == 1 ) { 
        env->pc++;
        return true;
    } else if( result == -1 ) {
        return true; //__newindex call triggered
    } else {
        return false;
    }
}

//R(A)[RK(B)] := RK(C) | Registers[ A ][ tableKey B ] := tableValue C
bool op_settable( struct WorkerEnv* env, uchar a, ushort b, ushort c ) {
    if( env->returnFlag ) {
        env->pc++;
        env->returnFlag = false;
        return true;
    }

    href table = cls_getRegister( env, a );
    if( env->heap[table] != T_TABLE ) return false; //attempt to assign to TYPE

    char result = _settable( env, table, b, c );
    if( result == 1 ) { 
        env->pc++;
        return true;
    } else if( result == -1 ) {
        return true; //__newindex call triggered
    } else {
        return false;
    }
}

//shared logic of settabup and settable
//0 fail with err
//-1 __newindex call
//1 set
char _settable( struct WorkerEnv* env, href table, ushort b, ushort c ) {
    href key, value;

    if( isK( b ) ) {
        key = kToHeap( env, indexK( b ));
        if( key == 0 ) return 0; //failed to allocate key to heap or attempt to index using nil
    } else {
        key = cls_getRegister( env, b );
        if( key == 0 ) return 0; //attempt to index using nil
    }

    if( isK( c )) {
        value = kToHeap( env, indexK( c ));
        if( value == 0 ) return 0; //failed to allocate value to heap
    } else {
        value = cls_getRegister( env, c );
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
                if(args[2] == 0) return 0; //failed to allocate space for constant
            } else { //c is a register
                args[2] = cls_getRegister( env, c );
            }

            setupCallWithArgs( env, newindex, args, 3 ); //queue call, catch results after return
            return -1;
        }
    } //else no usable meta-event __newindex

    if(tableRawSet( env, table, key, value ))
        return 1;
    return 0;
}

void returnRange( struct WorkerEnv* env, uchar a, uchar b ) {
    env->returnFlag = true;
    if( b == 0 ) {        //a to top of stack
        env->returnStart = cls_getRegisterHref( env, a );
        env->nReturn = cls_nRegisters( env );
    } else if( b == 1 ) { //no return values
        env->returnStart = 0;
        env->nReturn = 0;
    } else { //b >= 2, b-1 return values
        env->returnStart = cls_getRegisterHref( env, a );
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
        for(uint r = 0; r < keep; r++) {//overwrites function ref on stack used to call
            printf("op_call#return cls_setRegister( env, %d, %d )\n", a + r, getReturn( env, r ));
            if(!cls_setRegister( env, a + r, getReturn( env, r ) ))
                return false; //can't imagine this happening, but checked anyway
        }
        
        env->returnFlag = false; //must be set after getReturn( env, r )
        env->pc++;
        return true;
             // ===========================================================================================
    } else { // | New call
             // ===========================================================================================
        href func = cls_getRegister( env, a ); //should be closure or native func
        uint nargs = 0;
        if(b == 0) { //TOP
            nargs = cls_nRegisters( env ) - a;
        } else if(b == 1) {
            nargs = b-1;
        }

        uchar fType = env->heap[ func ];
        href hrefA = cls_getRegisterHref( env, a ); //function pos, a+1 is arg 1

        if( fType == T_CLOSURE ) {
            uint fID = getClosureFunction( env, func );
            uint namedArgs = env->numParams[ fID ];
            bool isVararg = env->isVararg[ fID ];
            uint nVarargs = nargs - namedArgs;

            //stores old pc for return, fID = funciton index, func = closure
            href newStack = allocateLuaStack( env, env->luaStack, env->pc, func, isVararg ? nVarargs : 0 );
            if( newStack == 0 ) return false;
            env->func = fID;
            env->pc = 0;
            env->luaStack = newStack;

            href argI = hrefA + 1;
            for(uint i = 0; i < namedArgs; i++) { //copy function args to fixed registers
                href argRef = getHeapInt( env->heap, argI );
                argI += REGISTER_SIZE;
                if(!cls_setRegister( env, i, argRef ))
                    return false;
            }

            if( isVararg ) {                         //if needed
                for(uint i = 0; i < nVarargs; i++) { //copy additonal args to varargs
                    href argRef = getHeapInt( env->heap, argI );
                    argI += REGISTER_SIZE;
                    cls_setVararg( env, i, argRef );
                }
            }

            //next program step should continue in the new stack frame
            return true;

        } else if ( fType == T_NATIVE_FUNC ) {
            uint nativeID = getHeapInt( env->heap, func + 1 );
            bool ok = callNative( env, nativeID, hrefA, nargs ); //should read args and put return values
            if( !ok ) return false;
            env->pc++;
            return true;
        } else {
            return false; //attempt to call TYPE
        }
    }
}

bool op_tailCall( struct WorkerEnv* env, uchar a, ushort b ) {
    
    if( env->returnFlag ) { //already called, handle result
        uint keep = 0;
        
        //c is always 0 for tailcall
        keep = env->nReturn;
        
        keep = keep < env->nReturn ? keep : env->nReturn;
        for(uint r = 0; r < keep; r++) //overwrites function ref on stack used to call
            if(!cls_setRegister( env, a + r, getReturn( env, r ) ))
                return false; //can't imagine this happening, but checked anyway
        
        env->returnFlag = false;
        env->pc++;
        return true;
             // ===========================================================================================
    } else { // | New tail call
             // ===========================================================================================
        href func = cls_getRegister( env, a ); //should only be closure
        uint nargs = 0;
        if(b == 0) { //TOP
            nargs = cls_nRegisters( env ) - a;
        } else if(b == 1) {
            nargs = b-1;
        }

        uchar fType = env->heap[ func ];
        href hrefA = cls_getRegisterHref( env, a );

        if( fType == T_CLOSURE ) {
            uint fID = getClosureFunction( env, func );
            uint namedArgs = env->numParams[ fID ];
            bool isVararg = env->isVararg[ fID ];
            uint nVarargs = nargs - namedArgs;

            //reuse current frame level | fID = function index, func = closure
            href redefined = redefineLuaStack( env, func, isVararg ? nVarargs : 0 );
            if( redefined == 0 ) return false;

            href argI = hrefA + 1;
            for(uint i = 0; i < namedArgs; i++) { //copy function args to fixed registers
                href argRef = getHeapInt( env->heap, argI );
                argI += REGISTER_SIZE;
                if(!cls_setRegister( env, i, argRef ))
                    return false;
            }

            if( isVararg ) {                         //if needed
                for(uint i = 0; i < nVarargs; i++) { //copy additonal args to varargs
                    href argRef = getHeapInt( env->heap, argI );
                    argI += REGISTER_SIZE;
                    cls_setVararg( env, i, argRef );
                }
            }

            env->pc = 0;
            env->func = getClosureFunction( env, func );
            env->luaStack = redefined; //no allocations occur during arg copying, so shouldn't have any rare GC issues here
            //next program step should continue in the new stack frame
            return true;

        } else if ( fType == T_NATIVE_FUNC ) {
            return op_call( env, a, b, 0 );
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
    uchar    a = getA( instruction );
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
        href val = cls_getRegister( env, rkb );
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
            href val = cls_getRegister( env, rkc );
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
    if( cls_setRegister( env, a, ansRef ) ) {
        env->pc++;
        return true;
    }
    return false;
}

bool isTruthy( href value ) {
    return value >= TRUE_HREF; //[0] nil | [1,2] false | [3:4] true | [5+] heap values
}

//TODO switch to void, error status checked via function now
bool doOp( struct WorkerEnv* env, LuaInstruction instruction ) {
    // LuaInstruction instruction = code[ codeIndexes[func] + pc ];

    OpCode op = getOpcode( instruction );

    printf("Op: %d PC: %d Depth: %d ReturnFlag: %d", op, env->pc, cls_getDepth( env ), env->returnFlag?1:0);
    if(env->returnFlag)
        printf(" [%d, %d]", env->returnStart, env->nReturn );
    printf("\n");

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
            if(!cls_setRegister( env, a, b == 0 ? FALSE_HREF : TRUE_HREF )) //Heap reserve: 1 false, 3 true
                return false;
            env->pc += c != 0 ? 2 : 1;
        }

        case OP_LOADNIL: { // R(A ... A+B) := nil
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            uint limit = a + b;
            for(uint r = a; r <= limit; r++) {
                if(!cls_setRegister( env, r, 0 )) //NIL_HREF is 0
                    return false;
            }
            env->pc++;
            return true;
        }

        case OP_GETUPVAL: { // R(A) := upval[B]
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            href closure = cls_getClosure( env );
            href upval = getClosureUpval( env, closure, b );
            
            if( !cls_setRegister( env, a, getUpvalValue( env, upval )) ) {
                return false;
            }

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
            href closure = cls_getClosure( env );
            href upval = getClosureUpval( env, closure, b );
            if( !setUpvalValue( env, upval, cls_getRegister( env, a ) )) {
                return false;
            }
            env->pc++;
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
            
            if(!cls_setRegister( env, a, table ))
                return false;
            env->pc++;
            return true;
        }

        case OP_SELF: { //R(A+1) := R(B);   R(A) := R(B)[RK(C)]
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            ushort c = getC( instruction );

            if( !cls_setRegister( env, a + 1, cls_getRegister( env, b ) ) )
                return false;
            
            return op_getTable( env, a, b, c ); // ok? pc++
        }

        case OP_CALL: {
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            ushort c = getC( instruction );
            return op_call( env, a, b, c );    //if(native || env.returnFlag && ok) pc++;
        }

        case OP_RETURN: { // R(A) := Kst(Bx)
            uchar a = getA( instruction );
            ushort b = getB( instruction );
            returnRange( env, a, b );
            ls_pop( env ); //pc, func, env->luaStack all updated
            //frame popped, don't care about pc++
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
            href val = cls_getRegister( env, b );
            //2 is constant ref for 
            if( cls_setRegister( env, a, isTruthy( val ) ? FALSE_HREF : TRUE_HREF ) ) {
                env->pc++;
                return true;
            }
            return false;
        }

        case OP_LEN: { // R(A) := # R(B)
            uchar  a = getA( instruction );

            if( env->returnFlag ) {
                href r1 = getReturn( env, 0 );
                if(!cls_setRegister( env, a, r1 )) {
                    return false;
                }
                env->pc++;
                return true;
            }

            ushort b = getB( instruction );
            href val = cls_getRegister( env, b );

            switch( env->heap[ val ] ) {
                case T_STRING: {
                    uint length = getHeapInt( env->heap, val+1 );
                    href r = allocateInt( env->heap, env->maxHeapSize, length );
                    if( r == 0 ) return false;
                    if( cls_setRegister( env, a, r ) ) {
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
                        if( setupCallWithArgs( env, metaEvent, args, 1 )) {
                            return true; //continue on return
                        }
                        return false;
                    } else {
                        uint length = tableLen( env->heap, val );
                        href r = allocateInt( env->heap, env->maxHeapSize, length );
                        if( r == 0 ) return false; //out of memory
                        if( cls_setRegister( env, a, r )) {
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


        case OP_EQ: // ==
        case OP_LT: // <
        case OP_LE: // <=
        {// if ((RK(B) OP RK(C)) ~= A) then pc++
            if( env->returnFlag ) {
                if(env->nReturn >= 1) {
                    bool result = isTruthy( getReturn( env, 0 ) );
                    env->pc += result ? 1 : 2;  //skips next if not eq
                } else { //treat as false
                    env->pc += 2;
                }
                env->returnFlag = false;
            }

            uchar* dataSourceA;
            uchar* dataSourceB;
            href indexA, indexB;

            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            ushort c = getC( instruction );
            
            if( isK( b ) ) {
                dataSourceA = env->constantsData;
                uint _;
                getConstDataRange( env, indexK( b ), &indexA, &_ );
            } else {
                dataSourceA = env->heap;
                indexA = cls_getRegister( env, b );
            }

            if( isK( c ) ) {
                dataSourceB = env->constantsData; //warning: incompatible pointer to integer conversion assigning to 'uchar' (aka 'unsigned char') from '__generic uchar *__generic' (aka '__generic unsigned char *__generic')
                uint _;
                getConstDataRange( env, indexK( c ), &indexB, &_ );
            } else {
                dataSourceB = env->heap;          // warning: incompatible pointer to integer conversion assigning to 'uchar' (aka 'unsigned char') from '__generic uchar *__generic' (aka '__generic unsigned char *__generic')
                indexB = cls_getRegister( env, c );
            }

            bool result;
            switch( op ) {
                case OP_EQ:
                    result = heapEquals( env, dataSourceA, indexA, dataSourceB, indexB ) == ((a == 0) ? false : true);
                    break;
                case OP_LT:
                    result = compareLessThan( env, dataSourceA, indexA, dataSourceB, indexB ) == ((a == 0) ? false : true);
                    break;
                case OP_LE:
                    result = compareLessThanOrEqual( env, dataSourceA, indexA, dataSourceB, indexB ) == ((a == 0) ? false : true);
                    break;
                default:
                    return false;
            } 
            
            return true;
        }
        
        case OP_TEST: {      //     TEST        A C     if (boolean(R(A)) != C) then PC++
            uchar  a = getA( instruction );
            bool   c = getC( instruction ) != 0;
            bool val = isTruthy(cls_getRegister( env, a ));
            env->pc += (val != c) ? 2 : 1;
            return true;
        }

        case OP_TESTSET: {  //   A B C   if (boolean(R(B)) != C) then R(A) := R(B) else pc++    
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            bool   c = getC( instruction ) != 0;
            bool val = isTruthy( cls_getRegister( env, b ) );
            if( val != c ) {
                if(!cls_setRegister( env, a, cls_getRegister( env, b ))) {
                    throwSO( env );
                    return false;
                }
                env->pc++;
                return true;
            } else {
                env->pc += 2;
                return true;
            }
        }

        case OP_TAILCALL: {  //  A B C   return R(A)(R(A+1), ... ,R(A+B-1))      
            uchar  a = getA( instruction );
            ushort b = getB( instruction ); //b-1 == arg count, -1 means till top of frame
            return op_tailCall( env, a, b ); //if return flag, pc++
        }
        
        case OP_FORPREP: {  //R(A)-=R(A+2); pc+=sBx
        
            uchar  a = getA( instruction );
            int  sBx = getsBx( instruction );
            //R(a) -> init val / internal loop var
            //R(a+1) -> limit
            //R(a+2) -> step
            //R(a+3) -> ext loop var
            
            //R(A) = R(A) - R(A+2) //init - step
            href initRef = cls_getRegister( env, a   );
            href stepRef = cls_getRegister( env, a+2 );
            double initVal, stepVal; //anything below 2^53 has a whole number representation, well past 2^32 from int
            _readAsDouble( env->heap, initRef, &initVal );
            _readAsDouble( env->heap, stepRef, &stepVal ); 
            href shiftedRef = allocateNumber( env->heap, env->maxHeapSize, initVal - stepVal );
            if( shiftedRef == 0 ) { throwOOM( env ); return false; }
            if( !cls_setRegister( env, a, shiftedRef ) ) { throwSO( env ); return false; }

            //pc += sBx +1
            env->pc += sBx + 1;
            return true;
        }

        case OP_FORLOOP: {   //   A sBx   R(A)+=R(A+2); //increment internal
                            //     if R(A) <?= R(A+1) then { pc+=sBx; R(A+3)=R(A) }
            
            // increment internal loop var + step size
            // if internal var <= limit
            //    pc += sbx + 1? 
            //    external = internal
            // TODO check logic
            uchar a = getA( instruction );
            int sBx = getsBx( instruction );

            href internalRef = cls_getRegister( env, a );
            href limitRef    = cls_getRegister( env, a + 1 );
            href stepRef     = cls_getRegister( env, a + 2 );

            double internal, limit, step;
            _readAsDouble( env->heap, internalRef, &internal );
            _readAsDouble( env->heap,    limitRef, &limit );
            
            internal += step;
            
            if( internal <= limit ) {
                //allocate and re-assign internal counter to register
                internalRef = allocateNumber( env->heap, env->maxHeapSize, internal );
                cls_setRegister( env, a, internalRef );

                //set external var used in for loop
                cls_setRegister( env, a + 3, internalRef); //nothing will modify the value on the heap, safe to copy
                
                //jump back to the start
                env->pc += sBx;
            }
            env->pc++;
            return true;
        }        

        case OP_TFORCALL: { //  A C     R(A+3), ... ,R(A+2+C) := R(A)(R(A+1), R(A+2)); 
            uchar  a = getA( instruction );
            ushort c = getC( instruction );

            if( env->returnFlag ) {
                for( uint r = 0; r < c; r++ ) {
                    href val = getReturn( env, r ); //nil : return value
                    if(!cls_setRegister( env, a + 3 + r, val ))
                        return false;
                    
                    env->returnFlag = false;
                    env->pc++;
                    return true;
                }
            }

            //R(A) itterator func
            //R(A+1) state
            //R(A+2) control variable (internal only)
            //R(A+3) lool vars (external), C refers to count, must always be at least 1 var

            //call R(A) with ( state, controlVar )
            //results are returned to loop vars R(A+3), ... R(A+2+C)

            href closure = cls_getRegister( env, a     );
            href   state = cls_getRegister( env, a + 1 );
            href ctrlVar = cls_getRegister( env, a + 2 );

            href args[2];
            args[0] = state;
            args[1] = ctrlVar;
            if(!setupCallWithArgs( env, closure, args, 2 ))
                return false;

            return true;
        }
        // case OP_TFORLOOP: { //  A sBx   if R(A+1) ~= nil then { R(A)=R(A+1); pc += sBx }
        //     uchar a = getA( instruction );
        //     int sBx = getsBx( instruction );

        //     href test = cls_getRegister( env, a + 1 );
        //     if( test != 0 ) {
        //         href nxt = cls_getRegister( env, a + 1 );
        //         cls_setRegister( env, a, nxt );
        //         env->pc += sBx;
        //     }
        //     env->pc++;
        // }
        case OP_SETLIST: {   //   A B C   R(A)[(C-1)*FPF+i] := R(A+i), 1 <= i <= B       
            uchar  a = getA( instruction ); //table, a+1... = values
            ushort b = getB( instruction ); //nElements
            ushort c = getC( instruction ); //blockNum (batch of values)

            href tableRef = cls_getRegister( env, a );

            uint offset = (c-1) * LFIELDS_PER_FLUSH;
            
            //reused vars to avoid repeate lookup
            href arrayPart;
            uint aSize, aCap;
            for(ushort i = 1; i <= b; i++) { //[1, b] not [0, b)
                href value = cls_getRegister( env, a + i );
                if( !tableSetList( env, tableRef, &arrayPart, &aSize, &aCap, offset + i, value ) )
                    return false;
            }
            return true;
        }

        case OP_CLOSURE: {  //   A Bx    R(A) := closure(KPROTO[Bx])                    
            uchar a = getA( instruction ); //register
            uint bx = getBx( instruction ); //proto id

            // uint funcID = //TODO use protoLengths to determine correct function id and upal ranges

            uint upvalRangeStart = env->upvalsIndex[ bx * 2 ];
            uint upvalRangeLen = env->upvalsIndex[ bx * 2  + 1 ];

            href closure = createClosure( env, bx, env->globals, upvalRangeLen / 2 );

            //FIXME enabling for stackOnlyClosure test causes most of the heap to disapear when dumped (probably wrote outside a tagged area?)
            for( uint i = 0; i < upvalRangeLen; i+=2 ) {
                uint func = bx + 1; //seems 0 isn't used
                bool onStack = env->upvals[ upvalRangeStart + i     ];
                uchar index  = env->upvals[ upvalRangeStart + i + 1 ]; //or register

                href stackRef = env->luaStack;
                uint upvalRef = upvalRangeStart;
                
                while( !onStack ) {
                    func = ls_getFunction( env, stackRef );
                    upvalRef = env->upvalsIndex[ func * 2 ];
                    onStack = env->upvals[ upvalRef + index * 2     ];
                    index   = env->upvals[ upvalRef + index * 2 + 1 ];
                    stackRef = ls_getPriorStack( env, stackRef );
                    if( stackRef == 0 )
                        return false;
                }
                href up = allocateUpval( env, stackRef, index );
                if( up == 0 )
                    return false;
                
                setClosureUpval( env, closure, i, up );
            } 

            cls_setRegister( env, a, closure );
            env->pc++;
            return true;
        }

        case OP_VARARG: {   //    A B     R(A), R(A+1), ..., R(A+B-2) = vararg           
            uchar  a = getA( instruction );
            ushort b = getB( instruction );
            uint nRegisters;
            if( b == 0 ) {
                b = cls_nVarargs( env );
            } else {
                nRegisters = b - 1;
            }

            for( uint i = 0; i < nRegisters; i++ ) {
                href value = cls_getVararg( env, i );
                if( !cls_setRegister( env, a + i, value ) )
                    return false;
            }
            return true;
        }

        case OP_EXTRAARG: //  Ax      extra (larger) argument for previous opcode    
        default: {
            throwUnexpectedBytecodeOp( env, op );
            return false;
        }
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

bool setupCallWithArgs( struct WorkerEnv* env, href closure, href* args, uint nargs ) {
    if( env->heap[closure] != T_CLOSURE ) {
        throwCall( env, env->heap[closure] );
        return false;
    }
    
    env->func = getClosureFunction( env, closure );

    uint namedArgs = env->numParams[ env->func ];
    bool isVararg = env->isVararg[ env->func ];
    uint nVarargs = nargs - namedArgs;

    href ls = allocateLuaStack( env, env->luaStack, env->pc, closure, nVarargs );
    if( ls == 0 ) return false;
    ls_push( env, ls );

    if( nargs > 0 ) {
        for( uint n = 0; n < namedArgs; n++ ) {
            if(!cls_setRegister( env, n, args[n] ))
                return false;
        }
        if( isVararg ) {
            uint a = namedArgs;
            for(uint v = 0; v < nVarargs; v++) {
                cls_setVararg( env, v, args[a] );
            }
        }
    }
    
    env->returnFlag = false;
    
    return true;
}

bool callWithArgs( struct WorkerEnv* env, href closure, href* args, uint nargs ) {
    if( !setupCallWithArgs(env, closure, args, nargs) )
        return false;
    
    uint callDepth = cls_getDepth( env );

    while( (env->luaStack != 0) && (callDepth <= cls_getDepth( env )) ) { //wait till popped
        if( (!stepProgram( env )) || hasError( env )) {
            return false;
        } 
    }
    
    return true;
}