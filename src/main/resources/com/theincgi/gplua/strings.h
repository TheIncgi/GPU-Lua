#ifndef HEAP_STRINGS
#define HEAP_STRINGS

#include"common.cl"
#include"vm.h"

href heapString(struct WorkerEnv* env, string str);
href _heapString(uchar* heap, uint maxHeapSize, href stringTable, string str, uint strLen);

#endif