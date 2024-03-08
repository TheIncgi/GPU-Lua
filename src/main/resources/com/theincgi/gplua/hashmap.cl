#ifndef HASHMAP_CL
#define HASHMAP_CL

#include"heapUtils.cl"
#include"types.cl"

/** Compute the hash code of a sequence of bytes within a byte array using
    * lua's rules for string hashes.  For long strings, not all bytes are hashed.
    * @param bytes  byte array containing the bytes.
    * @param offset  offset into the hash for the first byte.
    * @param length number of bytes starting with offset that are part of the string.
    * @return hash for the string defined by bytes, offset, and length.
    * <br>
    * Sourced from LuaJ
    */
uint hashCode(uchar* bytes, int offset, int length) {
    int h = length;  /* seed */
    int step = (length>>5)+1;  /* if string is too long, don't hash all its chars */
    for (int l1=length; l1>=step; l1-=step)  /* compute hash */
        h = h ^ ((h<<5)+(h>>2)+(((int) bytes[offset+l1-1] ) & 0x0FF ));
    return h;
}

uint newHashmap(uchar* heap, uint maxHeapSize, uint capacity) {
    uint mapIndex = allocateHeap( heap, maxHeapSize, 13);
    if(mapIndex == 0) return 0;

    uint keysIndex = allocateArray( heap, maxHeapSize, capacity);
    if(keysIndex == 0) return 0;

    uint valsIndex = allocateArray( heap, maxHeapSize, capacity);
    if(valsIndex == 0) return 0;

    heap[mapIndex] = T_HASHMAP;
    putHeapInt( heap, mapIndex + 4,          0); //current number of elements, used for quick checks to resize
    putHeapInt( heap, mapIndex + 5, keysIndex );
    putHeapInt( heap, mapIndex + 9, valsIndex );

    putHeapInt( heap, keysIndex + 1, capacity); //mark as full use since values may be spread out
    putHeapInt( heap, valsIndex + 1, capacity); //mark as full use since values may be spread out
}

bool hashmapPut( uchar* heap, uint maxHeap, uint mapIndex, uint keyHeapIndex, uint valueHeapIndex ) {
    uint keyHash = hashCode( heap, keyHeapIndex, heapObjectLength(heap, keyHeapIndex)); 
    uint size     = getHeapInt( heap, mapIndex + 1);
    uint keysPart = getHeapInt( heap, mapIndex + 5);
    uint capacity = getHeapInt( heap, keysPart + 5);
    uint hashIndex = keyHash % capacity;

    uint firstEmpty = 0;
    for(uint i = hashIndex, j = 0; j < capacity; i = (i + 1) % capacity, j++) {
        /*
        if equals
            set value
            return true
        if empty and firstEmpty == 0
            firstEmpty = i + keysPart
         */
    }
    /*
    if firstEmpty != 0
        set value
    else //size == capacity
        resize -> false? return false;
    hashIndex = *new value*
    for (same loop again)
        set value on empty
    return true
     */
}

bool resizeHashmap(uchar* heap, uint maxHeapSize, uint oldHashMapUIndex,  uint newCapacity) {

}

#endif