#ifndef COMPARISON_CL
#define COMPARISON_CL
#include"common.cl"
#include"types.cl"
#include"heapUtils.h"
#include"vm.h"
#include"errorMsg.cl"


//TODO rename, not just heap anymore
bool heapEquals( struct WorkerEnv* env, uchar* dataSourceA, href indexA, uchar* dataSourceB, href indexB ) {
    if( indexA == indexB )
        return true;
    
    uchar typeA = dataSourceA[indexA];
    uchar typeB = dataSourceB[indexB];
    
    if( typeA != typeB && ( !(isNumber(typeA) && isNumber(typeB)) )) {//different types & not both numbers
        return false;
    }

    switch( typeA ) {
        case T_NIL:
            return true; //types already checked to be the same

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
            
        case T_TABLE: { //TODO: metatable __eq
            if( dataSourceA != dataSourceB || dataSourceA != env->heap ) //all tables are on the heap
                return false;

            if( indexA == indexB ) //equals self
                return true;
            
            string eventName = "__eq";
            href metaA = tableGetMetaEvent( env, indexA, eventName );
            href metaB = tableGetMetaEvent( env, indexB, eventName );
            if( dataSourceA[metaA] == T_CLOSURE ) {
                if( metaA != metaB )
                    return false;
                
                href args[2];
                args[0] = indexA;
                args[1] = indexB;

                return false;
                bool ok = callWithArgs( env, metaA, args, 2 );
                //if not ok, error should be set by callWithArgs
                if(!ok) return false;

                if( env->returnFlag && env->nReturn >= 1) {
                    return isTruthy( env->luaStack[ env->returnStart ] );
                }
            }
            
            return false; //no event or event returned nil
        }

        case T_NATIVE_FUNC:
        case T_FUNC:
            return getHeapInt( dataSourceA, indexA + 1 ) == getHeapInt( dataSourceB, indexB + 1 );

        case T_INT:
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

bool compareLessThan( struct WorkerEnv* env, uchar* dataSourceA, uint indexA, uchar* dataSourceB, uint indexB ) {
    string op = "<" ;

    if( indexA == indexB )
        return false;
    
    uchar typeA = dataSourceA[indexA];
    uchar typeB = dataSourceB[indexB];
    
    if( typeA != typeB && ( !(isNumber(typeA) && isNumber(typeB)) )) { //different types & not both numbers
        err_attemptToPerform( env, typeA, op, typeB );
        return false;
    }

    switch( typeA ) {
        // case T_NIL:
        
        case T_INT:
        case T_NUMBER: {
            double x, y;
            _readAsDouble( dataSourceA, indexA, &x ); //from vm.h
            _readAsDouble( dataSourceA, indexB, &y ); //from vm.h

            return x < y;
        }

        case T_STRING: {
            uint lenA = getHeapInt( dataSourceA, indexA + 1 );
            uint lenB = getHeapInt( dataSourceB, indexB + 1 );
            uint limit = lenA < lenB ? lenA : lenB; //min

            for(uint c = 0; c < limit; c++) {
                if( dataSourceA[ 5 + c ] < dataSourceB[ 5 + c ] )
                    return true;
            }
            return lenA < lenB;
        }
            
        case T_TABLE: { //TODO: metatable __eq
            if( dataSourceA != dataSourceB || dataSourceA != env->heap ) { //all tables are on the heap
                string unexpected = "internal err: table not on heap";
                throwErr( unexpected );
                return false;
            }

            if( indexA == indexB ) //equals self
                return true;
            
            string eventName = "__lt";
            href meta = tableGetMetaEvent( env, indexA, eventName );
            if( meta == 0 )
                meta = tableGetMetaEvent( env, indexB, eventName );

            if( dataSourceA[meta] == T_CLOSURE ) { //both dataSource must be heap
                href args[2];
                
                args[0] = indexA;
                args[1] = indexB;

                bool ok = callWithArgs( env, metaA, args, 2 );
                //error set by callWithArgs if not ok
                if(!ok) return false;

                if( env->returnFlag && env->nReturn >= 1) {
                    return isTruthy( env->luaStack[ env->returnStart ] );
                }
                return false; //no return value
            } 
            //else fall through to error
        }
        case T_BOOL:
        case T_USERDATA:     //probably not even used
        case T_CLOSURE: 
        case T_ARRAY:
        case T_HASHMAP:
        case T_NATIVE_FUNC:
        case T_FUNC:
        default:
            //attempt to compare boolean with typeB
            err_attemptToPerform( env, typeA, op, typeB );
            return false;
    }
}

bool compareLessThanOrEqual( struct WorkerEnv* env, uchar* dataSourceA, uint indexA, uchar* dataSourceB, uint indexB ) {
    string op = "<=" ;

    if( indexA == indexB )
        return false;
    
    uchar typeA = dataSourceA[indexA];
    uchar typeB = dataSourceB[indexB];
    
    if( typeA != typeB && ( !(isNumber(typeA) && isNumber(typeB)) )) { //different types & not both numbers
        err_attemptToPerform( env, typeA, op, typeB );
        return false;
    }

    switch( typeA ) {
        // case T_NIL:
        
        case T_INT:
        case T_NUMBER: {
            double x, y;
            _readAsDouble( dataSourceA, indexA, &x ); //from vm.h
            _readAsDouble( dataSourceA, indexB, &y ); //from vm.h

            return x <= y;
        }

        case T_STRING: {
            uint lenA = getHeapInt( dataSourceA, indexA + 1 );
            uint lenB = getHeapInt( dataSourceB, indexB + 1 );
            if( lenA > lenB ) return false;
            
            uint limit = lenA < lenB ? lenA : lenB; //min

            for(uint c = 0; c < limit; c++) {
                if( dataSourceA[ 5 + c ] > dataSourceB[ 5 + c ] )
                    return false;
            }

            return lenA <= lenB;
        }
            
        case T_TABLE: { //TODO: metatable __eq
            if( dataSourceA != dataSourceB || dataSourceA != env->heap ) { //all tables are on the heap
                string unexpected = "internal err: table not on heap";
                throwErr( unexpected );
                return false;
            }

            if( indexA == indexB ) //equals self
                return true;
            
            string eventName = "__le";
            href meta = tableGetMetaEvent( env, indexA, eventName );
            if( meta == 0 )
                meta = tableGetMetaEvent( env, indexB, eventName );

            if( dataSourceA[meta] == T_CLOSURE ) { //both dataSource must be heap
                href args[2];
                
                args[0] = indexA;
                args[1] = indexB;

                bool ok = callWithArgs( env, metaA, args, 2 );
                //error set by callWithArgs if not ok
                if(!ok) return false;

                if( env->returnFlag && env->nReturn >= 1) {
                    return isTruthy( env->luaStack[ env->returnStart ] );
                }
                return false; //no return value
            } 
            //else fall through to error
        }
        case T_BOOL:
        case T_USERDATA:     //probably not even used
        case T_CLOSURE: 
        case T_ARRAY:
        case T_HASHMAP:
        case T_NATIVE_FUNC:
        case T_FUNC:
        default:
            //attempt to compare boolean with typeB
            err_attemptToPerform( env, typeA, op, typeB );
            return false;
    }
}

#endif