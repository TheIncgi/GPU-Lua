#ifndef HEAP_UTILS_CL
#define HEAP_UTILS_CL
#include"common.cl"
// #include <CL/cl.h>
//See Algorithms: https://gee.cs.oswego.edu/dl/html/malloc.html
//This implementation uses Boundray Tags
//Heap[0] is not used, the value is always 0 which is also the NIL type
//
//Mark and Sweep is used for garbage collection: https://www.geeksforgeeks.org/mark-and-sweep-garbage-collection-algorithm/
//max chunk size is 1GB when using 30bits of space, likely plenty for normal use
//
//Memory:
//  0 | NIL
//  1 | [used:1][mark:!][Chunk size:30]
//  2 | <heap value>
//  N | [used:1][mark:!][Chunk size:30]
// N+1| <heap value>
// ...
//
//chunk size includes it self
//adding [current index] + [chunk size] will give you the index of the next boundry tag

//                  AABBCCDD
#define  USE_FLAG 0x80000000
#define MARK_FLAG 0x40000000
#define SIZE_MASK 0x3FFFFFFF
#define HEAP_RESERVE 5

int getHeapInt(const uchar* heap, const href index);
void putHeapInt(uchar* heap, const href index, const uint value);

void initHeap(uchar* heap, uint maxHeap);
href allocateHeap(uchar* heap, uint maxHeap, uint size);
href allocateNumber( uchar* heap, uint maxHeap, double value );
href allocateInt( uchar* heap, uint maxHeap, int value );


uint heapObjectLength(const uchar* heap, const href index);
uint heapObjectGrowthLimit( uchar* heap, uint maxHeapSize, href index );
uint _hashCode(const  uchar* bytes, const int offset, const int length);

//return the hash code for an int object without needing it on the heap
uint hashInt( int value );
uint hashString( string str, uint len );
uint heapHash(uchar* heap, href obj);
void freeHeap(uchar* heap, uint maxHeap, href index, bool mergeMarked);

void _markHeap( uchar* heap, uint maxHeap, href index);
void _setMarkTag(uchar* heap, href index, bool marked);
void _markHeapArray(uchar* heap, uint maxHeap, href index);
void _markHeapHashmap(uchar* heap, uint maxHeap, href index);
void _markHeapClosure(uchar* heap, uint maxHeap, href index);
void _markHeapSubstring(uchar* heap, uint maxHeap, href index);
void _markHeapTable(uchar* heap, uint maxHeap, href index);
void _markNativeFunc(uchar* heap, uint maxHeap, href index);

void markHeap( uint* luaStack, uchar* heap, uint maxHeap, href globalsIndex );
void sweepHeap( uchar* heap, uint maxHeap );

#endif