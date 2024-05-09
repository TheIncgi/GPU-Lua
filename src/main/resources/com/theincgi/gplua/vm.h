#ifndef VM_H
#define VM_H
#include"common.cl"
#include"opUtils.cl"

#define LFIELDS_PER_FLUSH 50

struct WorkerEnv {
    // uint* luaStack;
    // uint stackSize;

    href luaStack;
    uchar* maxStackSizes;

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

    int*   upvalsIndex;
    uchar* upvals; //upval definitions
    uint*  protoLengths; //how many protos per function, may be safe to remove (no usage in closure)

    href globals;
    href stringTable;
    // href constTable; //todo

    //vm
    uint func;
    uint pc;
    //href varargs; //used when vararg op b=0 & return b=0 & tailcall & call & tforcall, setlist, ...

    href error; //0 is ok
    
    bool returnFlag;
    // uint returnStart;
    href returnValue;
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
char _settable( struct WorkerEnv* env, href table, ushort b, ushort c );

bool returnRange( struct WorkerEnv* env, uchar a, uchar b);
bool isTruthy( href value );
uint vm_nVarargs( struct WorkerEnv* env );

bool doOp( struct WorkerEnv* env, LuaInstruction instruction );

bool _readAsDouble( uchar* dataSource, uint start, double* result );
bool call( struct WorkerEnv* env, href closure );
bool setupCallWithArgs( struct WorkerEnv* env, href closure, href* args, uint nargs );
bool callWithArgs( struct WorkerEnv* env, href closure, href* args, uint nargs );

#endif