
#include"hashmap.h"
#include"heapUtils.h"
#include"common.cl"
#include"types.cl"
#include"comparison.cl"
#include"array.h"

href newHashmap(uchar* heap, uint maxHeapSize, uint capacity) {
    href mapIndex = allocateHeap( heap, maxHeapSize, 9);
    if(mapIndex == 0) return 0;

    href keysIndex = newArray( heap, maxHeapSize, capacity);
    if(keysIndex == 0) return 0;

    href valsIndex = newArray( heap, maxHeapSize, capacity);
    if(valsIndex == 0) return 0;

    heap[mapIndex] = T_HASHMAP;
    // putHeapInt( heap, mapIndex + 4,          0);
    putHeapInt( heap, mapIndex + 1, keysIndex );
    putHeapInt( heap, mapIndex + 5, valsIndex );

    return mapIndex;
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

href hashmapStringGet(uchar* heap, href mapIndex, string str, uint strLen) {
    uint hash = hashString( str, strLen );
    href keysPart = getHeapInt( heap, mapIndex + 1);
    href valsPart = getHeapInt( heap, mapIndex + 5);
    uint capacity = arrayCapacity( heap, keysPart );
    uint hashIndex = mapIndex % capacity;
    
    for(uint i = hashIndex, j = 0; j < MAP_MAX_SEARCH; i = (i + 1) % capacity, j++) { //i = search location (array index) | j = search count

        //string equals
        href heapKey = arrayGet(heap, keysPart, i);
        
        if(heap[heapKey] != T_STRING)
            continue; //not even a string
        
        uint heapStrLen = getHeapInt(heap, heapKey + 1);
        if( heapStrLen != strLen )
            continue; //length mismatch

        bool match = true;
        for(uint s = 0; s < strLen; s++) {
            if(heap[heapKey + 5 + s] != str[s]) {
                match = false;
                break;
            }
        }
        if( !match )
            continue;
        
        return heapKey;
    }
    return 0;
}

//no logic is implemented for scaling down to check that the elements will fit in the shrunk map
//new capacity may be larger than requested 
bool resizeHashmap(uchar* heap, uint maxHeapSize, href mapIndex,  uint newCapacity) {
    href oldKeysPart = getHeapInt( heap, mapIndex + 1 );
    href oldValsPart = getHeapInt( heap, mapIndex + 5 );
    uint oldCapacity = arrayCapacity( heap, oldKeysPart );
    
    href newKeysPart = newArray( heap, maxHeapSize, newCapacity );
    if(newKeysPart == 0) return false;

    href newValsPart = newArray( heap, maxHeapSize, newCapacity );
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