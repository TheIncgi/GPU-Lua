#ifndef CLOSURE_H
#define CLOSURE_H

#include"common.cl"

/**
  * main will have closure pointint to heap[0], this indicates that there are no upvals and the env should default to globals
  * no real point in having a pointer to globals when the VM will already have that, less heap, less pointer following
  */
href createClosure(uchar* heap, uint maxHeap, uint* stack, href envTable);

#endif