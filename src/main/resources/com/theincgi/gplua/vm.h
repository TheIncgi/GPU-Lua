#ifndef VM_H
#define VM_H
#include"common.cl"
#include"opUtils.cl"

struct WorkerEnv {
    uint* luaStack;
    uint stackSize;

    uchar* heap;
    uint maxHeapSize;

    char* error;
    uint errorSize;
    
    uint* codeIndexes;
    uint* code; //[function #][instruction] = code[ codeIndexes[function] + instruction ]
    uchar* numParams;
    bool* isVararg;

    int* constantsPrimaryIndex;
    int* constantsSecondaryIndex;
    uchar* constantsData;

    href globals;
    href stringTable;

    //vm
    uint func;
    uint pc;

    bool returnFlag;
    uint returnStart;
    ushort nReturn;
};

void getConstDataRange( struct WorkerEnv* env, uint index, uint* start, uint* len );

bool loadk( struct WorkerEnv* env, uchar reg, uint index );
href _getUpVal( struct WorkerEnv* env, href closureRef, uint upval );
bool getTabUp( struct WorkerEnv* env, uchar reg, uint upvalIndexOfTable, uint tableKey );
void returnRange( struct WorkerEnv* env, uchar a, uchar b);

bool doOp( struct WorkerEnv* env, LuaInstruction instruction );

#endif