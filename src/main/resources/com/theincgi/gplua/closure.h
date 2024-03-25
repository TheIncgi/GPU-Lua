#ifndef CLOSURE_H
#define CLOSURE_H

#include"vm.h"
#include"common.cl"

href createClosure(struct WorkerEnv* env, int funcIndex, href envTable, uint nUpvals);

uint getClosureFunction(struct WorkerEnv* env, href closure);
href getClosureUpvalArray(struct WorkerEnv* env, href closure);
href getClosureUpval(struct WorkerEnv* env, href closure, uint upvalIndex);
void setClosureUpval(struct WorkerEnv* env, href closure, uint upvalIndex, href value);
href getClosureEnv(struct WorkerEnv* env, href closure);

#endif