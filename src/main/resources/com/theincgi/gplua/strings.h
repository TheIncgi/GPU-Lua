#ifndef HEAP_STRINGS
#define HEAP_STRINGS

#define TYPE_NAME_BUFFER_SIZE 19
//fits "-2147483648" (-2 million) + null term
#define INT_STRING_BUFFER_SIZE 12
//fits "9e12345678e+308" + null term
#define DOUBLE_STRING_BUFFER_SIZE 16

#include"common.cl"
#include"vm.h"

href heapString(struct WorkerEnv* env, string str);
href _heapString(struct WorkerEnv* en, string str, uint strLen);
//buffer size must be at least INT_STRING_BUFFER_SIZE, anything smaller may cause array index out of bounds
void intToCharbuf( int value, char* buffer );
href concatRaw( struct WorkerEnv* env, string* strings, uint nStrings );
//min size 19
void typeName( uint type, string* buffer, uint bufferSize );
#endif