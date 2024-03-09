#ifndef STACK_UTILS_H
#define STACK_UTILS_H

#include"common.cl"

void initStack( uint* stack, href funcHeapIndex, href funcHeapClosure, uint nVarargs );
bool pushStackFrame( uint* stack, uint stackSize, uint pc, href funcHeapIndex, href funcHeapClosure, int nVarargs );
uint getPreviousPC( uint* stack );
void popStackFrame( uint* stack );
bool pushStack( uint* stack, uint stackSize, href value);
void setVararg( uint* stack, uchar arg, href heapIndex );
bool setRegister( uint* stack, uint stackSize, uchar regNum, href heapIndex );
sref getRegisterPos( uint* stack, uchar regNum );
sref getVarargPos( uint* stack, uchar vargn );

#endif