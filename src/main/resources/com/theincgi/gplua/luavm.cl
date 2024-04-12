// headers & cl files without headers
#include"types.cl"
#include"common.cl"
#include"heapUtils.h"
#include"array.h"
#include"table.h"
#include"opUtils.cl"
#include"strings.h"
#include"globals.cl"
// #include"stackUtils.h"
#include"vm.h"
#include"closure.h"
#include"luaStack.h"
#include"comparison.h"
#include"upval.h"


//manually include .cl for headers since openCL doesn't do that
#include"vm.cl"
#include"table.cl"
#include"array.cl"
#include"hashmap.cl"
#include"heapUtils.cl"
#include"strings.cl"
// #include"stackUtils.cl"
#include"closure.cl"
#include"luaStack.cl"
#include"comparison.cl"
#include"upval.cl"
			

__kernel void exec(
    // __global const uint * workSize,
    // __global      uchar* luaState,
    // __global       uint* luaStack,
    __global const uint* heapSize,
    // __global       char* errorOutput,
    __global const long* maxExecutionTime,
    __global uchar* heap,
    
    /*Byte code pieces*/
    __global unsigned int* numFunctions,
    __global unsigned int* linesDefined,
    __global unsigned int* lastLinesDefined,
    __global        uchar* numParams,
    __global         bool* isVararg, //could be true or passed number of args & set that way
    __global        uchar* maxStackSizes,

    //code
    __global          uint* codeIndexes,
    __global          uint* code, //[function #][instruction] = code[ codeIndexes[function] + instruction ]
    
    //constants
    //__global unsigned int* constantsLen,
    __global          int* constantsPrimaryIndex,
    __global          int* constantsSecondaryIndex,
    __global        uchar* constantsData, //[function #][byte] - single byte type, followed by value, strings are null terminated
    __global          int* protoLengths,
    
    //upvals
    __global          int* upvalsIndex,
    __global        uchar* upvals, //[function #][ index*2 ] - 2 byte pairs, bool "in stack" & upval index
    __global          int* returnInfo
    //debug info?
) {

    //task boiler plate
    int dimensions = get_work_dim();
    int glid = get_global_linear_id();
    
    for (int dim = 0; dim < dimensions; dim++) {
        if (get_global_id(dim) > get_global_size(dim)) {
            return; //done, not a real work item
        }
    }

    struct WorkerEnv workerEnv;

    //VM setup
    // uint stackSize = stackSizes[0];

    uchar* localHeap  = &(heap[ heapSize[0] * glid ]);
    //  uint* localStack = &(luaStack[ stackSize * glid ]);
    initHeap( localHeap, heapSize[0] );

    href stringTable = newTable( localHeap, heapSize[0] );
    //TODO allow heap retention as a param/flag/setting
    //TODO consider shared globals to reduce memory usage

    // int func = 0,a,b,c,pc=0; //func here refers to code, not a heap ref
    {
        // workerEnv.luaStack = localStack;
        // workerEnv.stackSize = stackSize;

        workerEnv.heap = localHeap;
        workerEnv.maxHeapSize = heapSize[0];

        workerEnv.maxStackSizes = maxStackSizes;

        // workerEnv.error = errorOutput;
        // workerEnv.errorSize = errorSize;

        workerEnv.codeIndexes = codeIndexes;
        workerEnv.code = code;
        workerEnv.numParams = numParams;
        workerEnv.isVararg = isVararg;

        workerEnv.constantsPrimaryIndex = constantsPrimaryIndex;
        workerEnv.constantsSecondaryIndex = constantsSecondaryIndex;
        workerEnv.constantsData = constantsData;

        workerEnv.upvalsIndex = upvalsIndex;
        workerEnv.upvals = upvals;

        workerEnv.error = 0; // no error

        workerEnv.stringTable = stringTable;
        workerEnv.globals = createGlobals( &workerEnv );

        workerEnv.returnFlag = false;
    }
   
    href mainClosure = createClosure( &workerEnv, 0, workerEnv.globals, 1 ); //function 0, 1 upval(_ENV)
    setClosureUpval( &workerEnv, mainClosure, 0, workerEnv.globals );

    bool ok = call( &workerEnv, mainClosure ); //callWithArgs is also available as an option

    if( ok && workerEnv.returnFlag ) {
        returnInfo[ 0 ] = 0; //no err
        returnInfo[ 1 ] = workerEnv.returnStart;
        returnInfo[ 2 ] = workerEnv.nReturn;
    } else if( workerEnv.error ) {
        returnInfo[ 0 ] = workerEnv.error;
        returnInfo[ 1 ] = 0;
        returnInfo[ 2 ] = 0;
    } else {
        returnInfo[ 0 ] = 0;
        returnInfo[ 1 ] = 0;
        returnInfo[ 2 ] = 0;
    }
}

// ERASE as they are implemented
// /*----------------------------------------------------------------------
//     name            args    description
//     ------------------------------------------------------------------------*/
//     OP_LOADKX,/*    A       R(A) := Kst(extra arg)                          */


//     OP_CONCAT,/*    A B C   R(A) := R(B).. ... ..R(C)                       */

//     OP_JMP,/*       A sBx   pc+=sBx; if (A) close all upvalues >= R(A - 1)  */
//     OP_EQ,/*        A B C   if ((RK(B) == RK(C)) ~= A) then pc++            */
//     OP_LT,/*        A B C   if ((RK(B) <  RK(C)) ~= A) then pc++            */
//     OP_LE,/*        A B C   if ((RK(B) <= RK(C)) ~= A) then pc++            */

//     OP_TEST,/*      A C     if not (R(A) <=> C) then pc++                   */
//     OP_TESTSET,/*   A B C   if (R(B) <=> C) then R(A) := R(B) else pc++     */

//     OP_TAILCALL,/*  A B C   return R(A)(R(A+1), ... ,R(A+B-1))              */

//     OP_FORLOOP,/*   A sBx   R(A)+=R(A+2);
//                             if R(A) <?= R(A+1) then { pc+=sBx; R(A+3)=R(A) }*/
//     OP_FORPREP,/*   A sBx   R(A)-=R(A+2); pc+=sBx                           */

//     OP_TFORCALL,/*  A C     R(A+3), ... ,R(A+2+C) := R(A)(R(A+1), R(A+2));  */
//     OP_TFORLOOP,/*  A sBx   if R(A+1) ~= nil then { R(A)=R(A+1); pc += sBx }*/

//     OP_SETLIST,/*   A B C   R(A)[(C-1)*FPF+i] := R(A+i), 1 <= i <= B        */

//     OP_CLOSURE,/*   A Bx    R(A) := closure(KPROTO[Bx])                     */

//     OP_VARARG,/*    A B     R(A), R(A+1), ..., R(A+B-2) = vararg            */

//     OP_EXTRAARG/*   Ax      extra (larger) argument for previous opcode     */
// } OpCode;