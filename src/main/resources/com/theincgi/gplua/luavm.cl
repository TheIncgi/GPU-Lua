#include"types.cl"
#include"heapUtils.h"
#include"array.h"
#include"common.cl"
#include"table.h"
#include"opUtils.cl"
#include"hashmap.cl"
#include"globals.cl"
// #include"opUtils.cl"
#include"stackUtils.cl"
#include"vm.h"

#include"vm.cl"


__kernel void exec(
    // __global const uint * workSize,
    // __global      uchar* luaState,
    __global       uint* luaStack,
    __global const uint* stackSizes,
    __global       char* errorOutput,
    __global const long* maxExecutionTime,
    __global uchar* heap,
    
    /*Byte code pieces*/
    __global unsigned int* numFunctions,
    __global unsigned int* linesDefined,
    __global unsigned int* lastLinesDefined,
    __global        uchar* numParams,
    __global         bool* isVararg, //could be true or passed number of args & set that way
    __global        uchar* maxStackSize,

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
    __global        uchar* upvals //[function #][ index*2 ] - 2 byte pairs, bool "in stack" & upval index
    
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
    uint stackSize = stackSizes[0];
    uint heapSize  = stackSizes[1];
    uint errorSize = stackSizes[2];

    uchar* localHeap  = &(heap[ heapSize * glid ]);
     uint* localStack = &(luaStack[ stackSize * glid ]);

    href stringTable = newTable( localHeap, heapSize );
    //TODO allow heap retention as a param/flag/setting
    //TODO consider shared globals to reduce memory usage
    href globals = createGlobals( localHeap, heapSize, stringTable );

    // int func = 0,a,b,c,pc=0; //func here refers to code, not a heap ref
    {
        workerEnv.luaStack = localStack;
        workerEnv.stackSize = stackSize;

        workerEnv.heap = localHeap;
        workerEnv.maxHeapSize = heapSize;

        workerEnv.error = errorOutput;
        workerEnv.errorSize = errorSize;

        workerEnv.codeIndexes = codeIndexes;
        workerEnv.code = code;
        workerEnv.numParams = numParams;
        workerEnv.isVararg = isVararg;

        workerEnv.constantsPrimaryIndex = constantsPrimaryIndex;
        workerEnv.constantsSecondaryIndex = constantsSecondaryIndex;
        workerEnv.constantsData = constantsData;

        workerEnv.globals = globals;
        workerEnv.stringTable = stringTable;

        workerEnv.returnFlag = false;
    }
    //stack, funcHref, closureHref, numVarargs
    initStack( localStack, 0, 0, 0 ); //no closure for main maybe? idk, what's even in it?

    while() {
        

        
    }
    //exec logic

    //varargs v = NONE
    

}

// ERASE as they are implemented
// /*----------------------------------------------------------------------
//     name            args    description
//     ------------------------------------------------------------------------*/
//     OP_MOVE,/*      A B     R(A) := R(B)                                    */
//     OP_LOADK,/*     A Bx    R(A) := Kst(Bx)                                 */
//     OP_LOADKX,/*    A       R(A) := Kst(extra arg)                          */
//     OP_LOADBOOL,/*  A B C   R(A) := (Bool)B; if (C) pc++                    */
//     OP_LOADNIL,/*   A B     R(A), R(A+1), ..., R(A+B) := nil                */
//     OP_GETUPVAL,/*  A B     R(A) := UpValue[B]                              */

//     OP_GETTABUP,/*  A B C   R(A) := UpValue[B][RK(C)]                       */
//     OP_GETTABLE,/*  A B C   R(A) := R(B)[RK(C)]                             */

//     OP_SETTABUP,/*  A B C   UpValue[A][RK(B)] := RK(C)                      */
//     OP_SETUPVAL,/*  A B     UpValue[B] := R(A)                              */
//     OP_SETTABLE,/*  A B C   R(A)[RK(B)] := RK(C)                            */

//     OP_NEWTABLE,/*  A B C   R(A) := {} (size = B,C)                         */

//     OP_SELF,/*      A B C   R(A+1) := R(B); R(A) := R(B)[RK(C)]             */

//     OP_ADD,/*       A B C   R(A) := RK(B) + RK(C)                           */
//     OP_SUB,/*       A B C   R(A) := RK(B) - RK(C)                           */
//     OP_MUL,/*       A B C   R(A) := RK(B) * RK(C)                           */
//     OP_DIV,/*       A B C   R(A) := RK(B) / RK(C)                           */
//     OP_MOD,/*       A B C   R(A) := RK(B) % RK(C)                           */
//     OP_POW,/*       A B C   R(A) := RK(B) ^ RK(C)                           */
//     OP_UNM,/*       A B     R(A) := -R(B)                                   */
//     OP_NOT,/*       A B     R(A) := not R(B)                                */
//     OP_LEN,/*       A B     R(A) := length of R(B)                          */

//     OP_CONCAT,/*    A B C   R(A) := R(B).. ... ..R(C)                       */

//     OP_JMP,/*       A sBx   pc+=sBx; if (A) close all upvalues >= R(A - 1)  */
//     OP_EQ,/*        A B C   if ((RK(B) == RK(C)) ~= A) then pc++            */
//     OP_LT,/*        A B C   if ((RK(B) <  RK(C)) ~= A) then pc++            */
//     OP_LE,/*        A B C   if ((RK(B) <= RK(C)) ~= A) then pc++            */

//     OP_TEST,/*      A C     if not (R(A) <=> C) then pc++                   */
//     OP_TESTSET,/*   A B C   if (R(B) <=> C) then R(A) := R(B) else pc++     */

//     OP_CALL,/*      A B C   R(A), ... ,R(A+C-2) := R(A)(R(A+1), ... ,R(A+B-1)) */
//     OP_TAILCALL,/*  A B C   return R(A)(R(A+1), ... ,R(A+B-1))              */
//     OP_RETURN,/*    A B     return R(A), ... ,R(A+B-2)      (see note)      */

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