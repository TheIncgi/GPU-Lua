#ifndef NATIVES_CL
#define NATIVES_CL

#include"vm.h"
#include"globals.cl"
#include"common.cl"



void _cn_argErr( struct WorkerEnv* env, uchar arg, uchar expectedType, uchar gotType ) {

}

href _cn_argAssert( struct WorkerEnv* env, sref a, uchar arg, uchar type ) {
    href argRef = env->luaStack[ a + arg ];
    uchar argType = env->heap[ argRef ];
    
    if(argType == T_INT)
        argType = T_NUMBER;

    if( argType != type ) {
        _cn_argErr( env, arg, type, argType );
        return 0;
    }
    return argRef;
}

double _cn_argDouble( struct WorkerEnv* env, href arg ) {
    uchar argType = env->heap[ arg ];
    union doubleUnion du;
    if( argType == T_NUMBER )
        du.lbits = (((long)getHeapInt( env->heap, arg + 1 )) << 32) | getHeapInt( env->heap, arg + 1 );
    else if( argType == T_INT )
        du.dbits = (double) getHeapInt( env->heap, arg + 1 );
    else
        du.dbits = NAN;
    return du.dbits;
}

/**
  * sref a - location where the native func is on the stack, args start at a+1
  *          return values are put at a
  */
bool callNative( struct WorkerEnv* env, uint nativeID, sref a, uint nargs ) {
    switch( nativeID ) {
        case NF_MATH_LOG: {
            //args
            href arg1 = _cn_argAssert( env, a, 1, T_NUMBER );
            double arg1d = _cn_argDouble( env, arg1 );
            //call
            double result = log( arg1d );
            //return
            href r1 = allocateNumber( env->heap, env->maxHeapSize, result );
            if( r1 == 0 ) return false;
            env->luaStack[ a ] = r1;
            return true;
        }
    }
    return false;
}

#endif