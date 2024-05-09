#ifndef TYPES_CL
#define TYPES_CL
//T_INT represents a signed int
#define T_INT 254
#define T_NONE 255
#define T_NIL 0
#define T_BOOL 1
#define T_NUMBER 3 //double
#define T_STRING 4
#define T_TABLE 5
#define T_FUNC 6
#define T_USERDATA 7
#define T_THREAD 8
#define T_ARRAY 0x50
#define T_HASHMAP 0x51
#define T_CLOSURE 0x52
#define T_SUBSTRING 0x54
#define T_NATIVE_FUNC 0x56
#define T_ERROR 0x57 //todo, remove, use string instead & env->error
#define T_LUA_STACK 0x58
#define T_UPVAL 0x59
#define T_VARARGS 0x5A

bool isNumber( uint type ) {
    return type == T_INT || type == T_NUMBER;
}

#endif