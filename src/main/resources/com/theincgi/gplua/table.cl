#include"table.h"
#include"common.cl"
#include"heapUtils.h"
#include"array.h"

//may return 0 if not enough memory
uint newTable(uchar* heap, uint maxHeapSize) {
    //no array, hash or metatable filled in on a new table
    return allocateHeap( heap, maxHeapSize, 13);
}

uint tableGetArrayPart( uchar* heap, href heapIndex ) {
    return getHeapInt( heap, heapIndex + 1 );
}

uint tableGetHashedPart( uchar* heap, href heapIndex ) {
    return getHeapInt( heap, heapIndex + 5 );
}

uint tableGetMetatable( uchar* heap, href heapIndex ) {
    return getHeapInt( heap, heapIndex + 9 );
}

//This return uint is the raw length, not a heap index like most other functions
uint tableLen( uchar* heap, href heapIndex ) {
    href arrayPart = tableGetArrayPart( heap, heapIndex);
    if( arrayPart == 0 )
        return 0;
    return arraySize( heap, arrayPart );
}

uint tableCreateArrayPart( uchar* heap, uint maxHeapSize, href tableHeapIndex ) {
    href current = tableGetArrayPart(heap, tableHeapIndex );
    if( current != 0 )
        return current; //already exists
    
    href arrayPart = allocateArray( heap, maxHeapSize, TABLE_INIT_ARRAY_SIZE );
    
    if( arrayPart == 0 )
        return false; //couldn't create array

    putHeapInt( heap, tableHeapIndex + 1, arrayPart );
    return arrayPart; //created
}

uint tableRawGet( uchar* heap, href heapIndex, href key ) {
    href arrayPart = tableGetArrayPart( heap, heapIndex );
    if( arrayPart == 0 )
        return 0;
}

bool tableRawSet( uchar* heap, uint maxHeapSize, href heapIndex, href key, href value ) {

}