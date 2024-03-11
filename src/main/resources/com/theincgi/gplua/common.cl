#ifndef COMMON_CL
#define COMMON_CL

//heap ref, some might still be uint if I miss them when I started replacing with this
//it should be used to refer to any address/index on our workers heap
//href 0 will be nil for any worker
//heap  will be something like &(globalHeap[ startOfWorkerHeap ])
//the value at heap[href] could be boundry tags, lua data, custom objects, or garbage
//href unit is bytes
typedef uint href;


//reference to a position on the stack
//sref unit is ints (likely holding an href)
//
//if there is a sref S for the first vararg
//and a href for the value
//href value = stack[ S ]
typedef uint sref;

typedef __constant char* string;

uint resizeRule( uint oldSize ) {
    uint times = oldSize * 2;
    uint add   = oldSize + 128;
    return times < add ? times : add; //min
}

uint strLen( string str ) {
    int size = 0;
    while( size >= 0 ) {
        if( str[size] == 0 )
            break;
        size++;
    }
    if(size <= 0)
        return 0;
    return size;
}

#endif