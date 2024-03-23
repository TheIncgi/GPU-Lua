#ifndef CLOSURE_H
#define CLOSURE_H

#include"common.cl"

href createClosure(uchar* heap, uint maxHeapSize, uint* stack, int funcIndex, href envTable);

uint getClosureFunction(struct WorkerEnv* env, href closure);
href getClosureUpvalArray(struct WorkerEnv* env, href closure);
href getClosureUpval(struct WorkerEnv* env, href closure, uint upvalIndex);
href getClosureEnv(struct WorkerEnv* env, href closure);

#endif