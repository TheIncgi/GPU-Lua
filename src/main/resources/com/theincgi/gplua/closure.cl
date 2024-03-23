#include"closure.h"
#include"common.cl"
#include"types.cl"
#include"heapUtils.h"
#include"vm.h"

href createClosure(WorkerEnv* env, int funcIndex, href envTable) {
    href closure = allocateHeap( env->heap, env->maxHeapSize, 9 );
    if( closure == 0 ) return 0;

    numUpvals = 0; //TODO count upvals needed, allocate, copy refs
    href upvalArray = allocateArray( env->heap, env->maxHeapSize, numUpvals );

    env->heap[ closure ] = T_CLOSURE;

    putHeapInt( env->heap, closure + 1, funcRef );
    putHeapInt( env->heap, closure + 5, upvalArray );
    putHeapInt( env->heap, closure + 9, envTable );

    return closure;
}

uint getClosureFunction(WorkerEnv* env, href closure) {
    return getHeapInt( env->heap, closure + 1 );
}


href getClosureUpvalArray(WorkerEnv* env, href closure) {
    return getHeapInt( env->heap, closure + 5 );
}

href getClosureUpval(WorkerEnv* env, href closure, uint upvalIndex) {
    href array = getClosureUpvalArray( env, closure );
    if(array == 0) return 0;

    return arrayGet( env->heap, array, upvalIndex );
}

href getClosureEnv(WorkerEnv* env, href closure) {
    return getHeapInt( env->heap, closure + 9 );
}