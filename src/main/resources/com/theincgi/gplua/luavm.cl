#include types.cl
#include"heapUtils.cl"
#include"hashmap.cl"
#include"opUtils.cl"
#include"stackUtils.cl"




__kernel void exec(
    // __global const uint * workSize,
    // __global      uchar* luaState,
    __global       uint* luaStack,
    __global const  int* stackSizes,
    __global       char* errorOutput,
    __global const long* maxExecutionTime,
    __global uchar* heap,
    __global  long* heapNext,
    
    /*Byte code pieces*/
    __global unsigned int* numFunctions,
    __global unsigned int* linesDefined,
    __global unsigned int* lastLinesDefined,
    __global        uchar* numParams,
    __global         bool* isVararg,
    __global        uchar* maxStackSize,

    //code
    __global          int* codeIndexes,
    __global unsigned int* code, //[function #][instruction]
    
    //constants
    //__global unsigned int* constantsLen,
    __global          int* constantsPrimaryIndex,
    __global          int* constantsSecondaryIndex,
    __global        uchar* constantsData, //[function #][byte] - single byte type, followed by value, strings are null terminated
    __global          int* protoLengths,
    
    //upvals
    __global          int* upvalsIndex,
    __global        uchar* upvals //[function #][ index*2 ] - 2 byte pairs, bool "in stack" & upval index
    
    //debug info?
) {
    int dimensions = get_work_dim();
    int glid = get_global_linear_id();
    
    for (int dim = 0; dim < dimensions; dim++) {
        if (get_global_id(dim) > get_global_size(dim)) {
            return; //done, not a real work item
        }
    }

    int stackSize = stackSizes[0];
    int heapSize  = stackSizes[1];
    int errorSize = stackSizes[2];

    uchar* localHeap  = &(heap[ heapSize * glid ]);
     uint* localStack = &(luaStack[ stackSize * glid ]);


    // size_t luaStackSize = stackSizes[0];
    // size_t callInfoStackSize = stackSizes[1];

    int func = 0,a,b,c,pc=0;
    initStack( localStack, 0, 0, 0 ); //no closure for main maybe? idk, what's even in it?
    
    //exec logic

    //varargs v = NONE
    

}