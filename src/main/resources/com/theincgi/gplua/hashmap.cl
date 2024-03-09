#ifndef HASHMAP_CL
#define HASHMAP_CL

#define MAP_MAX_SEARCH 10

#include"heapUtils.h"
#include"common.cl"
#include"types.cl"
#include"comparison.cl"
#include"array.h"

bool resizeHashmap(uchar* heap, uint maxHeapSize, href oldHashMapUIndex,  uint newCapacity);



href newHashmap(uchar* heap, uint maxHeapSize, uint capacity) {
    href mapIndex = allocateHeap( heap, maxHeapSize, 13);
    if(mapIndex == 0) return 0;

    href keysIndex = allocateArray( heap, maxHeapSize, capacity);
    if(keysIndex == 0) return 0;

    href valsIndex = allocateArray( heap, maxHeapSize, capacity);
    if(valsIndex == 0) return 0;

    heap[mapIndex] = T_HASHMAP;
    putHeapInt( heap, mapIndex + 4,          0); //current number of elements, used for quick checks to resize
    putHeapInt( heap, mapIndex + 5, keysIndex );
    putHeapInt( heap, mapIndex + 9, valsIndex );

    // putHeapInt( heap, keysIndex + 1, capacity); //mark as full use since values may be spread out
    // putHeapInt( heap, valsIndex + 1, capacity); //mark as full use since values may be spread out
}

bool hashmapPut( uchar* heap, uint maxHeap, href mapIndex, href keyHeapIndex, href valueHeapIndex ) {
    uint keyHash  = heapHash( heap, keyHeapIndex ); 
    href keysPart = getHeapInt( heap, mapIndex + 1);
    href valsPart = getHeapInt( heap, mapIndex + 5);
    uint size     = arraySize( heap, keysPart );
    uint capacity = arrayCapacity( heap, keysPart );
    bool isErase  = valueHeapIndex == 0;
    uint hashIndex = keyHash % capacity;

    bool foundEmpty = false;
    uint firstEmpty = 0;
    for(uint i = hashIndex, j = 0; j < MAP_MAX_SEARCH; i = (i + 1) % capacity, j++) {
        href globalKeyIndex = keysPart + i;
        if(heapEquals( heap, arrayGet(heap, keysPart, i), keyHeapIndex)) { //value in stored keys == provided key

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
        if( !resizeHashmap( heap, maxHeap, mapIndex, resizeRule(capacity) )) // min(cap+128, cap*2)
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

href hashmapGet(uchar* heap, href mapIndex, href key) {
    uint hash = heapHash( heap, key );
    href keysPart = getHeapInt( heap, mapIndex + 1);
    href valsPart = getHeapInt( heap, mapIndex + 5);
    uint capacity = arrayCapacity( heap, keysPart );
    uint hashIndex = mapIndex % capacity;

    for(uint i = hashIndex, j = 0; j < MAP_MAX_SEARCH; i = (i + 1) % capacity, j++) { //i = search location (array index) | j = search count
        if(heapEquals( heap, arrayGet(heap, keysPart, i), key)) { //value in stored keys == provided key
            return arrayGet( heap, valsPart, i );
        } 
    }
    return 0;
}

//no logic is implemented for scaling down to check that the elements will fit in the shrunk map
//new capacity may be larger than requested 
bool resizeHashmap(uchar* heap, uint maxHeapSize, href mapIndex,  uint newCapacity) {
    href oldKeysPart = getHeapInt( heap, mapIndex + 1 );
    href oldValsPart = getHeapInt( heap, mapIndex + 5 );
    uint oldCapacity = arrayCapacity( heap, oldKeysPart );
    
    href newKeysPart = allocateArray( heap, maxHeapSize, newCapacity );
    if(newKeysPart == 0) return false;

    href newValsPart = allocateArray( heap, maxHeapSize, newCapacity );
    if(newValsPart == 0) return false;

    for(int i = 0; i < oldCapacity; i++) {
        href key = arrayGet( heap, oldKeysPart, i );
        href val = arrayGet( heap, oldValsPart, i );
        if( key == 0 ) continue;
        uint keyHash  = heapHash( heap, key );
        
        bool assigned = false;
        for(uint slot = keyHash % newCapacity, j = 0; j < MAP_MAX_SEARCH; slot = (slot + 1) % newCapacity, j++ ) {
            uint slotKey = arrayGet( heap, newKeysPart, slot );
            if( slot == 0 ) { //empty
                arraySet( heap, newKeysPart, slot, key );
                arraySet( heap, newValsPart, slot, val );
                assigned = true;
                break;
            }
        }

        //too dense
        if( !assigned ) {
            freeHeap( heap, maxHeapSize, newKeysPart, false );
            freeHeap( heap, maxHeapSize, newValsPart, false );
            // min(cap+128, cap*2)
            uint newerCapacity =  resizeRule(newCapacity);
            return resizeHashmap( heap, maxHeapSize, mapIndex, newerCapacity);
        }
    }

    putHeapInt( heap, mapIndex + 1, newKeysPart );
    putHeapInt( heap, mapIndex + 5, newValsPart);

    freeHeap( heap, maxHeapSize, oldKeysPart, false );
    freeHeap( heap, maxHeapSize, oldValsPart, false );

    return true;
}

#endif