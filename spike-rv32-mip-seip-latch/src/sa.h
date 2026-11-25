// sa.h: one-line self-checks for Sail-audit reproducers (on top of ai_macros.h).
#ifndef SA_H
#define SA_H
#include "ai_macros.h"

// Fail (report _MSG, expected _EXP, actual _R) unless _R == _EXP. _EXP is an immediate/constant.
// Clobbers x4 and x5. _R must not be x4 or x5 (move it first).
#define SA_CHECK(_R, _EXP, _MSG)                            \
    .option push                                           ;\
    .option norvc                                          ;\
    LI(x4, _EXP)                                           ;\
96: beq  x4, _R, 98f                                       ;\
    jal  x5, failedtest_x5_x4                              ;\
    RVTEST_WORD_PTR 96b                                    ;\
    RVTEST_WORD_PTR 97f                                    ;\
    .pushsection .data                                     ;\
97: .string _MSG                                           ;\
    .popsection                                            ;\
98:                                                        ;\
    .option pop

// Pass if _R equals either _EXP1 or _EXP2 (two legal outcomes).
#define SA_CHECK2(_R, _EXP1, _EXP2, _MSG)                   \
    .option push                                           ;\
    .option norvc                                          ;\
    LI(x4, _EXP2)                                          ;\
    beq  x4, _R, 98f                                       ;\
    LI(x4, _EXP1)                                          ;\
96: beq  x4, _R, 98f                                       ;\
    jal  x5, failedtest_x5_x4                              ;\
    RVTEST_WORD_PTR 96b                                    ;\
    RVTEST_WORD_PTR 97f                                    ;\
    .pushsection .data                                     ;\
97: .string _MSG                                           ;\
    .popsection                                            ;\
98:                                                        ;\
    .option pop

// Trap window: SA_TRY(n) permits up to n traps; SA_TRAPS(ntraps, cause, msg) closes the window and checks
// the number of traps and the last xcause (-1 = no trap). The framework handler resumes at the next
// instruction (or at rvtest_trap_resume if set). Uses x13/x14.
#define SA_TRY(_N) AI_ALLOW(_N)
#define SA_TRAPS(_NT, _CAUSE, _MSG)                         \
    AI_OUTCOME                                             ;\
    SA_CHECK(x13, _NT, _MSG ": number of traps")           ;\
    SA_CHECK(x14, _CAUSE, _MSG ": xcause (-1 = none)")

// ---------------------------------------------------------------- soft checks (M-mode only)
// SA_SOFT(reg, expected, "msg"): on mismatch print "SA-MISMATCH: msg expect=<hex> got=<hex>" and CONTINUE.
// Use only in M-mode (printing uses the model's IO path). Clobbers x4, x5. _R must not be x4/x5.
// SA_SOFT_END (once, at the end of the test body, in M-mode): fails the test if any soft check mismatched.
#define SA_SOFT(_R, _EXP, _MSG)                             \
    .option push                                           ;\
    .option norvc                                          ;\
    LI(x4, _EXP)                                           ;\
    beq  x4, _R, 98f                                       ;\
    LA(x5, sa_soft_args)                                   ;\
    SREG x4, 0(x5)                                         ;\
    SREG _R, REGWIDTH(x5)                                  ;\
    LA(x4, 97f)                                            ;\
    SREG x4, 2*REGWIDTH(x5)                                ;\
    jal  x5, sa_soft_report                                ;\
    .pushsection .data                                     ;\
97: .string _MSG                                           ;\
    .popsection                                            ;\
98:                                                        ;\
    .option pop

#define SA_SOFT_PRINT(_PTR)                                 \
    LA(x10, _PTR)                                          ;\
    jal  x1, rvmodel_io_write_str

#define SA_SOFT_END                                         \
    LA(x4, sa_soft_count)                                  ;\
    LREG x6, 0(x4)                                         ;\
    SA_CHECK(x6, 0, "number of SA-MISMATCH soft-check failures (see the log)") ;\
    j    sa_soft_end_skip                                  ;\
sa_soft_report:                                            ;\
    LA(x4, sa_soft_save)                                   ;\
    SREG x1, 0(x4)                                         ;\
    SREG x6, 1*REGWIDTH(x4)                                ;\
    SREG x7, 2*REGWIDTH(x4)                                ;\
    SREG x8, 3*REGWIDTH(x4)                                ;\
    SREG x10, 4*REGWIDTH(x4)                               ;\
    SREG x11, 5*REGWIDTH(x4)                               ;\
    SREG x12, 6*REGWIDTH(x4)                               ;\
    SREG x5, 7*REGWIDTH(x4)                                ;\
    LA(x4, sa_soft_count)                                  ;\
    LREG x6, 0(x4)                                         ;\
    addi x6, x6, 1                                         ;\
    SREG x6, 0(x4)                                         ;\
    SA_SOFT_PRINT(sa_soft_s_hdr)                           ;\
    LA(x4, sa_soft_args)                                   ;\
    LREG x10, 2*REGWIDTH(x4)                               ;\
    jal  x1, rvmodel_io_write_str                          ;\
    SA_SOFT_PRINT(sa_soft_s_exp)                           ;\
    LA(x4, sa_soft_args)                                   ;\
    LREG x11, 0(x4)                                        ;\
    jal  x1, sa_soft_hex                                   ;\
    SA_SOFT_PRINT(sa_soft_s_got)                           ;\
    LA(x4, sa_soft_args)                                   ;\
    LREG x11, REGWIDTH(x4)                                 ;\
    jal  x1, sa_soft_hex                                   ;\
    SA_SOFT_PRINT(sa_soft_s_nl)                            ;\
    LA(x4, sa_soft_save)                                   ;\
    LREG x1, 0(x4)                                         ;\
    LREG x6, 1*REGWIDTH(x4)                                ;\
    LREG x7, 2*REGWIDTH(x4)                                ;\
    LREG x8, 3*REGWIDTH(x4)                                ;\
    LREG x10, 4*REGWIDTH(x4)                               ;\
    LREG x11, 5*REGWIDTH(x4)                               ;\
    LREG x12, 6*REGWIDTH(x4)                               ;\
    LREG x5, 7*REGWIDTH(x4)                                ;\
    jr   x5                                                ;\
sa_soft_hex:                                               ;\
    LA(x10, sa_soft_hexbuf)                                ;\
    li   x12, 2*REGWIDTH                                   ;\
    add  x10, x10, x12                                     ;\
    sb   x0, 0(x10)                                        ;\
1:  addi x10, x10, -1                                      ;\
    andi x6, x11, 15                                       ;\
    addi x6, x6, 48                                        ;\
    li   x7, 58                                            ;\
    blt  x6, x7, 2f                                        ;\
    addi x6, x6, 39                                        ;\
2:  sb   x6, 0(x10)                                        ;\
    srli x11, x11, 4                                       ;\
    addi x12, x12, -1                                      ;\
    bnez x12, 1b                                           ;\
    LA(x4, sa_soft_save)                                   ;\
    SREG x1, 8*REGWIDTH(x4)                                ;\
    jal  x1, rvmodel_io_write_str                          ;\
    LA(x4, sa_soft_save)                                   ;\
    LREG x1, 8*REGWIDTH(x4)                                ;\
    ret                                                    ;\
    .pushsection .data                                     ;\
    .p2align 3                                             ;\
sa_soft_count: .dword 0                                    ;\
sa_soft_args:  .dword 0, 0, 0                              ;\
sa_soft_save:  .dword 0, 0, 0, 0, 0, 0, 0, 0, 0, 0         ;\
sa_soft_hexbuf: .fill 24, 1, 0                             ;\
sa_soft_s_hdr: .string "SA-MISMATCH: "                     ;\
sa_soft_s_exp: .string " expect=0x"                        ;\
sa_soft_s_got: .string " got=0x"                           ;\
sa_soft_s_nl:  .string "\n"                                ;\
    .popsection                                            ;\
sa_soft_end_skip:
#endif
