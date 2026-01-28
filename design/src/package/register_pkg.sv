`timescale 1ns / 1ps
package register_pkg;

    typedef enum logic [4:0]{
        x0, x1, x2, x3, x4, x5, x6, x7, x8, x9,
        x10, x11, x12, x13, x14, x15, x16, x17, x18, x19,
        x20, x21, x22, x23, x24, x25, x26, x27, x28, x29,
        x30, x31
    }architected_reg_t;

    typedef enum logic [4:0]{
        zero, ra, // -------------------------------------------------------
        sp, gp, tp, // stack, global, thread pointers
        t0, t1, t2, // temporary registers
        s0, s1, // saved registers / frame pointer
        a0, a1, a2, a3, a4, a5, a6, a7, // function arguments / return values
        s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, // saved registers
        t3, t4, t5, t6 // more temporary registers
    }register_t;

    typedef enum logic [5:0]{
        r0, r1, r2, r3, r4, r5, r6, r7, r8, r9,
        r10, r11, r12, r13, r14, r15, r16, r17, r18, r19,
        r20, r21, r22, r23, r24, r25, r26, r27, r28, r29,
        r30, r31, r32, r33, r34, r35, r36, r37, r38, r39,
        r40, r41, r42, r43, r44, r45, r46, r47, r48, r49,
        r50, r51, r52, r53, r54, r55, r56, r57, r58, r59,
        r60, r61, r62, r63
    }physical_reg_t;

endpackage
