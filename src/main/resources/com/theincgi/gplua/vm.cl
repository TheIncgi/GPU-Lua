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

bool loadk( struct WorkerEnv* env, uchar reg, uint index ) { //TODO cache hrefs, preload?
    uint constStart; 
    uint constLen;
    getConstDataRange( env, index, &constStart, &constLen );

    if( constLen == 0 )
        return false; //const should have at minium 1 byte for type

    href k = allocateHeap( env->heap, env->maxHeapSize, constLen );
    if( k == 0 ) { return false; } //TODO err OOM

    uint limit = constStart + constLen;
    for( uint r = constStart, w = 0; r < limit; r++, w++ ) {
        env->heap[ k + w ] = env->constantsData[ r ];
    }
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

void returnRange( struct WorkerEnv* env, uchar a, uchar b) {
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

bool op_call( struct WorkerEnv* env, uchar a, ushort b, ushort c) {
    
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


bool doOp( struct WorkerEnv* env, LuaInstruction instruction ) {
    // LuaInstruction instruction = code[ codeIndexes[func] + pc ];
    OpCode op = getOpcode( instruction );
    switch( op ) {
        
        case OP_LOADK:{ // R(A) := Kst(Bx)
            uchar a = getA( instruction );
            ushort bx = getBx( instruction );
            return loadk( env, a, bx );        //ok? pc++
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

        default:
            return false;
    }
}

bool stepProgram( struct WorkerEnv* env ) {
    LuaInstruction instruction = env->code[ env->codeIndexes[ env->func ] + env->pc ];

    return doOp( env, instruction );
}

bool call( struct WorkerEnv* env, href closure ) {
    env->func = getClosureFunction( env, closure );

    if(!pushStackFrame( env->luaStack, env->stackSize, env->pc, env->func, closure, 0 ))
        return false;
    
    env->returnFlag = false;
    sref callFrame = env->luaStack[0];

    while( callFrame <= env->luaStack[0] ) { //wait till popped
        if(!stepProgram( env )) {
            return false;
        } 
    }

    return true;
}