#ifndef UPVAL_H
#define UPVAL_H
#include"vm.h"
#include"common.cl"
#include"types.cl"

href allocateUpval( struct WorkerEnv* env,  href stackRef, uchar reg );
href getUpvalStackRef( struct WorkerEnv* env, href ref );
uchar getUpvalRegister( struct WorkerEnv* env, href ref );

href getUpvalValue( struct WorkerEnv* env, href ref );
bool setUpvalValue( struct WorkerEnv* env, href ref, href value );
#endif