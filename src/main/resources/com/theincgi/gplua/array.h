#ifndef ARRAY_CL
#define ARRAY_CL

#include"common.cl"

href allocateArray(uchar* heap, uint maxHeap, uint size);
uint arraySize( uchar* heap, href index );
uint arrayCapacity( uchar* heap, href index );
href arrayGet( uchar* heap, href heapIndex, int index );
void arraySet( uchar* heap, href heapIndex, int index, href val );

//TODO direct expansion
//if next memory chunk is free, grow current chunk and shrink/absorb next chunk. Avoids array copy for resizing :)

#endif