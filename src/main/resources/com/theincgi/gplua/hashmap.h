#ifndef HASHMAP_CL
#define HASHMAP_CL
#include"common.cl"

#define MAP_MAX_SEARCH 10


href newHashmap(uchar* heap, uint maxHeapSize, uint capacity);
href hashmapGetKeysPart( uchar* heap, href mapIndex );
href hashmapGetValsPart( uchar* heap, href mapIndex );

bool hashmapPut( uchar* heap, uint maxHeap, href mapIndex, href keyHeapIndex, href valueHeapIndex );
href hashmapGet(uchar* heap, href mapIndex, href key);
href hashmapStringGet(uchar* heap, href mapIndex, string str, uint strLen);

bool hashmapBytesGetIndex(uchar* heap, const href mapIndex, const uchar* dataSrc, const uint dataOffset, const uint dataLen, uint* foundIndex);
bool resizeHashmap(uchar* heap, uint maxHeapSize, href oldHashMapUIndex,  uint newCapacity);

#endif