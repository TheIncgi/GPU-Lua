#ifndef GLOBALS_CL
#define GLOBALS_CL

#include"common.cl"
#include"table.h"
#include"heapUtils.h"
#include"strings.h"
#include"types.cl"
#include"vm.h"

typedef enum {
    NF_MATH_LOG = 1,
    NF_MATH_EXP,
    NF_MATH_ACOS,
    NF_MATH_ATAN,
    NF_MATH_LDEXP,
    NF_MATH_DEG,
    NF_MATH_RAD,
    NF_MATH_TAN,
    NF_MATH_COS,
    NF_MATH_COSH,
    NF_MATH_RANDOM,
    NF_MATH_FREXP,
    NF_MATH_RANDOMSEED,
    NF_MATH_CEIL,
    NF_MATH_TANH,
    NF_MATH_FLOOR,
    NF_MATH_ABS,
    NF_MATH_MAX,
    NF_MATH_SQRT,
    NF_MATH_MODF,
    NF_MATH_SINH,
    NF_MATH_ASIN,
    NF_MATH_MIN,
    NF_MATH_FMOD,
    NF_MATH_POW,
    NF_MATH_ATAN2,
    NF_MATH_SIN
} MathFunctions;



typedef enum {
    NF_GLOBAL_ASSERT = ((int)NF_MATH_SIN + 1),
    NF_GLOBAL_COLLECTGARBAGE,
    NF_GLOBAL_ERROR,
    NF_GLOBAL_GETMETATABLE,
    NF_GLOBAL_IPAIRS,
    NF_GLOBAL_NEXT,
    NF_GLOBAL_PAIRS,
    NF_GLOBAL_PCALL,
    NF_GLOBAL_RAWEQUAL,
    NF_GLOBAL_RAWGET,
    NF_GLOBAL_RAWLEN,
    NF_GLOBAL_RAWSET,
    NF_GLOBAL_SELECT,
    NF_GLOBAL_SETMETATABLE,
    NF_GLOBAL_TONUMBER,
    NF_GLOBAL_TOSTRING,
    NF_GLOBAL_TYPE,
    NF_GLOBAL_XPCALL
} GlobalFunctions;

typedef enum {
    NF_STRING_SUB = ((int)NF_GLOBAL_XPCALL + 1),
    NF_STRING_FIND,
    NF_STRING_REP,
    NF_STRING_MATCH,
    NF_STRING_GMATCH,
    NF_STRING_CHAR,
    NF_STRING_REVERSE,
    NF_STRING_UPPER,
    NF_STRING_LEN,
    NF_STRING_GSUB,
    NF_STRING_BYTE,
    NF_STRING_FORMAT,
    NF_STRING_LOWER
} StringFunctions;


typedef enum {
    NF_TABLE_REMOVE = ((int)NF_STRING_LOWER + 1),
    NF_TABLE_PACK,
    NF_TABLE_CONCAT,
    NF_TABLE_SORT,
    NF_TABLE_INSERT,
    NF_TABLE_UNPACK,
    NF_TABLE_PRESIZE
} TableFunctions;

typedef enum {
    NF_BIT32_BAND = ((int)NF_TABLE_PRESIZE + 1),
    NF_BIT32_LROTATE,
    NF_BIT32_EXTRACT,
    NF_BIT32_RSHIFT,
    NF_BIT32_BOR,
    NF_BIT32_BNOT,
    NF_BIT32_ARSHIFT,
    NF_BIT32_BXOR,
    NF_BIT32_REPLACE,
    NF_BIT32_LSHIFT,
    NF_BIT32_BTEST,
    NF_BIT32_RROTATE
} BitwiseFunctions;



href newNativeFunction( uchar* heap, uint maxHeapSize, uint id, href label ) {
    href nf = allocateHeap( heap, maxHeapSize, 9 );
    
    if(nf == 0)
        return 0;

    heap[nf] = T_NATIVE_FUNC;
    putHeapInt( heap, nf + 1, id );
    putHeapInt( heap, nf + 5, label );
    return nf;
}

bool globals_registerNF(struct WorkerEnv* env, href table, uint id, string name) {
    uchar* heap = env->heap;
    uint maxHeapSize = env->maxHeapSize;
    string nameConstant = name;
    href label = heapString( env, nameConstant);
    if (label == 0) 
        return false; 
    href nf = newNativeFunction(heap, maxHeapSize, id, label); 
    if (nf == 0) 
        return false;
    
    if (!tableRawSet(heap, maxHeapSize, table, label, nf))
        return false;
    
    return true; 
}

href createMathModule(struct WorkerEnv* env) {
    uchar* heap = env->heap;
    uint maxHeapSize = env->maxHeapSize;
    href mathModule = newTable( heap, maxHeapSize );
    
    if(!globals_registerNF(env, mathModule, NF_MATH_LOG,              "log")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_EXP,              "exp")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_ACOS,            "acos")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_ATAN,            "atan")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_LDEXP,           "ldexp")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_DEG,             "deg")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_RAD,             "rad")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_TAN,             "tan")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_COS,             "cos")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_COSH,            "cosh")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_RANDOM,          "random")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_FREXP,           "frexp")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_RANDOMSEED,      "randomseed")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_CEIL,            "ceil")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_TANH,            "tanh")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_FLOOR,           "floor")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_ABS,             "abs")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_MAX,             "max")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_SQRT,            "sqrt")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_MODF,            "modf")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_SINH,            "sinh")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_ASIN,            "asin")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_MIN,             "min")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_FMOD,            "fmod")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_POW,             "pow")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_ATAN2,           "atan2")) return 0;
    if(!globals_registerNF(env, mathModule, NF_MATH_SIN,             "sin")) return 0;
    
    return mathModule;
}

href createStringModule(struct WorkerEnv* env) {
    uchar* heap = env->heap;
    uint maxHeapSize = env->maxHeapSize;
    href stringModule = newTable( heap, maxHeapSize );
    
    if(!globals_registerNF(env, stringModule, NF_STRING_SUB,              "sub")) return 0;
    if(!globals_registerNF(env, stringModule, NF_STRING_FIND,             "find")) return 0;
    if(!globals_registerNF(env, stringModule, NF_STRING_REP,              "rep")) return 0;
    if(!globals_registerNF(env, stringModule, NF_STRING_MATCH,            "match")) return 0;
    if(!globals_registerNF(env, stringModule, NF_STRING_GMATCH,           "gmatch")) return 0;
    if(!globals_registerNF(env, stringModule, NF_STRING_CHAR,             "char")) return 0;
    if(!globals_registerNF(env, stringModule, NF_STRING_REVERSE,          "reverse")) return 0;
    if(!globals_registerNF(env, stringModule, NF_STRING_UPPER,            "upper")) return 0;
    if(!globals_registerNF(env, stringModule, NF_STRING_LEN,              "len")) return 0;
    if(!globals_registerNF(env, stringModule, NF_STRING_GSUB,             "gsub")) return 0;
    if(!globals_registerNF(env, stringModule, NF_STRING_BYTE,             "byte")) return 0;
    if(!globals_registerNF(env, stringModule, NF_STRING_FORMAT,           "format")) return 0;
    if(!globals_registerNF(env, stringModule, NF_STRING_LOWER,            "lower")) return 0;
    
    return stringModule;
}

href createTableModule(struct WorkerEnv* env) {
    uchar* heap = env->heap;
    uint maxHeapSize = env->maxHeapSize;
    href tableModule = newTable( heap, maxHeapSize );
    
    if(!globals_registerNF(env, tableModule, NF_TABLE_REMOVE,        "remove")) return 0;
    if(!globals_registerNF(env, tableModule, NF_TABLE_PACK,          "pack")) return 0;
    if(!globals_registerNF(env, tableModule, NF_TABLE_CONCAT,        "concat")) return 0;
    if(!globals_registerNF(env, tableModule, NF_TABLE_SORT,          "sort")) return 0;
    if(!globals_registerNF(env, tableModule, NF_TABLE_INSERT,        "insert")) return 0;
    if(!globals_registerNF(env, tableModule, NF_TABLE_UNPACK,        "unpack")) return 0;
    if(!globals_registerNF(env, tableModule, NF_TABLE_PRESIZE,       "presize")) return 0;
    
    return tableModule;
}

href createBit32Module(struct WorkerEnv* env) {
    uchar* heap = env->heap;
    uint maxHeapSize = env->maxHeapSize;
    href bitModule = newTable( heap, maxHeapSize );
    
    if(!globals_registerNF(env, bitModule, NF_BIT32_BAND,            "band")) return 0;
    if(!globals_registerNF(env, bitModule, NF_BIT32_LROTATE,         "lrotate")) return 0;
    if(!globals_registerNF(env, bitModule, NF_BIT32_EXTRACT,         "extract")) return 0;
    if(!globals_registerNF(env, bitModule, NF_BIT32_RSHIFT,          "rshift")) return 0;
    if(!globals_registerNF(env, bitModule, NF_BIT32_BOR,             "bor")) return 0;
    if(!globals_registerNF(env, bitModule, NF_BIT32_BNOT,            "bnot")) return 0;
    if(!globals_registerNF(env, bitModule, NF_BIT32_ARSHIFT,         "arshift")) return 0;
    if(!globals_registerNF(env, bitModule, NF_BIT32_BXOR,            "bxor")) return 0;
    if(!globals_registerNF(env, bitModule, NF_BIT32_REPLACE,         "replace")) return 0;
    if(!globals_registerNF(env, bitModule, NF_BIT32_LSHIFT,          "lshift")) return 0;
    if(!globals_registerNF(env, bitModule, NF_BIT32_BTEST,           "btest")) return 0;
    if(!globals_registerNF(env, bitModule, NF_BIT32_RROTATE,         "rrotate")) return 0;
    
    return bitModule;
}

bool createGlobalFunctions(struct WorkerEnv* env, href globalsTable) {
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_ASSERT,         "assert")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_COLLECTGARBAGE, "collectgarbage")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_ERROR,          "error")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_GETMETATABLE,   "getmetatable")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_IPAIRS,         "ipairs")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_NEXT,           "next")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_PAIRS,          "pairs")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_PCALL,          "pcall")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_RAWEQUAL,       "rawequal")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_RAWGET,         "rawget")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_RAWLEN,         "rawlen")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_RAWSET,         "rawset")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_SELECT,         "select")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_SETMETATABLE,   "setmetatable")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_TONUMBER,       "tonumber")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_TOSTRING,       "tostring")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_TYPE,           "type")) return false;
    if(!globals_registerNF(env, globalsTable, NF_GLOBAL_XPCALL,         "xpcall")) return false;    
    return true;
}

href createGlobals( struct WorkerEnv* env ) {
    uchar* heap = env->heap;
    uint maxHeapSize = env->maxHeapSize;
    href globalsTable = newTable( heap, maxHeapSize );
    
    if( globalsTable == 0 )
        return 0;
    
    string moduleName;
    href moduleNameHref;
    href moduleTableHref;

    moduleName = "math";
    moduleNameHref = heapString( env, moduleName );
    if( moduleNameHref == 0 ) return 0;
    moduleTableHref = createMathModule( env );
    if( moduleTableHref == 0 ) return 0;
    tableRawSet( heap, maxHeapSize, globalsTable, moduleNameHref, moduleTableHref );

    moduleName = "string";
    moduleNameHref = heapString( env, moduleName );
    if( moduleNameHref == 0 ) return 0;
    moduleTableHref = createStringModule( env );
    if( moduleTableHref == 0 ) return 0;
    tableRawSet( heap, maxHeapSize, globalsTable, moduleNameHref, moduleTableHref );

    moduleName = "table";
    moduleNameHref = heapString( env, moduleName );
    if( moduleNameHref == 0 ) return 0;
    moduleTableHref = createTableModule( env );
    if( moduleTableHref == 0 ) return 0;
    tableRawSet( heap, maxHeapSize, globalsTable, moduleNameHref, moduleTableHref );

    moduleName = "bit32";
    moduleNameHref = heapString( env, moduleName );
    if( moduleNameHref == 0 ) return 0;
    moduleTableHref = createBit32Module( env );
    if( moduleTableHref == 0 ) return 0;
    tableRawSet( heap, maxHeapSize, globalsTable, moduleNameHref, moduleTableHref );

    if( !createGlobalFunctions( env, globalsTable ) )
        return 0;

    return globalsTable;
}



#endif