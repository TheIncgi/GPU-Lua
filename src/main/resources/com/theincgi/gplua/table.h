#ifndef TABLE_CL
#define TABLE_CL

#include"common.cl"

#define TABLE_INIT_ARRAY_SIZE 4
#define HASHMAP_INIT_SIZE 4

href newTable(uchar* heap, uint maxHeapSize);
href tableGetArrayPart( uchar* heap, href heapIndex );
href tableGetHashedPart( uchar* heap, href heapIndex );
href tableGetMetatable( uchar* heap, href heapIndex );
uint tableLen( uchar* heap, href heapIndex );
href tableCreateArrayPart( uchar* heap, uint maxHeapSize, href tableHeapIndex );
href tableCreateHashedPart( uchar* heap, uint maxHeapSize, href tableHeapIndex );
href tableRawGet( uchar* heap, href heapIndex, href key );
bool tableResizeArray( uchar* heap, uint maxHeapSize, href tableIndex, uint newSize );
bool tableRawSet( uchar* heap, uint maxHeapSize, href tableIndex, href key, href value );

#endif