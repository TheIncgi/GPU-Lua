// #ifndef STACK_UTILS_H
// #define STACK_UTILS_H

// #include"common.cl"

// #define STACK_RESERVE 4

// void initStack( uint* stack, uint funcHeapIndex, href funcHeapClosure, uint nVarargs );
// bool pushStackFrame( uint* stack, uint stackSize, uint pc, href funcHeapIndex, href funcHeapClosure, int nVarargs );
// bool redefineFrame( uint* stack, uint stackSize, uint funcIndex, href funcHeapClosure, int nVarargs );
// uint getPreviousPC( uint* stack );
// uint getCurrentFunctionFromStack( uint* stack );
// bool popStackFrame( uint* stack );
// bool pushStack( uint* stack, uint stackSize, href value);
// void setVararg( uint* stack, uchar arg, href heapIndex );
// bool setRegister( uint* stack, uint stackSize, uchar regNum, href heapIndex );
// sref getRegisterPos( uint* stack, uchar regNum );
// sref getVarargPos( uint* stack, uchar vargn );
// href getStackClosure( uint* stack );

// href getRegister( uint* stack, uchar regNum );
// href getVararg( uint* stack, uchar vargn );
// uint getNVarargs( uint* stack );
// uint getNRegisters( uint* stack );
// #endif