#include"table.h"
#include"common.cl"
#include"heapUtils.h"
#include"array.h"
#include"hashmap.h"
#include"types.cl"

//may return 0 if not enough memory
href newTable(uchar* heap, uint maxHeapSize) {
    //no array, hash or metatable filled in on a new table
    href index = allocateHeap( heap, maxHeapSize, 13);
    heap[index] = T_TABLE;
    return index;
}

href tableGetArrayPart( uchar* heap, href heapIndex ) {
    return getHeapInt( heap, heapIndex + 1 );
}

href tableGetHashedPart( uchar* heap, href heapIndex ) {
    return getHeapInt( heap, heapIndex + 5 );
}

href tableGetMetatable( uchar* heap, href heapIndex ) {
    return getHeapInt( heap, heapIndex + 9 );
}

uint tableLen( uchar* heap, href heapIndex ) {
    href arrayPart = tableGetArrayPart( heap, heapIndex);
    if( arrayPart == 0 )
        return 0;
    return arraySize( heap, arrayPart );
}

href tableCreateArrayPart( uchar* heap, uint maxHeapSize, href tableHeapIndex ) {
    href current = tableGetArrayPart( heap, tableHeapIndex );
    if( current != 0 )
        return current; //already exists
    
    href arrayPart = newArray( heap, maxHeapSize, TABLE_INIT_ARRAY_SIZE );
    
    if( arrayPart == 0 )
        return false; //couldn't create array

    putHeapInt( heap, tableHeapIndex + 1, arrayPart );
    return arrayPart; //created
}

href tableCreateHashedPart( uchar* heap, uint maxHeapSize, href tableHeapIndex ) {
    href current = tableGetHashedPart( heap, tableHeapIndex );
    if( current != 0 )
        return current; //already exists

    href hashedPart = newHashmap( heap, maxHeapSize, HASHMAP_INIT_SIZE );
    
    if( hashedPart == 0 )
        return false; //couldn't create map
    
    putHeapInt( heap, tableHeapIndex + 5, hashedPart );
    return hashedPart; //created
}

href tableRawGet( uchar* heap, href heapIndex, href key ) {
    href arrayPart = tableGetArrayPart( heap, heapIndex );
    uchar keyType = heap[key];

    if( keyType == T_INT && arrayPart != 0 ) {              //int and array part exists
        uint size = arraySize( heap, arrayPart );
        int keyIndex = getHeapInt( heap, key + 1 ) - 1;         //SIGNED int, convert from 1 to 0 indexed

        if( 0 <= keyIndex && keyIndex < size ) {            //in bounds of the array part (else check hashed part)
            return arrayGet( heap, arrayPart, keyIndex );   //found it in array part
        }
    }
    
    href hashedPart = tableGetHashedPart( heap, heapIndex );
    return hashmapGet( heap, hashedPart, key );
}

bool tableResizeArray( uchar* heap, uint maxHeapSize, href tableIndex, uint newSize ) {
    href oldArray = tableGetArrayPart( heap, tableIndex );
    href newArray = arrayResize( heap, maxHeapSize, oldArray, newSize );
    if( newArray == 0 )
        return false;
    if(oldArray != newArray)
        putHeapInt( heap, tableIndex + 1, newArray );
    return true;
}

bool tableRawSet( uchar* heap, uint maxHeapSize, href tableIndex, href key, href value ) {
    uchar keyType = heap[key];
    bool  erase   = heap[value] == 0;
    if( keyType == T_INT ) {
        int keyIndex = getHeapInt( heap, key + 1 ) - 1;     //signed, convert from 1 to 0 indexing
        href arrayPart = tableGetArrayPart( heap, tableIndex );
        
        //initialize if index is in the first TABLE_INIT_ARRAY_SIZE slots
        if( arrayPart == 0 && 0 <= keyIndex && keyIndex < TABLE_INIT_ARRAY_SIZE)
            arrayPart = tableCreateArrayPart( heap, maxHeapSize, tableIndex );

        if( arrayPart != 0 ) {
            uint capacity = arrayCapacity( heap, arrayPart );

            if( 0 <= key && key <= capacity ) {                 //in array range, including end (first empty)
                if( key == capacity ) {                         //appending, may need to grow array
                    //erase is skipped incase it's in the hash part
                    if( !erase && tableResizeArray( heap, maxHeapSize, tableIndex, resizeRule( capacity ))) {
                        arraySet( heap, arrayPart, keyIndex, value );
                        return true;
                    } //if resizing fails we'll try the hash part claiming out of memory
                } else {
                    arraySet( heap, arrayPart, keyIndex, value ); //in bounds
                }
            } //out of bounds? will use the hash
        }
    }

    href hashedPart = tableCreateHashedPart( heap, maxHeapSize, tableIndex );
    if( hashedPart == 0 )
        return false; //out of memory

    return hashmapPut( heap, maxHeapSize, hashedPart, key, value );
}