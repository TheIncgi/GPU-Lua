#include"stackUtils.h"
/////////////////////////////////////////////////////////////////////
// Lua Stack Utils

//min stack size ~ 5
void initStack( uint* stack, uint funcIndex, href funcHeapClosure, uint nVarargs ) {
    stack[0] = 1; //base of top frame, always available
    stack[1] = 1 + STACK_RESERVE + nVarargs; //first empty, value might not be 0 if reused, but will be overwritten before use
    stack[2] = 1 + STACK_RESERVE + nVarargs; //varargs are bellow "base" as it's used in a regular lua stack, they use it to point to the first register in a frame. top will be here too until registers are pushed
                             //this value points to the last non-inclusive slot used for varargs, which is also the first fixed arg
    stack[3] = funcIndex;   //same as in closure, slightly quicker access
    stack[4] = funcHeapClosure;
}

/** stack - should be to base of worker stack
  * stackSize - maxium size that won't cause overflow into the next worker / out of bounds
  */
bool pushStackFrame( uint* stack, uint stackSize, uint pc, href funcHeapIndex, href funcHeapClosure, int nVarargs ) {
    sref oldBase = stack[0];
    sref oldTop  = stack[oldBase];

    sref base = oldTop + 2; //first empty of old frame, +1 to store old base of frame and old PC
    sref top = base + STACK_RESERVE; //first empty of new frame after values set
    
    if(top > stackSize)
        return false; //not enough space!

    stack[0] = base;
//  stack[oldBase] which contains the old frame's `top` value isn't updated so when it's pop'd it doesn't need to be either
    stack[base - 2] = pc;             //part of the previous frame, old 'program counter'
    stack[base - 1] = oldBase;        //part of the previous frame, if no previous frame then stack[0]
    stack[base    ] = top + nVarargs;            //first value in a frame points to the first empty index on the stack
    stack[base + 1] = top + nVarargs;
    stack[base + 2] = funcHeapIndex;
    stack[base + 3] = funcHeapClosure;
    //   [base + 4] empty
    return true; //not out of memory
}

uint getPreviousPC( uint* stack ) {
    sref currentBase = stack[0];
    return stack[ currentBase - 2 ];
}

void popStackFrame( uint* stack ) {
    sref currentBase = stack[0];
    sref oldBase = stack[currentBase - 1];
    stack[0] = oldBase;
    //everything previously on the stack's old top frame can be safely ignored
}

bool pushStack( uint* stack, uint stackSize, href value) {
    sref currentBase = stack[0];
    sref top = stack[ currentBase ];

    if(top+1 > stackSize)
        return false; //not enough space!

    stack[ top ] = value;
    stack[ currentBase ]++; //top++
    return true; //not out of memory
}

//index arg starting at 0
void setVararg( uint* stack, uchar arg, href heapIndex ) {
    sref currentBase = stack[0];
    sref argPos = currentBase + STACK_RESERVE + arg;
    stack[ argPos ] = heapIndex;
}

//auto grows if needed, regNum indexes start at 0
bool setRegister( uint* stack, uint stackSize, uchar regNum, href heapIndex ) {
    sref currentBase = stack[0];
    sref top = stack[ currentBase ];
    sref startOfRegisters = stack[ currentBase + 1 ];
    sref regPos = startOfRegisters + regNum;
    if( regPos >= top ) { //top is the first unused, this indicates that this is a new register
        while( regPos > stack[ currentBase ] )
            if(!pushStack( stack, stackSize, 0)) //push nil to fill gap
                return false; //ran out of space filling gap!
        return pushStack( stack, stackSize, heapIndex);
    } else {
        stack[ regPos ] = heapIndex; //register already exists
    }
    return true;
}

sref getRegisterPos( uint* stack, uchar regNum ) {
    sref currentBase = stack[0];
    sref startOfRegisters = stack[ currentBase + 1 ];
    return startOfRegisters + regNum;
}

sref getVarargPos( uint* stack, uchar vargn ) {
    sref currentBase = stack[0];
    return currentBase + STACK_RESERVE + vargn;
}

href getStackClosure( uint* stack ) {
    sref base = stack[0];
    return stack[ base + 3 ];
}

href getRegister( uint* stack, uchar regNum ) {
    return stack[ getRegisterPos( stack, regNum ) ];
}

href getVararg( uint* stack, uchar vargn ) {
    return stack[ getVarargPos( stack, vargn ) ];
}

int getNVarargs( uint* stack ) {
    return getRegisterPos( stack, 0 ) - getVarargPos( stack, 0 );
}