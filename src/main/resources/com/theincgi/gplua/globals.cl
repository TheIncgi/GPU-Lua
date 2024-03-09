#ifndef GLOBALS_CL
#define GLOBALS_CL

#include"common.cl"
#include"table.h"
#include"heapUtils.h"
#include"strings.h"

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
    NF_MATH_MDOF,
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
    NF_BIT32_BTTEST,
    NF_BIT32_RROTATE
} BitwiseFunctions;



#define NF(table, id, name) \
{ \
        string nameConstant = "foo";\
        href label = heapString(heap, maxHeapSize, stringTable, nameConstant, strLen(nameConstant));\
        if (label == 0) \
            return 0; \
        href nf = newNativeFunction(heap, maxHeapSize, stringTable, id, label); \
        if (nf == 0) \
            return 0; \
        if (!tableRawSet(heap, maxHeapSize, table, label, nf)) \
            return 0; \
}

href newNativeFunction( uchar* heap, uint maxHeapSize, href stringTable, uint id, href label ) {
    href nf = allocateHeap( heap, maxHeapSize, 9 );
    
    if(nf == 0)
        return 0;

    putHeapInt( heap, nf + 1, id );
    putHeapInt( heap, nf + 5, label );

    return nf;
}

href createMathModule( uchar* heap, uint maxHeapSize, href stringTable) {
    href mathModule = newTable( heap, maxHeapSize );
    
    NF(mathModule, NF_MATH_LOG, "log");
    NF(mathModule, NF_MATH_EXP, "exp")


    return mathModule;
}

href createGlobals( uchar* heap, uint maxHeapSize ) {
    href globalsTable = newTable( heap, maxHeapSize );
}



#endif