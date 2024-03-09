#ifndef ARRAY_CL
#define ARRAY_CL

#include"common.cl"

href newArray(uchar* heap, uint maxHeap, uint capacity );
href _allocateArray(uchar* heap, uint maxHeap, uint size);

void arrayClear(uchar* heap, href heapIndex);
uint arraySize( uchar* heap, href index );
uint arrayCapacity( uchar* heap, href index );
href arrayGet( uchar* heap, href heapIndex, int index );
void arraySet( uchar* heap, href heapIndex, int index, href val );

//if the next space in memory is free, claim some of that
// uint grow( uchar* heap, href heapIndex, uint maxGrowth );
href arrayResize( uchar* heap, uint maxHeapSize, href heapIndex, uint newCapacity );

#endif