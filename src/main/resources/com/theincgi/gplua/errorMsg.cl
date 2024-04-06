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

void throwUnexpectedBytecodeOp( struct WorkerEnv* env, int op ) {
    char ibuf[ INT_STRING_BUFFER_SIZE ];
    intToCharbuf( op, ibuf, INT_STRING_BUFFER_SIZE );
    strings strs[2];
    strs[0] = "bytecode: unhandled op ";
    strs[1] = ibuf;
    throwHref( env, concatRaw( env, strs, 2 ));
}

void throwCall( struct WorkerEnv* env, uint type ) {
    char buffer[ TYPE_NAME_BUFFER_SIZE ];
    typeName( type, buffer, TYPE_NAME_BUFFER_SIZE );

    string strs[2];
    strs[0] = "attempt to call ";
    strs[1] = buffer;

    throwHref( env, concatRaw( env, strs, 2 ));
}

void err_attemptToPerform( struct WorkerEnv* env, uint typeA, string op, uint typeB ) {
    string strs[6];
    char buffer1[ TYPE_NAME_BUFFER_SIZE ];
    char buffer2[ TYPE_NAME_BUFFER_SIZE ];

    typeName( typeA, buffer1, TYPE_NAME_BUFFER_SIZE );
    typeName( typeB, buffer2, TYPE_NAME_BUFFER_SIZE );

    strs[0] = "attempt to perform ";
    strs[1] = buffer1;
    strs[2] = " ";
    strs[3] = op;
    strs[4] = " "
    strs[5] = buffer2;

    throwHref( env, concatRaw( env, strs, 6 ) );
}


#endif