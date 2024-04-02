#include"strings.h"
#include"common.cl"
#include"table.h"
#include"hashmap.h"
#include"heapUtils.h"
#include"types.cl"

href heapString(struct WorkerEnv* env, string str) {
    return _heapString( env, str, strLen(str));
}

href _heapString(struct WorkerEnv* env, string str, uint strLen) {
    uchar* heap = env->heap;
    uint maxHeapSize = env->maxHeapSize;
    href stringTable = env->stringTable;
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

    if( !tableRawSet( env, stringTable, newString, newString )) //could be a HashSet probably
        return 0;

    return newString;
}
