#ifndef HEAP_UTILS_CL
#define HEAP_UTILS_CL
#include"types.cl"
//See Algorithms: https://gee.cs.oswego.edu/dl/html/malloc.html
//This implementation uses Boundray Tags
//Heap[0] is not used, the value is always 0 which is also the NIL type
//
//Mark and Sweep is used for garbage collection: https://www.geeksforgeeks.org/mark-and-sweep-garbage-collection-algorithm/
//max chunk size is 1GB when using 30bits of space, likely plenty for normal use
//
//Memory:
//  0 | NIL
//  1 | [used:1][mark:!][Chunk size:30]
//  2 | <heap value>
//  N | [used:1][mark:!][Chunk size:30]
// N+1| <heap value>
// ...
//
//chunk size includes it self
//adding [current index] + [chunk size] will give you the index of the next boundry tag

//                  AABBCCDD
#define  USE_FLAG 0x80000000
#define MARK_FLAG 0x40000000
#define SIZE_MASK 0x3FFFFFFF
#define HEAP_RESERVE 5

int getHeapInt(uchar* heap, uint index) {
    return 
        heap[index    ] << 24 |
        heap[index + 1] << 16 |
        heap[index + 2] <<  8 |
        heap[index + 3];
}

void putHeapInt(uchar* heap, uint index, uint value) {
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
uint allocateHeap(uchar* heap, uint maxHeap, uint size) {
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

//size is number of uints
uint allocateArray(uchar* heap, uint maxHeap, uint size) {
    uint byteSize = 9 + size * 4;
    uint array = allocateHeap( heap, maxHeap, byteSize );
    
    //allocation check
    if(array == 0)
        return 0;
    
    heap[array] = T_ARRAY;
    putHeapInt( heap, array + 1,    0 );   //current length
    putHeapInt( heap, array + 5, size );   //capacity
    for( int i = array + 9; i < array + byteSize; i++ ) {
        heap[i] = 0;
    }
    return array;
}

//allocated space NOT including the boundry tag
uint heapObjectLength(uchar* heap, uint index) {
    return getHeapInt( heap, index - 4 )-4;
}

//index refers to the point given by allocateHeap
//the chunk boundry tag will be 4 bytes before that
//max heap used to auto connect unused regions
void freeHeap(uchar* heap, uint maxHeap, uint index, bool mergeMarked) {
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

void _markHeap( uchar* heap, uint maxHeap, uint index);

void _setMarkTag(uchar* heap, uint index, bool marked) {
    if( marked )
        putHeapInt( heap, index, getHeapInt(heap, index) | MARK_FLAG );
    else
        putHeapInt( heap, index, getHeapInt(heap, index) & (SIZE_MASK | USE_FLAG) ); //unmark
}

void _markHeapArray(uchar* heap, uint maxHeap, uint index) {
    uint capacity = getHeapInt(heap, index + 5);
    uint arrayStart = index + 9; //used, capacity skipped
    for(uint i = 0; i < capacity; i++) {
        _markHeap(heap, maxHeap, getHeapInt(heap, arrayStart + i * 4));
    }
}
void _markHeapHashmap(uchar* heap, uint maxHeap, uint index) {
   uint keysPart = getHeapInt( heap, index + 1 );
   uint valsPart = getHeapInt( heap, index + 5);
   _markHeap(heap, maxHeap, keysPart);
   _markHeap(heap, maxHeap, valsPart);
}
void _markHeapClosure(uchar* heap, uint maxHeap, uint index) {
    uint upvalArray = getHeapInt(heap, index + 1);
    uint envTable = getHeapInt(heap, index + 5);
    _markHeap(heap, maxHeap, upvalArray);
    _markHeap(heap, maxHeap, envTable);
}
void _markHeapSubstring(uchar* heap, uint maxHeap, uint index) {
    uint stringRef = getHeapInt( heap, index + 1 );
    //+5 start, +9 len
    _markHeap( heap, maxHeap, stringRef ); //mark parent string
}
void _markHeapTable(uchar* heap, uint maxHeap, uint index) {
    uint arrayPart = getHeapInt(heap, index + 1);
    uint hashedPart = getHeapInt(heap, index + 5);
    uint metatable = getHeapInt(heap, index + 9);
    _markHeap(heap, maxHeap, arrayPart);
    _markHeap(heap, maxHeap, hashedPart);
    _markHeap(heap, maxHeap, metatable);
}

//index points to the object, not the tag
void _markHeap( uchar* heap, uint maxHeap, uint index) {
    if(index == 0)
        return;
    
    uint tagPos = index - 4;
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

void markHeap( uint* luaStack, uchar* heap, uint maxHeap, uint globalsIndex ) {
    uint frameBase = luaStack[0];
    uint frameTop = luaStack[frameBase];

    while(true) {
        for(uint r = frameBase + 2; r < frameTop; r++) {
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
    ulong index = HEAP_RESERVE;
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

#endif