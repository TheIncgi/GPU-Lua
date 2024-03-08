#ifndef COMPARISON_CL
#define COMPARISON_CL
#include"types.cl"
#include"heapUtils.cl"



bool heapEquals( uchar* heap, uint indexA, uint indexB ) {
    uchar typeA = heap[indexA];
    uchar typeB = heap[indexB];
    
    if( typeA != typeB )
        return false;
    
    switch( typeA ) {
        // case T_NIL:
        case T_BOOL:          //all bools are heap[1] or heap[3]
        case T_USERDATA:     //probably not even used
        case T_CLOSURE:     //
        case T_STRING:     //should be reused
        case T_SUBSTRING: //also in be string map and be re-used
        case T_ARRAY:    //not checking contents
        case T_HASHMAP: //also not checking contents
        case T_TABLE:  //TODO: metatable __eq
            return indexA == indexB;

        case T_INT:
        case T_NATIVE_FUNC:
        case T_FUNC:
            return getHeapInt( heap, indexA + 1 ) == getHeapInt( heap, indexB + 1 );

        case T_NUMBER:
            return getHeapInt( heap, indexA + 1 ) == getHeapInt( heap, indexB + 1 )
                && getHeapInt( heap, indexA + 5 ) == getHeapInt( heap, indexB + 5 );



        default:
            return false;
    }
}

#endif