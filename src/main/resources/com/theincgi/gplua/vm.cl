#include"vm.h"
#include"common.cl"
#include"closure.h"
#include"stackUtils.h"
#include"heapUtils.h"
#include"opUtils.cl"

void getConstDataRange( struct WorkerEnv* env, uint index, uint* start, uint* len ) {
    uint fConstStart = env->constantsPrimaryIndex[ env->func * 2     ];
    uint fConstLen   = env->constantsPrimaryIndex[ env->func * 2 + 1 ];

    uint secondaryIndex = fConstStart + index;
    //if secondaryIndex > >= len return 0, 1 indexed ? 0 indexed?
    *start = env->constantsSecondaryIndex[ secondaryIndex * 2     ];
    *len   = env->constantsSecondaryIndex[ secondaryIndex * 2 + 1 ];
}

bool loadk( struct WorkerEnv* env, uchar reg, uint index ) { //TODO cache hrefs, preload?
    if(index == 0) return false;
    index = index - 1;

    uint constStart; 
    uint constLen;
    getConstDataRange( env, index, &constStart, &constLen );

    href k = allocateHeap( env->heap, env->maxHeapSize, constLen );
    if( k == 0 ) { env->error[2] = 1; return false; } //TODO err OOM

    uint limit = constStart + constLen;
    for( uint r = constStart, w = 0; r < limit; r++, w++ ) {
        env->heap[ k + w ] = env->constantsData[ r ];
    }
    //nil bool number str
    if( setRegister( env->luaStack, env->stackSize, reg, k ) ) {
        return true;
    } else {
        freeHeap( env->heap, env->maxHeapSize, k, false ); //TODO return href instead?
        return false;
    } 
}

href getUpVal( struct WorkerEnv* env, href closureRef, uint upval ) {
    if( closureRef == 0 ) return 0;
    return getClosureUpval( env, closureRef, upval );
}

// GETTABLE A B C   R(A) := R(B)[RK(C)]       //table comes from heap
// GETTABUP A B C   R(A) := UpValue[B][RK(C)] //table comes from upval

bool getTabUp( struct WorkerEnv* env, uchar reg, uint upvalIndexOfTable, uint tableKey ) {
    href closure = getStackClosure( env->luaStack );
    href table = getClosureUpval( env, closure, upvalIndexOfTable );

    href value = 0;
    if( isK(tableKey) ) { //use constant
        int index = indexK( tableKey );
        value = tableGetByConst( env, table, index );
    } else { //use register
        href key = getRegister( env->luaStack, (uchar)tableKey );
        value = tableGetByHeap( env, table, key );
    }

    setRegister( env->luaStack, env->stackSize, reg, value );
    return true;
}

//Ax
void doAxOp( struct WorkerEnv* env,  OpCode code, uint a ) {

}

//A Bx
bool doABxOp( struct WorkerEnv* env, OpCode code, uchar a, uint bx ) {
    switch( code ) {
        case OP_LOADK: // R(A) := Kst(Bx)
            return loadk( env, a, bx );

        default:
            return false;
    }
}

//A sBx
void doAsBxOp( struct WorkerEnv* env, OpCode code, uchar a, int bx ) {

}

//A B C
void doABCOp( struct WorkerEnv* env, OpCode code, uchar a, ushort b, ushort c ) {

}

bool doOp( struct WorkerEnv* env, LuaInstruction instruction ) {
    // LuaInstruction instruction = code[ codeIndexes[func] + pc ];
    OpCode op = getOpcode( instruction );

    switch( op ) {
        //Ax
        //case:
        //A Bx
        case OP_LOADK:
        {
            uchar a = getA( instruction );
            ushort bx = getBx( instruction );
            return doABxOp( env, op, a, bx );
        }
        //case:

        //A sBx
        //case:

        //A B C
        //case:
        default:
            return false;
    }
}