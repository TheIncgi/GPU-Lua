#ifndef HEAP_STRINGS
#define HEAP_STRINGS

#include"common.cl"
#include"vm.h"

href heapString(struct WorkerEnv* env, string str);
href _heapString(struct WorkerEnv* en, string str, uint strLen);

#endif