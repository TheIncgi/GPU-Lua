#ifndef HASHMAP_CL
#define HASHMAP_CL

#define MAP_MAX_SEARCH 10

#include"heapUtils.cl"
#include"types.cl"
#include"comparison.cl"
#include"array.cl"

bool resizeHashmap(uchar* heap, uint maxHeapSize, uint oldHashMapUIndex,  uint newCapacity);

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

    // putHeapInt( heap, keysIndex + 1, capacity); //mark as full use since values may be spread out
    // putHeapInt( heap, valsIndex + 1, capacity); //mark as full use since values may be spread out
}

bool hashmapPut( uchar* heap, uint maxHeap, uint mapIndex, uint keyHeapIndex, uint valueHeapIndex ) {
    uint keyHash  = hashCode( heap, keyHeapIndex, heapObjectLength(heap, keyHeapIndex)); 
    uint keysPart = getHeapInt( heap, mapIndex + 1);
    uint valsPart = getHeapInt( heap, mapIndex + 5);
    uint size     = arraySize( heap, keysPart );
    uint capacity = arrayCapacity( heap, keysPart );
    bool isErase  = valueHeapIndex == 0;
    uint hashIndex = keyHash % capacity;

    bool foundEmpty = false;
    uint firstEmpty = 0;
    for(uint i = hashIndex, j = 0; j < MAP_MAX_SEARCH; i = (i + 1) % capacity, j++) {
        uint globalKeyIndex = keysPart + i;
        if(heapEquals( heap, globalKeyIndex, keyHeapIndex)) { //value in stored keys == provided key

            if( isErase || arrayGet( heap, keysPart, i ) == 0) { //removing value or no key is present
                arraySet( heap, keysPart, i, isErase ? 0 : keyHeapIndex );     //add or remove key
                arraySet( heap, valsPart, i, valueHeapIndex );                //set value
                return true; //found and removed or set
            }    
        } else if( !foundEmpty && arrayGet( heap, keysPart, i) == 0 ) {
            foundEmpty = true;
            firstEmpty = i;
        }
    }

    if( isErase )
        return true; //not found, nothing to remove


    if( foundEmpty ) {
        arraySet( heap, keysPart, firstEmpty, keyHeapIndex );
        arraySet( heap, valsPart, firstEmpty, valueHeapIndex );
        return true;
    } 
    
    //resize until there's a close enough gap or fail
    while(true) {
        if( !resizeHashmap( heap, maxHeap, mapIndex, capacity * 2 > 128 ? 128 : capacity * 2) ) // min(cap+128, cap*2)
            return false;
        

        capacity = arrayCapacity( heap, keysPart );
        hashIndex = keyHash % MAP_MAX_SEARCH;
        for(uint i = hashIndex, j = 0; j < capacity; i = (i + 1) % capacity, j++) {
            if( arrayGet(heap, keysPart, i) == 0 ) {
                arraySet( heap, keysPart, i, keyHeapIndex );     //add key
                arraySet( heap, valsPart, i, valueHeapIndex );  //set value
                return true; //found set
            }
        }
    }
}

bool resizeHashmap(uchar* heap, uint maxHeapSize, uint oldHashMapUIndex,  uint newCapacity) {

}

#endif