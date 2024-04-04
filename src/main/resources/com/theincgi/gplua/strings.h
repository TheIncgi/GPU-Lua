#ifndef HEAP_STRINGS
#define HEAP_STRINGS

#include"common.cl"
#include"vm.h"

href heapString(struct WorkerEnv* env, string str);
href _heapString(struct WorkerEnv* en, string str, uint strLen);
href concatRaw( struct WorkerEnv* env, string* strings, uint nStrings );
//min size 19
void typeName( uint type, string* buffer, uint bufferSize );
#endif