#ifndef LUASTACK_H
#define LUASTACK_H

href allocateStack( struct WorkerEnv* env, href priorStack, uint priorPC, href closure, uint nVarargs, uint maxStackSize );

href ls_getPriorStack( struct WorkerEnv* env, href frame );
uint ls_getPriorPC( struct WorkerEnv* env, href frame );
href ls_getClosure( struct WorkerEnv* env, href frame );
uint ls_getFunction( struct WorkerEnv* env, href frame );

sref ls_getVarargSref( struct WorkerEnv* env, href frame, uint varg );
sref ls_getRegisterSref( struct WorkerEnv* env, href frame, uint reg );
href ls_getVarargHref( struct WorkerEnv* env, href frame, uint varg );
sref ls_getTopSref( struct WorkerEnv* env, href frame );
sref ls_getTopHref( struct WorkerEnv* env, href frame );
href ls_getRegisterHref( struct WorkerEnv* env, href frame, uint reg );

href ls_getVararg( struct WorkerEnv* env, href frame, uint varg );
href ls_getRegister( struct WorkerEnv* env, href frame, uint reg );
void ls_setVararg( struct WorkerEnv* env, href frame, uint varg, href value );
bool ls_setRegister( struct WorkerEnv* env, href frame, uint reg, href value );

uint ls_nVarargs( struct WorkerEnv* env, href frame );
uint ls_nRegisters( struct WorkerEnv* env, href frame );

bool ls_pop( struct WorkerEnv* env );

#endif