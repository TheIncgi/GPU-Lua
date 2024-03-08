#ifndef COMPARISON_CL
#define COMPARISON_CL
#include"types.cl"
#include"heapUtils.cl"



bool equals( uchar* heap, uint indexA, uint indexB ) {
    uchar typeA = heap[indexA];
    uchar typeB = heap[indexB];
    
    if( typeA != typeB )
        return false;
    
    switch( typeA ) {
        // case T_NIL:
        case T_BOOL:
            return indexA == indexB; // all bools are heap[1] or heap[3]
        case T_INT:
            return getHeapInt( heap, indexA + 1 ) == getHeapInt( heap, indexB + 1 );
        case T_NATIVE_FUNC:
        case T_NUMBER:
        case T_STRING:
        case T_TABLE:
        case T_FUNC:
        case T_USERDATA:
        case T_ARRAY:
        case T_HASHMAP:
        case T_CLOSURE:
        case T_SUBSTRING:


            break;
    }
}

#endif