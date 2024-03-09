#include"array.h"
#include"common.cl"
#include"heapUtils.h"
#include"types.cl"


//size is number of uints
href allocateArray(uchar* heap, uint maxHeap, uint size) {
    uint byteSize = 9 + size * 4;
    href array = allocateHeap( heap, maxHeap, byteSize );
    
    //allocation check
    if(array == 0)
        return 0;
    
    heap[array] = T_ARRAY;
    putHeapInt( heap, array + 1,    0 );   //current length
    putHeapInt( heap, array + 5, size );   //capacity
    for( int i = array + 9; i < array + byteSize; i++ ) {
        heap[i] = 0;
    }
    return array;
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