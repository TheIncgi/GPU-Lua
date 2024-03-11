#include"strings.h"
#include"common.cl"
#include"table.h"
#include"hashmap.h"
#include"heapUtils.h"
#include"types.cl"

href heapString(uchar* heap, uint maxHeapSize, href stringTable, string str, uint strLen) {
    href hashedPart = tableCreateHashedPart( heap, maxHeapSize, stringTable );
    
    if( hashedPart == 0 )
        return 0;

    href existing = hashmapStringGet( heap, hashedPart, str, strLen);
    if( existing > 0 )
        return existing;

    href newString = allocateHeap( heap, maxHeapSize, 6 + strLen );
    if( newString == 0 )
        return 0;

    heap[ newString ] = T_STRING;
    putHeapInt( heap, newString + 1, strLen );
    
    href stringDataStart = newString + 5;
    for(uint i = 0; i < strLen; i++) {
        heap[ stringDataStart + i ] = str[i];
    }

    heap[ stringDataStart + strLen ] = 0; //null terminated, but not counted in length

    tableRawSet( heap, maxHeapSize, stringTable, newString, newString ); //could be a HashSet probably

    return newString;
}
