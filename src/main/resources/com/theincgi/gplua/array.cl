#include"array.h"
#include"common.cl"
#include"heapUtils.h"
#include"types.cl"


href newArray(uchar* heap, uint maxHeap, uint capacity ) {
    href array = _allocateArray(heap, maxHeap, capacity);
    
    if( array == 0 ) 
        return 0;

    arrayClear( heap, array );
    return array;
}

//size is number of uints
href _allocateArray(uchar* heap, uint maxHeap, uint size) {
    uint byteSize = 9 + size * 4;
    href array = allocateHeap( heap, maxHeap, byteSize );
    
    //allocation check
    if(array == 0)
        return 0;
    
    heap[array] = T_ARRAY;
    putHeapInt( heap, array + 1,    0 );   //current length
    putHeapInt( heap, array + 5, size );   //capacity
    
    return array;
}

void arrayClear(uchar* heap, href heapIndex) {
    uint capacity = arrayCapacity( heap, heapIndex );
    uint byteSize = 9 + capacity * 4;
    putHeapInt( heap, heapIndex + 1,    0 );   //current length
    for( int i = heapIndex + 9; i < heapIndex + byteSize; i++ ) {
        heap[i] = 0;
    }
}

//number of href that are stored
uint arraySize( uchar* heap, href index ) {
    return getHeapInt( heap, index + 1);
}

//number of href that can be stored
uint arrayCapacity( uchar* heap, href index ) {
    return getHeapInt( heap, index + 5 );
}

href arrayGet( uchar* heap, href heapIndex, int index ) {
    return getHeapInt( heap, heapIndex + 9 + index * 4 );
}

void arraySet( uchar* heap, href heapIndex, int index, href val ) {
    uint valPos = heapIndex + 9 + index * 4;
    uint size = arraySize( heap, heapIndex );

    putHeapInt( heap, valPos, val );

    if( val == 0 ) {
        if( index == size-1 ) { //last element
            //reduce size by 1
            putHeapInt( heap, heapIndex + 1, size - 1 );
        } else { //find first nil
            uint capacity = arrayCapacity( heap, heapIndex );
            uint newSize = capacity;
            for(int i = 0; i < capacity; i++) {
                if(arrayGet( heap, heapIndex, i) == 0)
                    newSize = i;
                    break;
            }
            putHeapInt( heap, heapIndex + 1, newSize );
        }
    } else if( arraySize( heap, heapIndex) <= index ) {
        putHeapInt( heap, heapIndex + 1, index + 1 );
    }
}

//if the array can be resized in place, does that, returns heapIndex
//else, returns new href to the copied array
//old array will be freed if so
href arrayResize( uchar* heap, uint maxHeapSize, href heapIndex, uint newCapacity ) {
    uint oldCapacity = arrayCapacity( heap, heapIndex );
    uint growthCapacity = heapObjectGrowthLimit( heap, maxHeapSize, heapIndex );
    
    //try to expand in place
    if( oldCapacity + (ulong)growthCapacity > newCapacity ) {
        //TODO grow object, not implemented in heapUtils yet
        //return heapIndex;
    }

    href newArray = _allocateArray( heap, maxHeapSize, newCapacity ); //new, but without setting values to 0
    uint copyLimit = oldCapacity < newCapacity ? newCapacity : oldCapacity; //min

    href oldArrayStart = heapIndex + 9;
    href newArrayStart = newArray + 9;

    for(uint i = 0; i < copyLimit; i++) { //*4 because byte, not index
        href newArrayRef = newArrayStart + i * 4;
        
        if( i < oldCapacity ) { //exists in old array
            href oldArrayRef = oldArrayStart + i * 4;

            heap[ newArrayRef     ] = heap[ oldArrayRef     ];
            heap[ newArrayRef + 1 ] = heap[ oldArrayRef + 1 ];
            heap[ newArrayRef + 2 ] = heap[ oldArrayRef + 2 ];
            heap[ newArrayRef + 3 ] = heap[ oldArrayRef + 3 ];

        } else { //out of bounds in old array
            heap[ newArrayRef     ] = 0;
            heap[ newArrayRef + 1 ] = 0;
            heap[ newArrayRef + 2 ] = 0;
            heap[ newArrayRef + 3 ] = 0;
        }

        
    }

    freeHeap(heap, heapIndex); //checkMe

    return newArray;
}