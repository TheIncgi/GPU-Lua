#include"heapUtils.h"
#include"common.cl"
#include"types.cl"

int getHeapInt(uchar* heap, href index) {
    return 
        heap[index    ] << 24 |
        heap[index + 1] << 16 |
        heap[index + 2] <<  8 |
        heap[index + 3];
}

void putHeapInt(uchar* heap, href index, uint value) {
    heap[index    ] = value >> 24 & 0xFF; //bit shift is higher priority than bitwise AND in c++, I checked
    heap[index + 1] = value >> 16 & 0xFF;
    heap[index + 2] = value >>  8 & 0xFF;
    heap[index + 3] = value       & 0xFF;
}

void initHeap(uchar* heap, uint maxHeap) {
    uint remainingHeap = maxHeap;
    for(uint i = HEAP_RESERVE; i < maxHeap; i += SIZE_MASK) {
        uint chunkSize = SIZE_MASK > remainingHeap ? SIZE_MASK : remainingHeap; //min(SIZE_MASK, remainingHeap) didn't want to use fmin
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
    if(size > SIZE_MASK)
        return 0;

    uint index = HEAP_RESERVE;
    while(index < (maxHeap-size-8)) { //not near end of heap, needs space for the tag before and after user data
        uint tag = heap[index];

        uint chunkSize = tag & SIZE_MASK;
        if(chunkSize >= size &&         //size check
            ((tag & USE_FLAG ) == 0)) { //not used check
            heap[index] = size | USE_FLAG; //mark flag is 0 on a new chunk
            heap[index + size] = chunkSize - size - 4; //remaining chunk is not in use
            return index + 1; //point to the actual space that can be used
        } else {
            index += chunkSize;
        }
    }  
    return 0; //not enough memory
}

//allocated space NOT including the boundry tag
uint heapObjectLength(uchar* heap, href index) {
    return getHeapInt( heap, index - 4 )-4;
}

// more free memory after object
// only changes allocation, not something like resizing hashmap
bool heapCanGrowObject( uchar* heap, href index ) {
    href thisTagPos = index - 4;
    uint thisTag = getHeapInt( heap, thisTagPos );
    href nextTagPos = thisTagPos + thisTag;
    uint nextTag = getHeapInt( heap, nextTagPos );
    //TODO
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
uint _hashCode(uchar* bytes, int offset, int length) {
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
    heapPutInt( &buf, value );
    return _hashCode( &buf, 0, 5);
}

uint heapHash(uchar* heap, href obj) {
    return _hashCode( heap, obj, heapObjectLength(heap, obj)); 
}

//index refers to the point given by allocateHeap
//the chunk boundry tag will be 4 bytes before that
//max heap used to auto connect unused regions
void freeHeap(uchar* heap, uint maxHeap, href index, bool mergeMarked) {
    uint tag = getHeapInt( heap, index );
    uint chunkSize = SIZE_MASK & tag;

    uint i = index + chunkSize;
    while( i < maxHeap ) {
        uint nextTag = getHeapInt(heap, i);
        if(nextTag & USE_FLAG > 0) //next in use
            if(!mergeMarked || (mergeMarked && (nextTag & MARK_FLAG) == 0) ) //not merging marked or are merging, but not marked
                break; //no merge on this tag
        
        uint nextSize = nextTag & SIZE_MASK + 4; //+4 from the tag that would be removed
        if( chunkSize + nextSize <= chunkSize )  //overflow check
            break; //overflow
        
        if( chunkSize + nextSize > SIZE_MASK )
            break; //too large for chunk

        chunkSize += nextSize;

        if( i + nextSize -4 <= i ) //another overflow check
            break;

        i += nextSize - 4;
    }
    putHeapInt( heap, index, chunkSize );
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

//index points to the object, not the tag
void _markHeap( uchar* heap, uint maxHeap, href index) {
    if(index == 0)
        return;
    
    href tagPos = index - 4;
    uint tag = getHeapInt(heap, tagPos);
    if(tag & MARK_FLAG > 0)
        return; //already marked

    uchar type = heap[index];
    switch( type ) {
        case T_INT:
        case T_NIL: //this shouldn't happen since it should refer to heap[0], but just incase
        case T_BOOL: //this shouldn't happen either, heap[1] and heap[3] should be the only booleans
        case T_NUMBER:
        case T_STRING:
        case T_USERDATA: //is there even any?
        case T_NATIVE_FUNC:
        case T_FUNC:
        default:
            _setMarkTag(heap, tagPos, true); //marked
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

    }while( index <= maxHeap );
}