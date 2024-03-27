#ifndef OP_UTILS_CL
#define OP_UTILS_CL

typedef enum {
    /*-------------------------------------------------------------------------
    name            args    description
    ---------------------------------------------------------------------------*/
    OP_MOVE = 0,/*  A B     R(A) := R(B)                                     0 */
    OP_LOADK,/*     A Bx    R(A) := Kst(Bx)                                  1 */
    OP_LOADKX,/*    A       R(A) := Kst(extra arg)                           2 */
    OP_LOADBOOL,/*  A B C   R(A) := (Bool)B; if (C) pc++                     3 */
    OP_LOADNIL,/*   A B     R(A), R(A+1), ..., R(A+B) := nil                 4 */
    OP_GETUPVAL,/*  A B     R(A) := UpValue[B]                               5 */

    OP_GETTABUP,/*  A B C   R(A) := UpValue[B][RK(C)]                        6 */
    OP_GETTABLE,/*  A B C   R(A) := R(B)[RK(C)]                              7 */

    OP_SETTABUP,/*  A B C   UpValue[A][RK(B)] := RK(C)                       8 */
    OP_SETUPVAL,/*  A B     UpValue[B] := R(A)                               9 */
    OP_SETTABLE,/*  A B C   R(A)[RK(B)] := RK(C)                            10 */

    OP_NEWTABLE,/*  A B C   R(A) := {} (size = B,C)                         11 */

    OP_SELF,/*      A B C   R(A+1) := R(B); R(A) := R(B)[RK(C)]             12 */

    OP_ADD,/*       A B C   R(A) := RK(B) + RK(C)                           13 */
    OP_SUB,/*       A B C   R(A) := RK(B) - RK(C)                           14 */
    OP_MUL,/*       A B C   R(A) := RK(B) * RK(C)                           15 */
    OP_DIV,/*       A B C   R(A) := RK(B) / RK(C)                           16 */
    OP_MOD,/*       A B C   R(A) := RK(B) % RK(C)                           17 */
    OP_POW,/*       A B C   R(A) := RK(B) ^ RK(C)                           18 */
    OP_UNM,/*       A B     R(A) := -R(B)                                   19 */
    OP_NOT,/*       A B     R(A) := not R(B)                                20 */
    OP_LEN,/*       A B     R(A) := length of R(B)                          21 */

    OP_CONCAT,/*    A B C   R(A) := R(B).. ... ..R(C)                       22 */

    OP_JMP,/*       A sBx   pc+=sBx; if (A) close all upvalues >= R(A - 1)  23 */
    OP_EQ,/*        A B C   if ((RK(B) == RK(C)) ~= A) then pc++            24 */
    OP_LT,/*        A B C   if ((RK(B) <  RK(C)) ~= A) then pc++            25 */
    OP_LE,/*        A B C   if ((RK(B) <= RK(C)) ~= A) then pc++            26 */

    OP_TEST,/*      A C     if not (R(A) <=> C) then pc++                   27 */
    OP_TESTSET,/*   A B C   if (R(B) <=> C) then R(A) := R(B) else pc++     28 */

    OP_CALL,/*      A B C   R(A), ... ,R(A+C-2) := R(A)(R(A+1), ... ,R(A+B-1)) 29*/
    OP_TAILCALL,/*  A B C   return R(A)(R(A+1), ... ,R(A+B-1))              30 */
    OP_RETURN,/*    A B     return R(A), ... ,R(A+B-2)                      31 */

    OP_FORLOOP,/*   A sBx   R(A)+=R(A+2);
                            if R(A) <?= R(A+1) then { pc+=sBx; R(A+3)=R(A) } 32 */
    OP_FORPREP,/*   A sBx   R(A)-=R(A+2); pc+=sBx                           33 */

    OP_TFORCALL,/*  A C     R(A+3), ... ,R(A+2+C) := R(A)(R(A+1), R(A+2));  34 */
    OP_TFORLOOP,/*  A sBx   if R(A+1) ~= nil then { R(A)=R(A+1); pc += sBx } 35 */

    OP_SETLIST,/*   A B C   R(A)[(C-1)*FPF+i] := R(A+i), 1 <= i <= B        36 */

    OP_CLOSURE,/*   A Bx    R(A) := closure(KPROTO[Bx])                     37 */

    OP_VARARG,/*    A B     R(A), R(A+1), ..., R(A+B-2) = vararg            38 */

    OP_EXTRAARG/*   Ax      extra (larger) argument for previous opcode     39 */
} OpCode;

#define NUM_OPCODES     (cast(int, OP_EXTRAARG) + 1)

typedef unsigned int LuaInstruction;

// Functions to extract opcode and arguments
OpCode getOpcode(LuaInstruction i) {
    return i & 0x3F;
}

uchar getA(LuaInstruction i) {
    return (i >> 6) & 0xFF;
}

uint getAx(LuaInstruction i) {
    return (i >> 6) & 0x3FFFFFF; // A, B & C combined, 0x 03 FF FF FF
}

ushort getB(LuaInstruction i) {
    return (i >> 23) & 0x1FF;
}

uint getBx(LuaInstruction i) {
    return (i >> 14) & 0x3FFFF; //B and C combined (32 - opSize - aSize) >>
}

ushort getC(LuaInstruction i) {
    return (i >> 14) & 0x1FF;
}

int getsBx(LuaInstruction i) {
    return ((i >> 14) & 0x3FFFF) - 0x1FFFF; //Signed B and C combined
}

bool isK( int x ) {
    return 0 != (x & 0x100); //256
}

//uint? too small to matter?
int indexK( int r ) {
    return ((int)r) & (~0x100) ;
}

int rkAsK( int x ) {
    return x | 0x100;
}

#endif