#ifndef ARRAY_CL
#define ARRAY_CL

#include"heapUtils.cl"

uint arraySize( uchar* heap, uint index ) {
    return getHeapInt( heap, index + 1);
}

uint arrayCapacity( uchar* heap, uint index ) {
    return getHeapInt( heap, index + 5 );
}

uint arrayGet( uchar* heap, uint heapIndex, int index ) {
    return getHeapInt( heap, heapIndex + 9 + index * 4 );
}

void arraySet( uchar* heap, uint heapIndex, int index, int val ) {
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




#endif