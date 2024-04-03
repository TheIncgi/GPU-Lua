#ifndef COMPARISON_CL
#define COMPARISON_CL
#include"common.cl"
#include"types.cl"
#include"heapUtils.h"



bool heapEquals( struct WorkerEnv* env, uchar* dataSourceA, href indexA, uchar* dataSourceB, href indexB ) {
    uchar* heap = dataSourceA;
    
    if( indexA == indexB )
        return true;
    
    uchar typeA = heap[indexA];
    uchar typeB = heap[indexB];
    
    if( typeA != typeB )
        return false;
    
    switch( typeA ) {
        // case T_NIL:
        case T_BOOL:          //all bools are heap[1] or heap[3]
            return dataSourceA[ indexA + 1 ] == dataSourceB[ indexB + 1 ];

        case T_USERDATA:     //probably not even used
            return false;

        case T_CLOSURE:     //
            return dataSourceA == dataSourceB && dataSourceA == env->heap && indexA == indexB;

        case T_STRING:     //should be reused
            if(dataSourceA == dataSourceB) {
                return indexA == indexB;
            }
            int len = getHeapInt( dataSourceA, indexA + 1 );
            if( len != getHeapInt( dataSourceB, indexB + 1 ))
                return false;

            for(int i = 0; i < len; i++ ) {
                if( dataSourceA[ indexA + i ] != dataSourceB[ indexB + i ] )
                    return false;
            }
            return true;

        // case T_SUBSTRING: //also in be string map and be re-used
        case T_ARRAY:    //not checking contents
        case T_HASHMAP: //also not checking contents
            return dataSourceA == dataSourceB && dataSourceA == env->heap && indexA == indexB;
            
        case T_TABLE:  //TODO: metatable __eq
            return indexA == indexB;

        case T_INT:
        case T_NATIVE_FUNC:
        case T_FUNC:
            return getHeapInt( dataSourceA, indexA + 1 ) == getHeapInt( dataSourceB, indexB + 1 );

        case T_NUMBER: {
            double x, y;
            _readAsDouble( dataSourceA, indexA, &x ); //from vm.h
            _readAsDouble( dataSourceA, indexB, &y ); //from vm.h

            return x == y;
        }

        default:
            return false;
    }
}

#endif