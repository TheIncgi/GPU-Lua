#ifndef VM_H
#define VM_H
#include"common.cl"

struct WorkerEnv {
    uint* luaStack;
    uint stackSize;

    uchar* heap;
    uint maxHeapSize;

    char* error;
    uint errorSize;
    
    int* constantsPrimaryIndex;
    int* constantsSecondaryIndex;
    uchar* constantsData;

    href globals;
    href stringTable;

    //vm
    uint func = 0;
    uint pc=0;
};

bool loadk( struct WorkerEnv* env, uchar reg, uint index );

void doAxOp( struct WorkerEnv* env,  OpCode code, uint a );
bool doABxOp( struct WorkerEnv* env, OpCode code, uchar a, uint bx );
void doAsBxOp( struct WorkerEnv* env, OpCode code, uchar a, int bx );
void doABCOp( struct WorkerEnv* env, OpCode code, uchar a, ushort b, ushort c );

bool doOp( struct WorkerEnv* env, LuaInstruction instruction );

#endif