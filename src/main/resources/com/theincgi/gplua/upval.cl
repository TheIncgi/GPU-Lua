#include"upval.h"
#include"common.cl"
#include"types.cl"
#include"luaStack.h"

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

href getUpvalValue( struct WorkerEnv* env, href ref ) {
    return ls_getRegister( 
        env,
        getUpvalStackRef( env, ref ),
        getUpvalRegister( env, ref )
    );
}

bool setUpvalValue( struct WorkerEnv* env, href ref, href value ) {
    return ls_setRegister(
        env,
        getUpvalStackRef( env, ref ),
        getUpvalRegister( env, ref ),
        value
    );
}