#ifndef VM_H
#define VM_H
#include"common.cl"
#include"opUtils.cl"

struct WorkerEnv {
    uint* luaStack;
    uint stackSize;

    uchar* heap;
    uint maxHeapSize;

    // char* error;
    // uint errorSize;
    
    uint* codeIndexes;
    uint* code; //[function #][instruction] = code[ codeIndexes[function] + instruction ]
    uchar* numParams;
    bool* isVararg;

    int* constantsPrimaryIndex;
    int* constantsSecondaryIndex;
    uchar* constantsData;

    href globals;
    href stringTable;
    // href constTable; //todo

    //vm
    uint func;
    uint pc;

    href error; //0 is ok

    bool returnFlag;
    uint returnStart;
    ushort nReturn;
};

void getConstDataRange( struct WorkerEnv* env, uint index, uint* start, uint* len );
bool op_move( struct WorkerEnv* env, uchar dstReg, ushort srcReg );
href kToHeap( struct WorkerEnv* env, uint index );

bool loadk( struct WorkerEnv* env, uchar reg, uint index );
href _getUpVal( struct WorkerEnv* env, href closureRef, uint upval );
bool getTabUp( struct WorkerEnv* env, uchar reg, uint upvalIndexOfTable, uint tableKey );
bool op_getTable( struct WorkerEnv* env, uchar destReg, ushort tableReg, ushort tableKey);
bool op_settabup( struct WorkerEnv* env, uchar a, ushort b, ushort c );
bool op_settable( struct WorkerEnv* env, uchar a, ushort b, ushort c );
bool _settable( struct WorkerEnv* env, href table, ushort b, ushort c );

void returnRange( struct WorkerEnv* env, uchar a, uchar b);

bool doOp( struct WorkerEnv* env, LuaInstruction instruction );

bool _readAsDouble( uchar* dataSource, uint start, double* result );
bool call( struct WorkerEnv* env, href closure );
bool callWithArgs( struct WorkerEnv* env, href closure, href* args, uint nargs );

#endif