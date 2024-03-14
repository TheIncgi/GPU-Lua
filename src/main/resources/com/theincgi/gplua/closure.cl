#include"closure.h"
#include"common.cl"
#include"types.cl"
#include"heapUtils.h"


href createClosure(uchar* heap, uint maxHeapSize, uint* stack, href envTable) {
    href closure = allocateHeap( heap, maxHeapSize, 9 );
    if( closure == 0 ) return 0;

    numUpvals = 0; //TODO count upvals needed, allocate, copy refs
    href upvalArray = allocateArray( heap, maxHeapSize, numUpvals );

    heap[ closure ] = T_CLOSURE;

    putHeapInt( heap, closure + 1, upvalArray );
    putHeapInt( heap, closure + 5, envTable );
}