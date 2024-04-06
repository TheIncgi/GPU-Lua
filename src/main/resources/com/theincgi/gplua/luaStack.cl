#include"common.h"
#include"heapUtils.h"
#include"stackUtils.h"
#include"vm.h"
#include"errorMsg.cl"
#include"types.cl"
#include"closure.h"

//type + 6 ints
#define STACKFRAME_RESERVE (1 + 6*4)
#define REGISTER_SIZE 4
//prev stack
//prev pc
//top
//first reg
//closure href

//maxStackSize defined from kernel args
href allocateStack( struct WorkerEnv* env, href priorStack, uint priorPC, href closure, uint nVarargs, uint maxStackSize ) {
    uchar* heap = env->heap;

    href stack = allocateHeap( heap, env->maxHeapSize, 
                                     1 
        +           STACKFRAME_RESERVE 
        +      varargs * REGISTER_SIZE 
        + maxStackSize * REGISTER_SIZE //maxStacksize might already include vararg space, idk, this is safe for now
    );
    if( stack == 0 ) return 0;
    
    uint funcIndex = getClosureFunction( env, closure );

    heap[stack] = T_LUA_STACK;
    putHeapInt( heap, stack +  1, priorStack ); //0 if none
    putHeapInt( heap, stack +  5, priorPC    ); // 0 if none
    putHeapInt( heap, stack +  9, STACKFRAME_RESERVE + nVarargs ); //top, first empty slot, relative to stackHref
    putHeapInt( heap, stack + 13, STACKFRAME_RESERVE + nVarargs ); //first reg, relative to stackHref
    putHeapInt( heap, stack + 17, closure ); 
    putHeapInt( heap, stack + 21, maxStackSize ); 

    return stack;
}

href ls_getPriorStack( struct WorkerEnv* env, href frame ) {
    return getHeapInt( env->heap, frame + 1 );
}

uint ls_getPriorPC( struct WorkerEnv* env, href frame ) {
    return getHeapInt( env->heap, frame + 5 );
}

href ls_getClosure( struct WorkerEnv* env, href frame ) {
    return getHeapInt( env->heap, frame + 17 );
}

uint ls_getFunction( struct WorkerEnv* env, href frame ) {
    href closure = ls_getClosure( env, frame );
    return getClosureFunction( env, closure );
}

sref ls_getVarargSref( struct WorkerEnv* env, href frame, uint varg ) {
    return STACKFRAME_RESERVE + vararg * REGISTER_SIZE;
}

sref ls_getRegisterSref( struct WorkerEnv* env, href frame, uint reg ) {
    return getHeapInt( env->heap, frame + 13 ) + reg * REGISTER_SIZE;
}

href ls_getVarargHref( struct WorkerEnv* env, href frame, uint varg ) {
    return frame + ls_getVarargSref( env, frame, varg );
}

// href top = frame + <sref returned>
sref ls_getTopSref( struct WorkerEnv* env, href frame ) {
    return getHeapInt( env->heap, frame + 9 );
}
sref ls_getTopHref( struct WorkerEnv* env, href frame ) {
    return frame + getHeapInt( env->heap, frame + 9 );
}

href ls_getRegisterHref( struct WorkerEnv* env, href frame, uint reg ) {
    return frame + ls_getRegisterSref( env, frame, reg );
}



href ls_getVararg( struct WorkerEnv* env, href frame, uint varg ) {
    return getHeapInt( env->heap, ls_getVarargHref( env, varg) );
}

href ls_getRegister( struct WorkerEnv* env, href frame, uint reg ) {
    sref top = ls_getTopSref( env, frame );
    sref regPos = ls_getRegisterSref( env, frame, reg );
    if( regPos >= top ) return 0; //out of bounds

    return getHeapInt( env->heap, frame + regPos );
}

void ls_setVararg( struct WorkerEnv* env, href frame, uint varg, href value ) {
    href vargPos = ls_getVarargHref( env, frame, varg );
    putHeapInt( env->heap, vargPos, value );
}

bool ls_setRegister( struct WorkerEnv* env, href frame, uint reg, href value ) {
    uint maxStk = getHeapInt( env->heap, frame + 21 );
    if( reg >= maxStk ) {
        throwSO( env ); //stack overflow
        return false;
    }
    sref regPos = ls_getRegisterSref( env, frame, reg );
    sref    top = ls_getTopSref( env, frame );
    
    //fill skipped with nil, might not ever happen, idk
    for( sref r = top; r < regPos; r += REGISTER_SIZE )
        putHeapInt( env->heap, frame + r, 0 );
    
    putHeapInt( env->heap, regPos, value );
    return true;
}

uint ls_nVarargs( struct WorkerEnv* env, href frame ) {
    sref firstReg = ls_getRegisterSref( env, frame, 0 );
    return (firstReg - STACKFRAME_RESERVE) / REGISTER_SIZE - 1;
}
uint ls_nRegisters( struct WorkerEnv* env, href frame ) {
    sref top = ls_getTopSref( env, frame );
    sref first = ls_getRegisterSref( env, frame, 0 );
    return (top - first) / REGISTER_SIZE;
}



bool ls_pop( struct WorkerEnv* env ) {
    href prior = ls_getPriorStack( env, env->luaStackHref );
    if( prior == 0 )
        return false;
    
    uint pc = ls_getPriorPC( env, env->luaStackHref );
    env->pc = pc;
    env->luaStackHref = prior;
    return true;
}