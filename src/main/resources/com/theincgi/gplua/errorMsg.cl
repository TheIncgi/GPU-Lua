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
    char msg[ 24 ];
    copyToBuf( "bytecode: unhandled op ", msg );

    char ibuf[ INT_STRING_BUFFER_SIZE ];
    intToCharbuf( op, ibuf );

    char* strs[2];
    strs[0] = msg;
    strs[1] = ibuf;

    uint lenBuf[2];

    throwHref( env, concatRaw( env, strs, 2, lenBuf ));
}

void throwCall( struct WorkerEnv* env, uint type ) {
    char msg[ 17 ];
    copyToBuf( "attempt to call ", msg );

    char buffer[ TYPE_NAME_BUFFER_SIZE ];
    typeName( type, buffer, TYPE_NAME_BUFFER_SIZE );

    char* strs[2];
    strs[0] = msg;
    strs[1] = buffer;
    
    uint lenBuf[2];
    throwHref( env, concatRaw( env, strs, 2, lenBuf ));
}

//for use with math ops, string op must not be more than 2 long
void err_attemptToPerform( struct WorkerEnv* env, uint typeA, string op, uint typeB ) {
    char msg[ 20 ];
    copyToBuf( "attempt to perform ", msg );

    char space[ 2 ];
    space[0] = ' ';
    space[1] = 0;

    char buffer1[ TYPE_NAME_BUFFER_SIZE ];
    char buffer2[ TYPE_NAME_BUFFER_SIZE ];

    typeName( typeA, buffer1, TYPE_NAME_BUFFER_SIZE );
    typeName( typeB, buffer2, TYPE_NAME_BUFFER_SIZE );

    char opBuf[3];
    copyToBuf( op, opBuf );

    char* strs[6];
    strs[0] = msg;
    strs[1] = buffer1;
    strs[2] = space;
    strs[3] = opBuf;
    strs[4] = space;
    strs[5] = buffer2;

    uint lenBuf[6];

    throwHref( env, concatRaw( env, strs, 6, lenBuf ) );
}


#endif