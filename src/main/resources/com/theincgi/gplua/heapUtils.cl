#include"heapUtils.h"
#include"vm.h"
#include"common.cl"
#include"types.cl"

//#define DEBUG_ALLOCATION
//#define DEBUG_ALLOCATION_START someNumber

int getHeapInt(const uchar* heap, const href index) {
    return 
        (heap[index    ] << 24) |
        (heap[index + 1] << 16) |
        (heap[index + 2] <<  8) |
        (heap[index + 3]      );
}

void putHeapInt(uchar* heap, const href index, const uint value) {
    heap[index    ] = (value >> 24) & 0xFF; //bit shift is higher priority than bitwise AND in c++, I checked
    heap[index + 1] = (value >> 16) & 0xFF;
    heap[index + 2] = (value >>  8) & 0xFF;
    heap[index + 3] = (value      ) & 0xFF;
}

void initHeap(uchar* heap, uint maxHeap) {
    if(maxHeap < 5) return;
    heap[1] = T_BOOL;
    heap[3] = T_BOOL;
    heap[4] = 1;
    uint remainingHeap = maxHeap - HEAP_RESERVE;
    for(uint i = HEAP_RESERVE; i < maxHeap; i += SIZE_MASK) {
        uint chunkSize = SIZE_MASK < remainingHeap ? SIZE_MASK : remainingHeap; //min(SIZE_MASK, remainingHeap) didn't want to use fmin
        putHeapInt(heap, i, chunkSize);
        remainingHeap -= chunkSize;
    }
}

//max size will be 0x3F_FF_FF_FF (0011_1111_1....)
//left most bit will be used as a `in use` flag
//the second left most bit will be the `mark` flag for gc
//allocation index of 0 indicates failure
//returns index of first byte in the new chunk on success
href allocateHeap(uchar* heap, uint maxHeap, uint size) {
    //debug, records allocations
    #ifdef DEBUG_ALLOCATION
        uint debugStart = DEBUG_ALLOCATION_START;
        uint debugPos; {
            uint debugTag = getHeapInt(heap, debugStart);
            putHeapInt(heap, debugStart, debugTag == 0 ? (21 | USE_FLAG) : (debugTag + 8));
            heap[debugStart+4] = T_ARRAY;
            debugPos = getHeapInt(heap, debugStart + 5);
            putHeapInt(heap, debugStart + 5, 2 + debugPos);
            putHeapInt(heap, debugStart + 9, 2 + debugPos);
        }
    #endif

    uint sizeWithTag = size+4;
    uint index = HEAP_RESERVE;
    long limit = (maxHeap-(long)sizeWithTag-4);
    while(index < limit) { //not near end of heap, needs space for the tag before and after user data
        uint tag = getHeapInt(heap, index);
        uint chunkSize = tag & SIZE_MASK;
        if( (tag & USE_FLAG) != 0 ) {
            index += chunkSize;
            continue;
        }

        href nextTagPos = index + chunkSize;
        uint nextTag;
        while( nextTagPos < limit ) {
            nextTag = getHeapInt(heap, nextTagPos);
            uint tagSize = nextTag & SIZE_MASK;
            nextTagPos += tagSize;
            
            if( ((nextTag & USE_FLAG) == 0) && ((tagSize + (long)chunkSize) <= SIZE_MASK) ) {
                chunkSize += tagSize;
            } else {
                break;
            }
        };

        bool sizeOK = (chunkSize - 4 >= sizeWithTag) //tag safety margin, partial overlap will destroy the next tag
                      || (chunkSize == sizeWithTag); //exact match, awesome
        if(sizeOK) {
             //use flag only, mark flag is 0 on a new chunk
            #ifdef DEBUG_ALLOCATION
                uint debugStart = DEBUG_ALLOCATION_START;
                putHeapInt(heap, debugStart + 13 + debugPos * 4, index); //DEBUG
                putHeapInt(heap, debugStart + 13 + debugPos * 4 + 4, sizeWithTag); //DEBUG
            #endif
            putHeapInt(heap, index, sizeWithTag | USE_FLAG);

            if(chunkSize != sizeWithTag) //don't edit next tag for exact fit
                putHeapInt(heap, index+sizeWithTag, chunkSize - size - 4); //remaining chunk is not in use


            return index + 4; //point to the actual space that can be used
        } else {
            index = nextTagPos;
        }
    }  
    return 0; //not enough memory
}

href allocateNumber( uchar* heap, uint maxHeap, double value ) {
    if( value == (int)value )
        return allocateInt( heap, maxHeap, (int) value);

    href hpos = allocateHeap( heap, maxHeap, 9 );
    if( hpos == 0 ) return 0;

    union doubleUnion du;
    du.dbits = value;
    heap[hpos    ] = T_NUMBER;
    heap[hpos + 1] = (du.lbits >> 56) & 0xFF;
    heap[hpos + 2] = (du.lbits >> 48) & 0xFF;
    heap[hpos + 3] = (du.lbits >> 40) & 0xFF;
    heap[hpos + 4] = (du.lbits >> 32) & 0xFF;
    heap[hpos + 5] = (du.lbits >> 24) & 0xFF;
    heap[hpos + 6] = (du.lbits >> 16) & 0xFF;
    heap[hpos + 7] = (du.lbits >>  8) & 0xFF;
    heap[hpos + 8] = (du.lbits      ) & 0xFF;

    return hpos;
}

href allocateInt( uchar* heap, uint maxHeap, int value ) {
    href hpos = allocateHeap( heap, maxHeap, 5 );
    if( hpos == 0 ) return 0;

    heap[ hpos ] = T_INT;
    putHeapInt( heap, hpos + 1, value );
    return hpos;
}

//allocated space NOT including the boundry tag
uint heapObjectLength(const uchar* heap, const href index) {
    return (getHeapInt( heap, index - 4 ) & SIZE_MASK) - 4;
}

// amount of free memory after object that can be used to expand
// only for changes to allocation, not something like resizing hashmap
uint heapObjectGrowthLimit( uchar* heap, uint maxHeapSize, href index ) {
    href thisTagPos = index - 4;
    uint thisTag = getHeapInt( heap, thisTagPos );
    href nextTagPos = thisTagPos + thisTag;
    uint nextTag = getHeapInt( heap, nextTagPos );
    
    if((nextTag & USE_FLAG) > 0) 
        return 0;

    uint nextSize = nextTag & SIZE_MASK;
    //TODO determine if next tag is end of heap, and include logic when expanding
    //so there aren't any empty chunks (4)

    return 0; //dummy value
}

/** Compute the hash code of a sequence of bytes within a byte array using
    * lua's rules for string hashes.  For long strings, not all bytes are hashed.
    * @param bytes  byte array containing the bytes.
    * @param offset  offset into the hash for the first byte.
    * @param length number of bytes starting with offset that are part of the string.
    * @return hash for the string defined by bytes, offset, and length.
    * <br>
    * Sourced from LuaJ
    */
uint _hashCode(const uchar* bytes, const int offset, const int length) {
    int h = length;  /* seed */
    int step = (length>>5)+1;  /* if string is too long, don't hash all its chars */
    for (int l1=length; l1>=step; l1-=step)  /* compute hash */
        h = h ^ ((h<<5)+(h>>2)+(((int) bytes[offset+l1-1] ) & 0x0FF ));
    return h;
}

//return the hash code for an int object without needing it on the heap
uint hashInt( int value ) {
    uchar buf[5];
    buf[0] = T_INT;
    putHeapInt( buf, 1, value );
    return _hashCode( buf, 0, 5);
}

uint hashString( string str, uint len ) {
    uchar buf[5];
    buf[0] = T_STRING;
    uint size = 0;
    putHeapInt( buf, 1, len );
    uint length = len + 6;

    int h = length;  /* seed */
    int step = (length>>5)+1;  /* if string is too long, don't hash all its chars */
    for (int l1=length; l1>=step; l1-=step) {  /* compute hash */
        int byteIndex = l1-1;
        uchar byteVal = ( 0 <= byteIndex && byteIndex < 5 ) ?
            buf[byteIndex] :
            (byteIndex == length-1 ? 0 : str[byteIndex - 5]);
        h = h ^ ((h<<5)+(h>>2)+(((int) byteVal ) & 0x0FF ));
    }
    return h;
}

uint heapHash(uchar* heap, href obj) {
    return _hashCode( heap, obj, heapObjectLength(heap, obj)); 
}

//index refers to the point given by allocateHeap
//the chunk boundry tag will be 4 bytes before that
//max heap used to auto connect unused regions
void freeHeap(uchar* heap, uint maxHeap, href index, bool mergeUnmarked) {
    href tagPos = index - 4;
    uint tag = getHeapInt( heap, tagPos );
    uint chunkSize = SIZE_MASK & tag;

    #ifdef DEBUG_ALLOCATION
        uint debugPos; { //debug record free
            uint debugStart = DEBUG_ALLOCATION_START;
            uint debugTag = getHeapInt(heap, debugStart);
            putHeapInt(heap, debugStart, debugTag == 0 ? (21 | USE_FLAG) : (debugTag + 8));
            heap[debugStart+4] = T_ARRAY;
            debugPos = getHeapInt(heap, debugStart + 5);
            putHeapInt(heap, debugStart + 5, 2 + debugPos);
            putHeapInt(heap, debugStart + 9, 2 + debugPos);

            putHeapInt(heap, debugStart + 13 + debugPos * 4, index - 4); //DEBUG
            putHeapInt(heap, debugStart + 13 + debugPos * 4 + 4, 0); //DEBUG
        }
    #endif

    href i = tagPos + chunkSize;
    while( i < maxHeap ) {
        uint nextTag = getHeapInt(heap, i);
        if((nextTag & USE_FLAG) > 0) //next in use
            if(!mergeUnmarked || (mergeUnmarked && (nextTag & MARK_FLAG) != 0) ) //not merging marked or are merging, but not marked
                break; //no merge on this tag
        
        uint nextSize = nextTag & SIZE_MASK;
        if( chunkSize + nextSize <= chunkSize )  //overflow check
            break; //overflow
        
        if( chunkSize + nextSize > SIZE_MASK )
            break; //too large for chunk

        chunkSize += nextSize;

        if( i + nextSize -4 <= i ) //another overflow check
            break;

        i += nextSize;
    }
    putHeapInt( heap, tagPos, chunkSize );
}

void _setMarkTag(uchar* heap, href index, bool marked) {
    if( marked )
        putHeapInt( heap, index, getHeapInt(heap, index) | MARK_FLAG );
    else
        putHeapInt( heap, index, getHeapInt(heap, index) & (SIZE_MASK | USE_FLAG) ); //unmark
}

void _markHeapArray(uchar* heap, uint maxHeap, href index) {
    uint capacity = getHeapInt(heap, index + 5);
    href arrayStart = index + 9; //used, capacity skipped
    for(uint i = 0; i < capacity; i++) {
        _markHeap(heap, maxHeap, getHeapInt(heap, arrayStart + i * 4));
    }
}
void _markHeapHashmap(uchar* heap, uint maxHeap, href index) {
   href keysPart = getHeapInt( heap, index + 1 );
   href valsPart = getHeapInt( heap, index + 5);
   _markHeap(heap, maxHeap, keysPart);
   _markHeap(heap, maxHeap, valsPart);
}
void _markHeapClosure(uchar* heap, uint maxHeap, href index) {
    href upvalArray = getHeapInt(heap, index + 1);
    href envTable = getHeapInt(heap, index + 5);
    _markHeap(heap, maxHeap, upvalArray);
    _markHeap(heap, maxHeap, envTable);
}
void _markHeapSubstring(uchar* heap, uint maxHeap, href index) {
    href stringRef = getHeapInt( heap, index + 1 );
    //+5 start, +9 len
    _markHeap( heap, maxHeap, stringRef ); //mark parent string
}
void _markHeapTable(uchar* heap, uint maxHeap, href index) {
    href arrayPart = getHeapInt(heap, index + 1);
    href hashedPart = getHeapInt(heap, index + 5);
    href metatable = getHeapInt(heap, index + 9);
    _markHeap(heap, maxHeap, arrayPart);
    _markHeap(heap, maxHeap, hashedPart);
    _markHeap(heap, maxHeap, metatable);
}

void _markNativeFunc(uchar* heap, uint maxHeap, href index) {
    href label = getHeapInt( heap, index + 5 );
    _markHeap(heap, maxHeap, label);
}

//index points to the object, not the tag
void _markHeap( uchar* heap, uint maxHeap, href index) {
    if(index == 0)
        return;
    
    href tagPos = index - 4;
    uint tag = getHeapInt(heap, tagPos);
    if((tag & MARK_FLAG) > 0)
        return; //already marked

    uchar type = heap[index];
    switch( type ) {
        case T_INT:
        case T_NIL: //this shouldn't happen since it should refer to heap[0], but just incase
        case T_BOOL: //this shouldn't happen either, heap[1] and heap[3] should be the only booleans
        case T_NUMBER:
        case T_STRING:
        case T_USERDATA: //is there even any?
        case T_FUNC:
        default:
            _setMarkTag(heap, tagPos, true); //marked
            break;
        case T_NATIVE_FUNC:
            _setMarkTag(heap, tagPos, true); //marked
            _markNativeFunc(heap, maxHeap, index);
            break;
        case T_ARRAY:
            _setMarkTag(heap, tagPos, true); //marked
            _markHeapArray(heap, maxHeap, index);
            break;
        case T_HASHMAP:
            _setMarkTag(heap, tagPos, true); //marked
            _markHeapHashmap(heap, maxHeap, index);
            break;
        case T_CLOSURE:
            _setMarkTag(heap, tagPos, true); //marked
            _markHeapClosure(heap, maxHeap, index);
            break;
        case T_SUBSTRING:
            _setMarkTag(heap, tagPos, true); //marked
            _markHeapSubstring(heap, maxHeap, index);
            break;
        case T_TABLE:
            _setMarkTag(heap, tagPos, true); //marked
            _markHeapTable(heap, maxHeap, index);
            break;
    }
}

void markHeap( uint* luaStack, uchar* heap, uint maxHeap, href globalsIndex ) {
    sref frameBase = luaStack[0];
    sref frameTop = luaStack[frameBase];

    while(true) {
        for(sref r = frameBase + 2; r < frameTop; r++) {
            _markHeap( heap, maxHeap, luaStack[r] );
        }
        if(frameBase == 1)
            break;
        
        frameBase = luaStack[ frameBase - 1 ];
        frameTop = luaStack[ frameBase ];
    }

    _markHeap( heap, maxHeap, globalsIndex );

}

void sweepHeap( uchar* heap, uint maxHeap ) {
    href index = HEAP_RESERVE;
    uint tag = getHeapInt(heap, index);

    do {
        if((tag & SIZE_MASK) == 0 )
            break; //should only happen at the end of the heap

        if( (tag & MARK_FLAG) == 0 ) { //not marked
            freeHeap( heap, maxHeap, (uint)(index + 4), true );
            tag = getHeapInt( heap, (uint)index ); //size may change
        } else {
            _setMarkTag(heap, (uint)index, false); //unmark
        }

        index += (tag & SIZE_MASK);
        tag = getHeapInt(heap, index);
    }while( index < maxHeap-4 );
}