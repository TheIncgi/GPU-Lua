#include"luaStack.h"
#include"common.cl"
#include"heapUtils.h"
#include"stackUtils.h"
#include"vm.h"
#include"errorMsg.cl"
#include"types.cl"
#include"closure.h"


//prev stack
//prev pc
//top
//first reg
//closure href

//maxStackSize defined from kernel args
href allocateLuaStack( struct WorkerEnv* env, href priorStack, uint priorPC, href closure, uint nVarargs ) {
    uchar* heap = env->heap;
    uint funcIndex = getClosureFunction( env, closure );
    uint maxStackSize = env->maxStackSizes[ funcIndex ];

    uint depth = 0;
    if( priorStack != 0 ) {
        depth = ls_getDepth( env, priorStack ) + 1;
    }

    href stack = allocateHeap( heap, env->maxHeapSize, 
                                     1 
        +           STACKFRAME_RESERVE 
        +     nVarargs * REGISTER_SIZE 
        + maxStackSize * REGISTER_SIZE //maxStacksize might already include vararg space, idk, this is safe for now
    );
    if( stack == 0 ) return 0;

    heap[stack] = T_LUA_STACK;
    putHeapInt( heap, stack +  1, priorStack ); //0 if none
    putHeapInt( heap, stack +  5, priorPC    ); // 0 if none
    putHeapInt( heap, stack +  9, STACKFRAME_RESERVE + nVarargs * REGISTER_SIZE ); //top, first empty slot, relative to stackHref
    putHeapInt( heap, stack + 13, STACKFRAME_RESERVE + nVarargs * REGISTER_SIZE ); //first reg, relative to stackHref
    putHeapInt( heap, stack + 17, closure ); 
    putHeapInt( heap, stack + 21, maxStackSize ); 
    putHeapInt( heap, stack + 25, depth ); 

    return stack;
}

href ls_getPriorStack( struct WorkerEnv* env, href frame ) {
    return getHeapInt( env->heap, frame + 1 );
}

uint ls_getPriorPC( struct WorkerEnv* env, href frame ) {
    return getHeapInt( env->heap, frame + 5 );
}

uint ls_getDepth( struct WorkerEnv* env, href frame ) {
    return getHeapInt( env->heap, frame + 25 );
}

href ls_getClosure( struct WorkerEnv* env, href frame ) {
    return getHeapInt( env->heap, frame + 17 );
}

uint ls_getFunction( struct WorkerEnv* env, href frame ) {
    href closure = ls_getClosure( env, frame );
    return getClosureFunction( env, closure );
}

sref ls_getVarargSref( struct WorkerEnv* env, href frame, uint varg ) {
    return STACKFRAME_RESERVE + varg * REGISTER_SIZE;
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
    return getHeapInt( env->heap, ls_getVarargHref( env, frame, varg ) );
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
    if( env->luaStack == 0 )
        return false;
    
    href prior = ls_getPriorStack( env, env->luaStack );
    uint pc = ls_getPriorPC( env, env->luaStack );
    env->pc = pc;
    env->luaStack = prior;
    return true;
}

void ls_push( struct WorkerEnv* env, href luaStack ) {
    env->pc = 0;
    env->func = ls_getFunction( env, luaStack );
    env->luaStack = luaStack;
}

//helpers for CurrentLuaStack (cls)
href cls_getPriorStack( struct WorkerEnv* env ) {
    return ls_getPriorStack( env, env->luaStack );
}
uint cls_getPriorPC( struct WorkerEnv* env ) {
    return ls_getPriorPC( env, env->luaStack );
}
uint cls_getDepth( struct WorkerEnv* env ) {
    return ls_getDepth( env, env->luaStack );
}
href cls_getClosure( struct WorkerEnv* env ) {
    return ls_getClosure( env, env->luaStack );
}
uint cls_getFunction( struct WorkerEnv* env ) {
    return ls_getFunction( env, env->luaStack );
}
sref cls_getVarargSref( struct WorkerEnv* env, uint varg ) {
    return ls_getVarargSref( env, env->luaStack, varg );
}
sref cls_getRegisterSref( struct WorkerEnv* env, uint reg ) {
    return ls_getRegisterSref( env, env->luaStack, reg );
}
href cls_getVarargHref( struct WorkerEnv* env, uint varg ) {
    return ls_getVarargHref( env, env->luaStack, varg );
}
sref cls_getTopSref( struct WorkerEnv* env ) {
    return ls_getTopSref( env, env->luaStack );
}
sref cls_getTopHref( struct WorkerEnv* env ) {
    return ls_getTopHref( env, env->luaStack );
}
href cls_getRegisterHref( struct WorkerEnv* env, uint reg ) {
    return ls_getRegisterHref( env, env->luaStack, reg );
}
href cls_getVararg( struct WorkerEnv* env, uint varg ) {
    return ls_getVararg( env, env->luaStack, varg );
}
href cls_getRegister( struct WorkerEnv* env, uint reg ) {
    return ls_getRegister( env, env->luaStack, reg );
}
void cls_setVararg( struct WorkerEnv* env, uint varg, href value ) {
    ls_setVararg( env, env->luaStack, varg, value );
}
bool cls_setRegister( struct WorkerEnv* env, uint reg, href value ) {
    return ls_setRegister( env, env->luaStack, reg, value );
}
uint cls_nVarargs( struct WorkerEnv* env ) {
    return ls_nVarargs( env, env->luaStack );
}
uint cls_nRegisters( struct WorkerEnv* env ) {
    return ls_nRegisters( env, env->luaStack );
}

href getReturn( struct WorkerEnv* env, uint r ) {
    if( !env->returnFlag )
        return 0;
    if( env->nReturn >= r)
        return 0;
    return env->heap[ env->returnStart + r * REGISTER_SIZE ];
}

href redefineLuaStack( struct WorkerEnv* env, href closure, uint nVarargs ) {
    href old = env->luaStack;
    return allocateLuaStack( 
        env, 
        ls_getPriorStack( env, old ),
        ls_getPriorPC( env, old ),
        closure, nVarargs
    );
}