#ifndef HEAP_STRINGS
#define HEAP_STRINGS

#include"common.cl"

href heapString(uchar* heap, uint maxHeapSize, href stringTable, string str);
href _heapString(uchar* heap, uint maxHeapSize, href stringTable, string str, uint strLen);

#endif