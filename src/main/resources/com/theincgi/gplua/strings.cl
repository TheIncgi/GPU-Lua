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

void intToCharbuf( int value, char* buffer ) {
    uint c = 0;
    if( value < 0 ) {
        buffer[ c++ ] = '-';
        value = -value;
    }
    uint digits = (uint)ceil(log10((double)value));
    for(uint digitPos = digitPos-1; digitPos >= 0; digitPos--) { //left to right
        buffer[ c++ ] = '0' + ( (int)( value / exp10((double)digitPos) ) );
    }
    buffer[ c ] = 0;
}

//lenghts can't be dynamicly allocated, so just need to pass in array with right size
href concatRaw( struct WorkerEnv* env, char** strings, uint nStrings, uint* lengths ) {
    //TODO check for dupes in string table
    uchar* heap = env->heap;
    uint totalLen = 1; //null teminated
    
    for( uint s = 0; s < nStrings; s++ ) {
        lengths[s] = strBufLen( strings[s] );
        totalLen += lengths[s];
    }
    
    href str = allocateHeap( heap, env->maxHeapSize, 5 + totalLen );
    if( str == 0 ) return 0; //failed to allocate

    heap[ str ] = T_STRING;
    putHeapInt( heap, str + 1, totalLen );
    
    uint w = 0;
    for( uint s = 0; s < nStrings; s++ ) {
        for( uint sChar = 0; sChar < lengths[s]; sChar++ ) {
            heap[ w++ ] = (uchar) strings[sChar];
        }
    }

    return str;
}

void copyToBuf( string str, char* buf ) {
    uint len = strLen( str );
    for(uint i = 0; i < len; i++)
        buf[i] = str[i];
    buf[len] = 0;
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