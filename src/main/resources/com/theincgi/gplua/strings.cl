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

href concatRaw( struct WorkerEnv* env, string* strings, uint nStrings ) {
    //TODO check for dupes in string table
    uchar* heap = env->heap;
    uint totalLen = 1; //null teminated
    uint lengths[ nStrings ];
    for( uint s = 0; s < nStrings; s++ ) {
        totalLen += lengths[s] = strLen( strings[s] );
    }
    
    href str = allocateHeap( heap, env->maxHeapSize, 5 + totalLen );
    if( str == 0 ) return 0; //failed to allocate

    heap[ str ] = T_STRING;
    putHeapInt( heap, str + 1, totalLen );
    
    uint w = 0;
    for( uint s = 0; s < nStrings; s++ ) {
        for( uint sChar = 0; sChar < lengths[s]; sChar++ ) {
            heap[ w++ ] = strings[sChar];
        }
    }

    return str;
}

//min size 19
void typeName( uint type, char* buffer, uint bufferSize ) {
    string name;
    switch( type ) {
        //lua exposed
        case T_INT:
        case T_NUMBER:
            name = "number"; break;
        case T_NONE:
        case T_NIL:
            name = "nil"; break;
        case T_BOOL:  
            name = "boolean"; break;
        case T_STRING:
        case T_SUBSTRING:
            name = "string"; break;
        case T_TABLE: 
            name = "table"; break;
        case T_CLOSURE: 
        case T_NATIVE_FUNC:  
            name = "function"; break;
        //internal
        case T_FUNC:
            name = "internal-prototype"; break;
        case T_USERDATA:
            name = "userdata"; break;
        case T_ARRAY:
            name = "internal-array"; break;
        case T_HASHMAP:  
            name = "internal-hashmap"; break;
        case T_ERROR:
            name = "error"; break;
        default:
            name = "unknown";
    }
    uint len = strLen( name );
    len = (len < bufferSize - 1) ? len : (bufferSize-1);
    for( uint i = 0; i < len; i++ )
        buffer[i] = name[i];
}