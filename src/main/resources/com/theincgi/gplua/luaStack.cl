#include"luaStack.h"
#include"common.cl"
#include"heapUtils.h"
#include"stackUtils.h"
#include"vm.h"
#include"errorMsg.cl"
#include"types.cl"
#include"closure.h"
#include"array.h"
#include"varargs.h"

//prev stack
//prev pc
//top
//first reg
//closure href

//maxStackSize defined from kernel args
href allocateLuaStack( struct WorkerEnv* env, href priorStack, uint priorPC, href closure ) {
    uchar* heap = env->heap;
    uint funcIndex = getClosureFunction( env, closure );
    uint maxStackSize = env->maxStackSizes[ funcIndex ];
    bool isVararg = env->isVararg[ funcIndex ];
    uint nVarargs = isVararg ? 1 : 0; //call varargs

    uint depth = 0;
    if( priorStack != 0 ) {
        depth = ls_getDepth( env, priorStack ) + 1;
    }

    href stack = allocateHeap( heap, env->maxHeapSize, 
                                     1 
        +           STACKFRAME_RESERVE 
        +     nVarargs * REGISTER_SIZE 
        + maxStackSize * REGISTER_SIZE //maxStacksize looks like it only refers to registers
    );
    if( stack == 0 ) return 0;

    heap[stack] = T_LUA_STACK;
    putHeapInt( heap, stack +  1, priorStack ); //0 if none
    putHeapInt( heap, stack +  5, priorPC    ); // 0 if none
    putHeapInt( heap, stack +  9, STACKFRAME_RESERVE + nVarargs * REGISTER_SIZE ); //top, first empty slot, relative to stackHref
    putHeapInt( heap, stack + 13, STACKFRAME_RESERVE + nVarargs * REGISTER_SIZE ); //first reg, relative to stackHref
    putHeapInt( heap, stack + 17, closure ); 
    putHeapInt( heap, stack + 21, maxStackSize ); //probably refers to the number of registers
    putHeapInt( heap, stack + 25, depth ); 
    putHeapInt( heap, stack + 29,     0 ); // "V" temp varargs for results & calling, not the varargs that this stack was called with

    if(nVarargs > 1)
        putHeapInt( heap, ls_getVarargArrayHref(env, stack), 0 );

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

sref ls_getVarargArraySref( struct WorkerEnv* env, href frame ) {
    return STACKFRAME_RESERVE + REGISTER_SIZE;
}

sref ls_getRegisterSref( struct WorkerEnv* env, href frame, uint reg ) {
    return getHeapInt( env->heap, frame + 13 ) + reg * REGISTER_SIZE;
}

sref ls_getVSref( struct WorkerEnv* env, href frame ) {
    return STACKFRAME_RESERVE;
}

href ls_getVarargArrayHref( struct WorkerEnv* env, href frame ) {
    return frame + ls_getVarargArraySref( env, frame );
}

sref ls_getVHref( struct WorkerEnv* env, href frame ) {
    return frame + ls_getVSref( env, frame );
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
    href vargsArray = getHeapInt( env->heap, ls_getVarargArrayHref( env, frame ) );
    if(vargsArray == 0) return 0;

    return arrayGet( env->heap, vargsArray, varg );
    //getHeapInt( env->heap, ls_getVarargHref( env, frame, varg ) );
}

href ls_getVArg( struct WorkerEnv* env, href frame, uint varg ) {
    href vHref = ls_getVHref( env, frame );
    href v = getHeapInt( env->heap, vHref );
    if( v == 0 ) return 0;
    
    if( env->heap[ v ] == T_VARARGS ) {
        varg_get( env, v, varg );
    }
    return v;
}

href ls_getRegister( struct WorkerEnv* env, href frame, uint reg ) {
    sref top = ls_getTopSref( env, frame );
    sref regPos = ls_getRegisterSref( env, frame, reg );
    if( regPos >= top ) return 0; //out of bounds

    return getHeapInt( env->heap, frame + regPos );
}

// void ls_setVararg( struct WorkerEnv* env, href frame, uint varg, href value ) {
//     href vargPos = ls_getVarargHref( env, frame, varg );
//     putHeapInt( env->heap, vargPos, value );
// }

void ls_setVarargs( struct WorkerEnv* env, href frame, href varargs ) {
    putHeapInt( env->heap, ls_getVarargArrayHref( env, frame ), varargs );
}

void ls_setV( struct WorkerEnv* env, href frame, href v ) {
    putHeapInt( env->heap, ls_getVHref( env, frame ), v );
}

bool ls_setRegister( struct WorkerEnv* env, href frame, uint reg, href value ) {
    uint maxStk = getHeapInt( env->heap, frame + 21 );
    if( reg >= maxStk ) {
        throwSO( env ); //stack overflow
        printf("ERR: SO, %d >= %d\n", reg, maxStk);
        return false;
    }
    sref regPos = ls_getRegisterSref( env, frame, reg );
    sref    top = ls_getTopSref( env, frame );
    
    //fill skipped with nil, might not ever happen, idk
    for( sref r = top; r < regPos; r += REGISTER_SIZE )
        putHeapInt( env->heap, frame + r, 0 );
    
    putHeapInt( env->heap, frame + regPos, value );
    
    if( regPos >= top )
        putHeapInt( env->heap, frame + 9, regPos + REGISTER_SIZE );

    return true;
}

uint ls_nVarargs( struct WorkerEnv* env, href frame ) {
    href vargsArray = getHeapInt( env->heap, ls_getVarargArrayHref( env, frame ) );
    if(vargsArray == 0) return 0;
    return arraySize( env->heap, vargsArray );
    // sref firstReg = ls_getRegisterSref( env, frame, 0 );
    // return (firstReg - STACKFRAME_RESERVE) / REGISTER_SIZE - 1;
}
uint ls_nV( struct WorkerEnv* env, href frame ) {
    href vHref = ls_getVHref( env, frame );
    href v = getHeapInt( env->heap, vHref );
    if( v == 0 ) return 0;
    if( env->heap[ v ] == T_VARARGS )
        return varg_size( env, v );
    return 1;
}
uint ls_nRegisters( struct WorkerEnv* env, href frame ) {
    sref top = ls_getTopSref( env, frame );
    sref first = ls_getRegisterSref( env, frame, 0 );
    return (top - first) / REGISTER_SIZE;
}

href ls_getCallArg( struct WorkerEnv* env, href frame, ushort a, uint argN ) {
    uint nReg = ls_nRegisters( env, frame );
    uint nRegArgs = nReg - a - 1;
    if( argN >= nRegArgs ) {
        argN -= nRegArgs;
        return ls_getVArg( env, frame, argN );
    }
    return ls_getRegister( env, frame, a + argN + 1 );
}

bool ls_pop( struct WorkerEnv* env ) {
    if( env->luaStack == 0 )
        return false;
    
    href prior = ls_getPriorStack( env, env->luaStack );
    if( prior == 0 ) {
        env->luaStack = 0;
        env->func = 0;
        env->pc = 0;
        return true;
    }
    
    env->pc = ls_getPriorPC( env, env->luaStack );
    env->func = ls_getFunction( env, prior );
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
sref cls_getVarargArraySref( struct WorkerEnv* env ) {
    return ls_getVarargArraySref( env, env->luaStack );
}
sref cls_getRegisterSref( struct WorkerEnv* env, uint reg ) {
    return ls_getRegisterSref( env, env->luaStack, reg );
}
href cls_getVarargArrayHref( struct WorkerEnv* env ) {
    return ls_getVarargArrayHref( env, env->luaStack );
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
void cls_setVarargs( struct WorkerEnv* env, href varArgs ) {
    ls_setVarargs( env, env->luaStack, varArgs );
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

void cls_setV( struct WorkerEnv* env, href v ) {
    ls_setV( env, env->luaStack, v );
}

href cls_getVHref( struct WorkerEnv* env ) {
    return ls_getVHref( env, env->luaStack );
}

href cls_getVArg( struct WorkerEnv* env, uint varg ) {
    return ls_getVArg( env, env->luaStack, varg );
}

uint cls_nV( struct WorkerEnv* env) {
    return ls_nV( env, env->luaStack );
}

href cls_getCallArg( struct WorkerEnv* env, ushort a, uint argN ) {
    return ls_getCallArg( env, env->luaStack, a, argN );
}

href getReturn( struct WorkerEnv* env, uint r ) {
    if( !env->returnFlag )
        return 0;

    if( env->heap[ env->returnValue ] == 0 ) return 0;
    if( env->heap[ env->returnValue ] == T_VARARGS ) 
        return varg_get( env, env->returnValue, r);
    if( r == 0 )
        return env->returnValue;

    return 0;
}

href redefineLuaStack( struct WorkerEnv* env, href closure ) {
    href old = env->luaStack;
    return allocateLuaStack( 
        env, 
        ls_getPriorStack( env, old ),
        ls_getPriorPC( env, old ),
        closure
    );
}