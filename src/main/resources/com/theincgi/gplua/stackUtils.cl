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