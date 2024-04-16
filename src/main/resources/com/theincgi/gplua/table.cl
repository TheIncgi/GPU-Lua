#include"table.h"
#include"common.cl"
#include"heapUtils.h"
#include"array.h"
#include"hashmap.h"
#include"types.cl"
#include"vm.h"

//may return 0 if not enough memory
href newTable(uchar* heap, uint maxHeapSize) {
    //no array, hash or metatable filled in on a new table
    href index = allocateHeap( heap, maxHeapSize, 13);
    heap[index] = T_TABLE;
    for(uint i = 1; i < 13; i++)
        heap[index+i] = 0;
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
    return tableCreateArrayPartWithSize( heap, maxHeapSize, tableHeapIndex, TABLE_INIT_ARRAY_SIZE );
}

href tableCreateArrayPartWithSize( uchar* heap, uint maxHeapSize, href tableHeapIndex, uint initalSize ) {
    href current = tableGetArrayPart( heap, tableHeapIndex );
    if( current != 0 )
        return current; //already exists
    
    href arrayPart = newArray( heap, maxHeapSize, initalSize );
    
    if( arrayPart == 0 )
        return false; //couldn't create array

    putHeapInt( heap, tableHeapIndex + 1, arrayPart );
    return arrayPart; //created
}

href tableCreateHashedPart( uchar* heap, uint maxHeapSize, href tableHeapIndex ) {
    return tableCreateHashedPartWithSize( heap, maxHeapSize, tableHeapIndex, HASHMAP_INIT_SIZE );
}

href tableCreateHashedPartWithSize( uchar* heap, uint maxHeapSize, href tableHeapIndex, uint initalSize ) {
    href current = tableGetHashedPart( heap, tableHeapIndex );
    if( current != 0 )
        return current; //already exists

    href hashedPart = newHashmap( heap, maxHeapSize, initalSize );
    
    if( hashedPart == 0 )
        return false; //couldn't create map
    
    putHeapInt( heap, tableHeapIndex + 5, hashedPart );
    return hashedPart; //created
}

// bool tableHashContainsKey( uchar* heap, href tableIndex, uchar* keySource, uint keyIndex, uint keyLen, uint* foundIndex ) {
//     href hashPart = tableGetHashedPart( heap, tableIndex );
//     if( hashPart == 0 ) return false;

//     return hashmapBytesGetIndex( heap, hashPart, keySource, keyIndex, keyLen, foundIndex );
// }

// bool tableArrayContainsKey( uchar* heap, href tableIndex, uint indexInTable) {
//     href arrayPart = tableGetArrayPart( heap, tableIndex );
//     return arrayPart != 0;
// }

href tableRawGet( uchar* heap, href tableIndex, uchar* keySource, uint keyIndex, uint keyLen ) {
    uchar keyType = keySource[keyIndex];
    if( keyType == T_INT ) {
        int key = getHeapInt( keySource, keyIndex + 1 );
        href arrayPart = tableGetArrayPart( heap, tableIndex );
        if( arrayPart != 0 ) {
            if( 0 <= key && key < arraySize( heap, arrayPart ) ) {
                return arrayGet( heap, arrayPart, key );
            }
        }
    }

    href hashedPart = tableGetHashedPart( heap, tableIndex );
    if( hashedPart == 0 ) return 0;

    uint foundIndex;
    if(hashmapBytesGetIndex( heap, hashedPart, keySource, keyIndex, keyLen, &foundIndex )) {
        href valsPart = hashmapGetValsPart( heap, hashedPart );
        return arrayGet( heap, valsPart, foundIndex );
    }
    
    return 0;
}

// href tableRawGet( uchar* heap, href heapIndex, href key ) {
//     href arrayPart = tableGetArrayPart( heap, heapIndex );
//     uchar keyType = heap[key];

//     if( keyType == T_INT && arrayPart != 0 ) {              //int and array part exists
//         uint size = arraySize( heap, arrayPart );
//         int keyIndex = getHeapInt( heap, key + 1 ) - 1;         //SIGNED int, convert from 1 to 0 indexed

//         if( 0 <= keyIndex && keyIndex < size ) {            //in bounds of the array part (else check hashed part)
//             return arrayGet( heap, arrayPart, keyIndex );   //found it in array part
//         }
//     }
    
//     href hashedPart = tableGetHashedPart( heap, heapIndex );
//     return hashmapGet( heap, hashedPart, key );
// }



bool tableResizeArray( uchar* heap, uint maxHeapSize, href tableIndex, uint newSize ) {
    href oldArray = tableGetArrayPart( heap, tableIndex );
    uint oldSize = arraySize( heap, oldArray );

    href newArray = arrayResize( heap, maxHeapSize, oldArray, newSize );
    if( newArray == 0 )
        return false;
    if(oldArray != newArray)
        putHeapInt( heap, tableIndex + 1, newArray );

    uchar intBuf[5];
    intBuf[0] = T_INT;
    href hashedPart = tableGetHashedPart( heap, tableIndex );
    if( hashedPart != 0 ) {
        href hashedKeys = hashmapGetKeysPart( heap, hashedPart );
        href hashedVals = hashmapGetValsPart( heap, hashedPart );

        for( uint i = oldSize; i < newSize; i++ ) {
            putHeapInt( intBuf, 1, i );

            uint* foundIndex;
            if( hashmapBytesGetIndex( heap, hashedPart, intBuf, 0, 5, foundIndex ) ) {
                href foundValue = arrayGet( heap, hashedVals, *foundIndex );
                arraySet( heap, newArray, i, foundValue );   //move into array part
                arraySet( heap, hashedKeys, *foundIndex, 0 ); //remove from hashmap
                arraySet( heap, hashedVals, *foundIndex, 0 ); //remove from hasmmap
            }
        }
    }
    return true;
}

bool tableRawSet( struct WorkerEnv* env, href tableIndex, href key, href value ) {
    uchar* heap = env->heap;
    uint maxHeapSize = env->maxHeapSize;
    uchar keyType = heap[key];
    bool  erase   = value == 0;
    if( keyType == T_INT ) {
        int keyIndex = getHeapInt( heap, key + 1 ) - 1;     //signed, convert from 1 to 0 indexing
        href arrayPart = tableGetArrayPart( heap, tableIndex );
        
        //initialize if index is in the first TABLE_INIT_ARRAY_SIZE slots
        if( arrayPart == 0 && 0 <= keyIndex && keyIndex < TABLE_INIT_ARRAY_SIZE)
            arrayPart = tableCreateArrayPart( heap, maxHeapSize, tableIndex );

        if( arrayPart != 0 ) {
            uint capacity = arrayCapacity( heap, arrayPart );
            printf("tableRawSet 0 <= %d <= %d\n", keyIndex, capacity);
            if( 0 <= keyIndex && keyIndex <= capacity ) {                 //in array range, including end (first empty)
                if( keyIndex == capacity ) {                         //appending, may need to grow array
                    //erase is skipped incase it's in the hash part
                    if( !erase && tableResizeArray( heap, maxHeapSize, tableIndex, resizeRule( capacity ))) {
                        arrayPart = tableGetArrayPart( heap, tableIndex ); // may have changed
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

    return hashmapPut( env, hashedPart, key, value );
}

//For use with setlist op to avoid temp heap values
//arrayPart & arraySize/capacity will be solved if arrayPart is 0
bool tableSetList( struct WorkerEnv* env, href tableIndex, href* arrayPart, uint* size, uint* cap, uint key, href value ) {
    if( *arrayPart == 0 ) {
        *arrayPart = tableCreateArrayPart( env->heap, env->maxHeapSize, tableIndex ); //probably already created, but just to be safe
        *size = arraySize( env->heap, *arrayPart );
        *cap  = arrayCapacity( env->heap, *arrayPart );
    }
    
    if( (key-1) < *cap ) {
        arraySet( env->heap, *arrayPart, key-1, value );
        *size = *size + 1;
        return true;
    } else {
        href hkey = allocateInt( env->heap, env->maxHeapSize, key );
        return tableRawSet( env, tableIndex, hkey, value );
    }
}

href tableGetMetaEvent( struct WorkerEnv* env, href table, string eventName ) {
    href meta = tableGetMetatable( env->heap, table );
    if( meta == 0 ) return 0;

    href metahash = tableGetHashedPart( env->heap, meta );
    if( metahash == 0 ) return 0;

    string metakey = "__newindex";
    href metaIndex = hashmapStringGet( env->heap, metahash, eventName, strLen( eventName ));
    return metaIndex;
}

href tableGetMetaIndex( struct WorkerEnv* env, href table ) {
    string metakey = "__index";
    return tableGetMetaEvent( env, table, metakey );
}

href tableGetMetaNewIndex( struct WorkerEnv* env, href table ) {
    string metakey = "__newindex";
    return tableGetMetaEvent( env, table, metakey );
}

href _tableRecurseGetByHeap( struct WorkerEnv* env, href table, href key ) {
    return tableGetByHeap( env, table, key );
}

href tableGetByHeap( struct WorkerEnv* env, href table, href key ) {
    uint keySize = heapObjectLength( env->heap, key );

    href value = 0;
    while( table != 0 && value == 0 ) {
        value = tableRawGet( env->heap, table, env->heap, key, keySize );
        if( value != 0 ) return value;

        href metaIndex = tableGetMetaIndex( env, table );
        if( metaIndex == 0 ) return 0;
        uchar indexType = env->heap[ metaIndex ];
        if( indexType == T_TABLE ) {
            table = metaIndex;
            continue;
        } else if ( indexType == T_FUNC ) {
            return 0; //TODO call
        }
        return 0;
    }
    return 0;
}


href tableGetByConst( struct WorkerEnv* env, href table, int key ) {
    if(table == 0) return 0;
    uint constStart, constLen;
    getConstDataRange( env, key, &constStart, &constLen );

    if(constLen == 0) return 0;
    
    href value = 0;
    while( table != 0 && value == 0 ) {
        value = tableRawGet( env->heap, table, env->constantsData, constStart, constLen );
        if( value != 0 ) return value;
        
        href metaIndex = tableGetMetaIndex( env, table );

        if( metaIndex == 0 ) return 0;
        uchar metaIndexType = env->heap[ metaIndex ];
        if( metaIndexType == T_TABLE ) {
            table = metaIndex;
            continue;
        } else if ( metaIndexType == T_FUNC ) {
            return 0; //TODO call
        }
        return 0;
    }
    return 0;
}