#ifndef ERROR_MSG_CL
#define ERROR_MSG_CL

#include"common.cl"
#include"strings.h"

bool hasError( struct WorkerEnv* env ) {
    return env->error > 0;
}

void throwHref( struct WorkerEnv* env, href msg ) {
    env->error = msg == 0 ? TRUE_HREF : msg;
}

//heap memory
void throwOOM( struct WorkerEnv* env ) {
    throwHref( env, 0 );
}

void throwErr( struct WorkerEnv* env, string msg ) {
    href ref = heapString( env, msg );
    throwHref( env, ref );
}

void throwSO( struct WorkerEnv* env ) {
    string msg = "StackOverflow";
    throwErr( env, msg );
}

void err_attemptToPerform( struct WorkerEnv* env, uint typeA, string op, uint typeB ) {
    string strs[6];
    char buffer1[ 19 ];
    char buffer2[ 19 ];

    typeName( typeA, buffer1, 19 );
    typeName( typeB, buffer2, 19 );

    strs[0] = "attempt to perform ";
    strs[1] = &buffer1;
    strs[2] = " ";
    strs[3] = op;
    strs[4] = " "
    strs[5] = &buffer2;

    throwHref( env, concatRaw( env, strs, 6 ) );
}


#endif