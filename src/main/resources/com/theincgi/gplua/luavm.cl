
typedef enum {
    /*----------------------------------------------------------------------
    name            args    description
    ------------------------------------------------------------------------*/
    OP_MOVE,/*      A B     R(A) := R(B)                                    */
    OP_LOADK,/*     A Bx    R(A) := Kst(Bx)                                 */
    OP_LOADKX,/*    A       R(A) := Kst(extra arg)                          */
    OP_LOADBOOL,/*  A B C   R(A) := (Bool)B; if (C) pc++                    */
    OP_LOADNIL,/*   A B     R(A), R(A+1), ..., R(A+B) := nil                */
    OP_GETUPVAL,/*  A B     R(A) := UpValue[B]                              */

    OP_GETTABUP,/*  A B C   R(A) := UpValue[B][RK(C)]                       */
    OP_GETTABLE,/*  A B C   R(A) := R(B)[RK(C)]                             */

    OP_SETTABUP,/*  A B C   UpValue[A][RK(B)] := RK(C)                      */
    OP_SETUPVAL,/*  A B     UpValue[B] := R(A)                              */
    OP_SETTABLE,/*  A B C   R(A)[RK(B)] := RK(C)                            */

    OP_NEWTABLE,/*  A B C   R(A) := {} (size = B,C)                         */

    OP_SELF,/*      A B C   R(A+1) := R(B); R(A) := R(B)[RK(C)]             */

    OP_ADD,/*       A B C   R(A) := RK(B) + RK(C)                           */
    OP_SUB,/*       A B C   R(A) := RK(B) - RK(C)                           */
    OP_MUL,/*       A B C   R(A) := RK(B) * RK(C)                           */
    OP_DIV,/*       A B C   R(A) := RK(B) / RK(C)                           */
    OP_MOD,/*       A B C   R(A) := RK(B) % RK(C)                           */
    OP_POW,/*       A B C   R(A) := RK(B) ^ RK(C)                           */
    OP_UNM,/*       A B     R(A) := -R(B)                                   */
    OP_NOT,/*       A B     R(A) := not R(B)                                */
    OP_LEN,/*       A B     R(A) := length of R(B)                          */

    OP_CONCAT,/*    A B C   R(A) := R(B).. ... ..R(C)                       */

    OP_JMP,/*       A sBx   pc+=sBx; if (A) close all upvalues >= R(A - 1)  */
    OP_EQ,/*        A B C   if ((RK(B) == RK(C)) ~= A) then pc++            */
    OP_LT,/*        A B C   if ((RK(B) <  RK(C)) ~= A) then pc++            */
    OP_LE,/*        A B C   if ((RK(B) <= RK(C)) ~= A) then pc++            */

    OP_TEST,/*      A C     if not (R(A) <=> C) then pc++                   */
    OP_TESTSET,/*   A B C   if (R(B) <=> C) then R(A) := R(B) else pc++     */

    OP_CALL,/*      A B C   R(A), ... ,R(A+C-2) := R(A)(R(A+1), ... ,R(A+B-1)) */
    OP_TAILCALL,/*  A B C   return R(A)(R(A+1), ... ,R(A+B-1))              */
    OP_RETURN,/*    A B     return R(A), ... ,R(A+B-2)      (see note)      */

    OP_FORLOOP,/*   A sBx   R(A)+=R(A+2);
                            if R(A) <?= R(A+1) then { pc+=sBx; R(A+3)=R(A) }*/
    OP_FORPREP,/*   A sBx   R(A)-=R(A+2); pc+=sBx                           */

    OP_TFORCALL,/*  A C     R(A+3), ... ,R(A+2+C) := R(A)(R(A+1), R(A+2));  */
    OP_TFORLOOP,/*  A sBx   if R(A+1) ~= nil then { R(A)=R(A+1); pc += sBx }*/

    OP_SETLIST,/*   A B C   R(A)[(C-1)*FPF+i] := R(A+i), 1 <= i <= B        */

    OP_CLOSURE,/*   A Bx    R(A) := closure(KPROTO[Bx])                     */

    OP_VARARG,/*    A B     R(A), R(A+1), ..., R(A+B-2) = vararg            */

    OP_EXTRAARG/*   Ax      extra (larger) argument for previous opcode     */
} OpCode;

#define NUM_OPCODES     (cast(int, OP_EXTRAARG) + 1)

typedef unsigned int LuaInstructionRaw;

// Functions to extract opcode and arguments
OpCode getOpcode(LuaInstructionRaw raw) {
    return (raw >> 26) & 0x3F;
}

unsigned int getA(LuaInstructionRaw raw) {
    return (raw >> 18) & 0xFF;
}

unsigned int getB(LuaInstructionRaw raw) {
    return (raw >> 9) & 0x1FF;
}

unsigned int getC(LuaInstructionRaw raw) {
    return raw & 0x1FF;
}

int getsBx(LuaInstructionRaw raw) {
    return raw & 0x3FFFFFF;
}

/////////////////////////////////////////////////////////////////////
// Lua Stack Utils

//min stack size ~ 5
void initStack( uint* stack, uint funcHeapIndex, uint funcHeapClosure, uint nVarargs ) {
    stack[0] = 1; //base of top frame, always available
    stack[1] = 5 + nVarargs; //first empty, value might not be 0 if reused, but will be overwritten before use
    stack[2] = 5; //varargs are bellow "base" as it's used in a regular lua stack, they use it to point to the first register in a frame. with no varargs top will be here too
    stack[3] = funcHeapIndex;
    stack[4] = funcHeapClosure;
}

/** stack - should be to base of worker stack
  * stackSize - maxium size that won't cause overflow into the next worker / out of bounds
  */
bool pushStackFrame( uint* stack, uint stackSize, uint pc, uint funcHeapIndex, uint funcHeapClosure, int nVarargs ) {
    uint oldBase = stack[0];
    uint oldTop  = stack[oldBase];

    uint base = oldTop + 2; //first empty of old frame, +1 to store old base of frame and old PC
    uint top = oldBase + 4; //first empty of new frame after values set
    
    if(top > stackSize)
        return false; //not enough space!

    stack[0] = base;
//  stack[oldBase] which contains the old frame's `top` value isn't updated so when it's pop'd it doesn't need to be either
    stack[base - 2] = pc;             //part of the previous frame, old 'program counter'
    stack[base - 1] = oldBase;        //part of the previous frame, if no previous frame then stack[0]
    stack[base    ] = top + nVarargs;            //first value in a frame points to the first empty index on the stack
    stack[base + 1] = top;
    stack[base + 2] = funcHeapIndex;
    stack[base + 3] = funcHeapClosure;
    //   [base + 4] empty
    return true; //not out of memory
}

uint getPreviousPC( uint* stack ) {
    uint currentBase = stack[0];
    return stack[ currentBase - 2 ];
}

void popStackFrame( uint* stack ) {
    uint currentBase = stack[0];
    uint oldBase = stack[currentBase - 1];
    stack[0] = oldBase;
    //everything previously on the stack's old top frame can be safely ignored
}

bool pushStack( uint* stack, uint stackSize, uint value) {
    uint currentBase = stack[0];
    uint top = stack[ currentBase ];

    if(top+1 > stackSize)
        return false; //not enough space!

    stack[ currentBase ] = value;
    stack[ currentBase ]++;
    return true; //not out of memory
}

//index arg starting at 0
void setVararg( uint* stack, uchar arg, uint heapIndex ) {
    uint currentBase = stack[0];
    uint argPos = currentBase + 4 + arg;
    stack[ argPos ] = heapIndex;
}

//auto grows if needed, regNum indexes start at 0
bool setRegister( uint* stack, uint stackSize, uchar regNum, uint heapIndex ) {
    uint currentBase = stack[0];
    uint top = stack[ currentBase ];
    uint startOfRegisters = stack[ currentBase + 1 ];
    uint regPos = startOfRegisters + regNum;
    if( regPos >= top ) { //top is the first unused, this indicates that this is a new register
        for(uchar i = 0; i < (regPos - top); i++)
            if(!pushStack( stack, stackSize, 0)) //push nil to fill gap
                return false; //ran out of space filling gap!
        return pushStack( stack, stackSize, heapIndex);
    } else {
        stack[ regPos ] = heapIndex; //register already exists
    }
    return true;
}

uint getRegisterPos( uint* stack, uchar regNum ) {
    uint currentBase = stack[0];
    uint startOfRegisters = stack[ currentBase + 1 ];
    return startOfRegisters + regNum;
}

uint getVarargPos( uint* stack, uchar vargn ) {
    uint currentBase = stack[0];
    return currentBase + 4 + vargn;
}

//////////////////////////////////////////////////////////////////////
// global void* malloc(size_t size, global uchar *heap, global uint *next)
// {
//   uint index = atomic_add(next, size);
//   return heap+index;
// }

// *******************************************************************
// **** byte code helpers ********************************************
// *******************************************************************

// struct LuaFunc {
//     unsigned int lineDefined;
//     unsigned int lastLineDefined;
//     uchar numParams;
//     bool isVararg;
//     uchar maxStackSize;
//     unsigned int codeLen;

// }
// uchar

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