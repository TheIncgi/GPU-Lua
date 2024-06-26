#ifndef TABLE_CL
#define TABLE_CL

#include"common.cl"
#include"vm.h"

#define TABLE_INIT_ARRAY_SIZE 4
#define HASHMAP_INIT_SIZE 4

href newTable(uchar* heap, uint maxHeapSize);
href tableGetArrayPart( uchar* heap, href heapIndex );
href tableGetHashedPart( uchar* heap, href heapIndex );
href tableGetMetatable( uchar* heap, href heapIndex );
uint tableLen( uchar* heap, href heapIndex );
href tableCreateArrayPart( uchar* heap, uint maxHeapSize, href tableHeapIndex );
href tableCreateArrayPartWithSize( uchar* heap, uint maxHeapSize, href tableHeapIndex, uint initalSize );
href tableCreateHashedPart( uchar* heap, uint maxHeapSize, href tableHeapIndex );
href tableCreateHashedPartWithSize( uchar* heap, uint maxHeapSize, href tableHeapIndex, uint initalSize );
// bool tableArrayContainsKey( uchar* heap, href tableIndex, uint indexInTable);
href tableRawGet( uchar* heap, href tableIndex, uchar* keySource, uint keyIndex, uint keyLen );
bool tableResizeArray( uchar* heap, uint maxHeapSize, href tableIndex, uint newSize );
bool tableRawSet( struct WorkerEnv* env, href tableIndex, href key, href value );
bool tableSetList( struct WorkerEnv* env, href tableIndex, href* arrayPart, uint* size, uint* cap, uint key, href value );

href tableGetMetaEvent( struct WorkerEnv* env, href table, string eventName );
href tableGetMetaIndex( struct WorkerEnv* env, href table );
href tableGetMetaNewIndex( struct WorkerEnv* env, href table );

href tableGetByHeap( struct WorkerEnv* env, href table, href key );
href tableGetByConst( struct WorkerEnv* env, href table, int key );

#endif