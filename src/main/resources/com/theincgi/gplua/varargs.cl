
#include"varargs.h"
#include"vm.h"
#include"common.cl"
#include"heapUtils.h"
#include"types.cl"
#include"array.h"
#include"luaStack.h"

href newVarargs( struct WorkerEnv* env, href luaStack, uchar registerStart, uchar nRegisters, href more ) {
    href v = allocateHeap( env->heap, env->maxHeapSize, 11 );
    if( v == 0 ) return 0;
    printf("Allocated VARARGS at %d\n", v);

    env->heap[ v     ] = T_VARARGS;
    putHeapInt( env->heap, v + 1, luaStack );
    env->heap[ v + 5 ] = registerStart;
    env->heap[ v + 6 ] = nRegisters;
    putHeapInt( env->heap, v + 7, more );
    return v;
}

href varg_getLuaStack( struct WorkerEnv* env, href vararg ) {
    return getHeapInt( env->heap, vararg + 1 );
}

uchar varg_regStart( struct WorkerEnv* env, href vararg ) {
    return getHeapInt( env->heap, vararg + 5);
}

uchar varg_nRegisters( struct WorkerEnv* env, href vararg ) {
    return getHeapInt( env->heap, vararg + 6 );
}

uint varg_size( struct WorkerEnv* env, href vararg ) {
    href more = getHeapInt( env->heap, vararg + 7 );
    if( more != 0 )
        return arraySize( env->heap, more ) + varg_nRegisters( env, vararg );
    return varg_nRegisters( env, vararg );
}

href varg_get( struct WorkerEnv* env, href vararg, uint index ) {
    uint nreg = varg_nRegisters( env, vararg );
    if( index >= nreg ) {
        href more = getHeapInt( env->heap, vararg + 7 );
        if( more == 0 ) return 0;
        return arrayGet( env->heap, more, index - nreg );
    }

    return ls_getRegister( env, varg_getLuaStack(env, vararg), varg_regStart(env, vararg) + index );
}

href varg_dealias( struct WorkerEnv* env, href vararg ) {
    uint size = varg_size( env, vararg );

    // if( size == 0 ) return 0;
    // if( size == 1 ) return varg_get( env, vararg, 0 );

    href arr = newArray( env->heap, env->maxHeapSize, size);
    for( uint i = 0; i < size; i++ ) {
        arraySet( env->heap, arr, i, varg_get( env, vararg, i ));
    }
    return newVarargs( env, 0, 0, 0, arr );
}