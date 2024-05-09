#ifndef VARARGS_H
#define VARARGS_H

#include"vm.h"
#include"common.cl"
#include"heapUtils.h"

href newVarargs( struct WorkerEnv* env, href luaStack, uchar registerStart, uchar nRegisters, href more );

href varg_getLuaStack( struct WorkerEnv* env, href vararg );
uchar varg_regStart( struct WorkerEnv* env, href vararg );
uchar varg_nRegisters( struct WorkerEnv* env, href vararg );
uint varg_size( struct WorkerEnv* env, href vararg );
href varg_get( struct WorkerEnv* env, href vararg, uint index );
href varg_dealias( struct WorkerEnv* env, href vararg );

#endif