#include"upval.h"
#include"common.cl"
#include"types.cl"

href allocateUpval( struct WorkerEnv* env,  href stackRef, uchar reg ) {
    href ref = allocateHeap( env->heap, env->maxHeapSize, 9 );
    if( ref == 0 ) return 0;

    env->heap[ ref ] = T_UPVAL;
    putHeapInt( env->heap, ref + 1, stackRef );
    env->heap[ 5 ] = reg;
    
    return ref;
}

href getUpvalStackRef( struct WorkerEnv* env, href ref ) {
    return getHeapInt( env->heap, ref + 1 );
}

uchar getUpvalRegister( struct WorkerEnv* env, href ref ) {
    return env->heap[ ref + 5 ];
}