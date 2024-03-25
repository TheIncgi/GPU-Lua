#include"closure.h"
#include"common.cl"
#include"types.cl"
#include"heapUtils.h"
#include"vm.h"
#include"array.h"

href createClosure(struct WorkerEnv* env, int funcIndex, href envTable, uint numUpvals) {
    href closure = allocateHeap( env->heap, env->maxHeapSize, 13 );
    if( closure == 0 ) return 0;

    href upvalArray = newArray( env->heap, env->maxHeapSize, numUpvals );

    env->heap[ closure ] = T_CLOSURE;

    putHeapInt( env->heap, closure + 1, funcIndex );
    putHeapInt( env->heap, closure + 5, upvalArray );
    putHeapInt( env->heap, closure + 9, envTable );

    return closure;
}

uint getClosureFunction(struct WorkerEnv* env, href closure) {
    return getHeapInt( env->heap, closure + 1 );
}


href getClosureUpvalArray(struct WorkerEnv* env, href closure) {
    return getHeapInt( env->heap, closure + 5 );
}

href getClosureUpval(struct WorkerEnv* env, href closure, uint upvalIndex) {
    href array = getClosureUpvalArray( env, closure );
    if(array == 0) return 0;

    return arrayGet( env->heap, array, upvalIndex );
}

void setClosureUpval(struct WorkerEnv* env, href closure, uint upvalIndex, href value) {
    href array = getClosureUpvalArray( env, closure );
    arraySet( env->heap, array, upvalIndex, value );
}

href getClosureEnv(struct WorkerEnv* env, href closure) {
    return getHeapInt( env->heap, closure + 9 );
}