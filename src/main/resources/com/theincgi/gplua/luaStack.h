#ifndef LUASTACK_H
#define LUASTACK_H

#include"vm.h"
#include"common.cl"

//type + 6 ints
#define STACKFRAME_RESERVE (1 + 8*4)
#define REGISTER_SIZE 4

href allocateLuaStack( struct WorkerEnv* env, href priorStack, uint priorPC, href closure );

href ls_getPriorStack( struct WorkerEnv* env, href frame );
uint ls_getPriorPC( struct WorkerEnv* env, href frame );
uint ls_getDepth( struct WorkerEnv* env, href frame );
href ls_getClosure( struct WorkerEnv* env, href frame );
uint ls_getFunction( struct WorkerEnv* env, href frame );

//vararg is call varargs, v is temp result from a returned value added to this stack

sref ls_getVarargArraySref( struct WorkerEnv* env, href frame );
sref ls_getVSref( struct WorkerEnv* env, href frame );
sref ls_getRegisterSref( struct WorkerEnv* env, href frame, uint reg );
href ls_getVarargArrayHref( struct WorkerEnv* env, href frame );
sref ls_getTopSref( struct WorkerEnv* env, href frame );
sref ls_getTopHref( struct WorkerEnv* env, href frame );
href ls_getRegisterHref( struct WorkerEnv* env, href frame, uint reg );
sref ls_getVHref( struct WorkerEnv* env, href frame );

href ls_getVararg( struct WorkerEnv* env, href frame, uint varg );
href ls_getRegister( struct WorkerEnv* env, href frame, uint reg );
href ls_getV( struct WorkerEnv* env, href frame, uint varg );
// void ls_setVararg( struct WorkerEnv* env, href frame, uint varg, href value );
void ls_setVarargs( struct WorkerEnv* env, href frame, href varargs );
void ls_setV( struct WorkerEnv* env, href frame, href v );
bool ls_setRegister( struct WorkerEnv* env, href frame, uint reg, href value );

uint ls_nVarargs( struct WorkerEnv* env, href frame );
uint ls_nV( struct WorkerEnv* env, href frame );
uint ls_nRegisters( struct WorkerEnv* env, href frame );

href ls_getCallArg( struct WorkerEnv* env, href frame, ushort a, uint argN );

bool ls_pop( struct WorkerEnv* env );\
void ls_push( struct WorkerEnv* env, href luaStack );

//helpers for CurrentLuaStack (cls)
href cls_getPriorStack( struct WorkerEnv* env );
uint cls_getPriorPC( struct WorkerEnv* env );
uint cls_getDepth( struct WorkerEnv* env );
href cls_getClosure( struct WorkerEnv* env );
uint cls_getFunction( struct WorkerEnv* env );
sref cls_getVarargArraySref( struct WorkerEnv* env );
sref cls_getRegisterSref( struct WorkerEnv* env, uint reg );
href cls_getVarargArrayHref( struct WorkerEnv* env );
sref cls_getTopSref( struct WorkerEnv* env );
sref cls_getTopHref( struct WorkerEnv* env );
href cls_getRegisterHref( struct WorkerEnv* env, uint reg );
href cls_getVararg( struct WorkerEnv* env, uint varg );
href cls_getRegister( struct WorkerEnv* env, uint reg );
void cls_setVarargs( struct WorkerEnv* env, href varArgs );
bool cls_setRegister( struct WorkerEnv* env, uint reg, href value );
uint cls_nVarargs( struct WorkerEnv* env );
uint cls_nRegisters( struct WorkerEnv* env );
void cls_setV( struct WorkerEnv* env, href v );
href cls_getVHref( struct WorkerEnv* env );
href cls_getVArg( struct WorkerEnv* env, uint varg );
uint cls_nV( struct WorkerEnv* env );
href cls_getCallArg( struct WorkerEnv* env, ushort a, uint argN );


href getReturn( struct WorkerEnv* env, uint r );
href redefineLuaStack( struct WorkerEnv* env, href closure );

#endif