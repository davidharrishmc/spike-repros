// u31-aia-b-T-08 (verify v15b): the supervisor-level APLIC domain implements no m/smsiaddrcfg(h); offsets
// 0x1BC0-0x1BCC of an S-level domain are reserved read-only zeros.
// Spec (specs/aia/src/AdvPLIC.adoc): :289-292 mmsiaddrcfg..smsiaddrcfgh "(machine-level interrupt domains only)";
//  :559-562 "For domains not at machine level, they are never implemented. When a domain does not implement
//  mmsiaddrcfg and mmsiaddrcfgh, the eight bytes at their locations are simply read-only zeros like other reserved
//  bytes."; :358-362 reserved bytes are read-only zeros; :667-668 same for smsiaddrcfg(h).
// Expected: the S domain (0x0D000000; Spike aplic_s, Whisper saplic) reads 0 at 0x1BC0/4/8/C, also after sw ~0.
##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'Zicsr', 'Smaia', 'Ssaia']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

// Platform facts (not expectations): APLIC domain bases (Spike riscv/platform.h APLIC_M_BASE/APLIC_S_BASE; Whisper
// whisper.json maplic/saplic). ADDR_SETIPNUM is defined only by Whisper's rvmodel_macros.h (its RVMODEL_BOOT
// programs the APLIC); IMSIC_S_FILE only by configs with an IMSIC.
#define MB 0x0C000000
#define SB 0x0D000000
#ifdef ADDR_SETIPNUM
  #define V15_WHISPER 1
#endif
#if __riscv_xlen == 64
  #define ZX(_r) slli _r, _r, 32; srli _r, _r, 32
#else
  #define ZX(_r) nop
#endif
// 32-bit APLIC register write / read (zero-extended). Use x6/x7 as scratch.
#define WR(_a, _v) LI(x6, _a); LI(x7, _v); sw x7, 0(x6)
#define WRR(_a, _r) LI(x6, _a); sw _r, 0(x6)
#define RD(_r, _a) LI(x6, _a); lw _r, 0(x6); ZX(_r)
// bit _b of the register at _a into _r
#define RDBIT(_r, _a, _b) RD(_r, _a); srli _r, _r, _b; andi _r, _r, 1
// print an informational line; keeps x1, x6-x8, x10
#define INFO(_MSG)                                          \
    LA(x5, v15_sv)                                         ;\
    SREG x1, 0(x5)                                         ;\
    SREG x6, 1*REGWIDTH(x5)                                ;\
    SREG x7, 2*REGWIDTH(x5)                                ;\
    SREG x8, 3*REGWIDTH(x5)                                ;\
    SREG x10, 4*REGWIDTH(x5)                               ;\
    LA(x10, 97f)                                           ;\
    jal  x1, rvmodel_io_write_str                          ;\
    LA(x5, v15_sv)                                         ;\
    LREG x1, 0(x5)                                         ;\
    LREG x6, 1*REGWIDTH(x5)                                ;\
    LREG x7, 2*REGWIDTH(x5)                                ;\
    LREG x8, 3*REGWIDTH(x5)                                ;\
    LREG x10, 4*REGWIDTH(x5)                               ;\
    .pushsection .data                                     ;\
97: .string "SA-SOFT-INFO: " _MSG "\n"                     ;\
    .popsection
// S-level IMSIC file register access from M-mode
#define SIMSIC_W(_sel, _v) li x7, _sel; csrw siselect, x7; LI(x7, _v); csrw sireg, x7
#define SIMSIC_S(_sel, _v) li x7, _sel; csrw siselect, x7; LI(x7, _v); csrs sireg, x7
#define SIMSIC_C(_sel, _v) li x7, _sel; csrw siselect, x7; LI(x7, _v); csrc sireg, x7
#define SIMSIC_R(_r, _sel) li x7, _sel; csrw siselect, x7; csrr _r, sireg
#define MIMSIC_W(_sel, _v) li x7, _sel; csrw miselect, x7; LI(x7, _v); csrw mireg, x7
#define MIMSIC_S(_sel, _v) li x7, _sel; csrw miselect, x7; LI(x7, _v); csrs mireg, x7
#define MIMSIC_C(_sel, _v) li x7, _sel; csrw miselect, x7; LI(x7, _v); csrc mireg, x7
#define MIMSIC_R(_r, _sel) li x7, _sel; csrw miselect, x7; csrr _r, mireg
// NS16550 IER (Spike: UART THR-empty interrupt = S-domain source 1 wire, level high while IER.ETBEI=1)
#define UART_IER 0x10000001
#define WIRE_HIGH LI(x6, UART_IER); li x7, 2; sb x7, 0(x6)
#define WIRE_LOW  LI(x6, UART_IER); sb x0, 0(x6)

RVTEST_BEGIN
  csrw mie, zero
  RD(x8, SB+0x1bc4)
  SA_SOFT(x8, 0x0, "T-08 (a) S domain offset 0x1BC4 (mmsiaddrcfgh location) reads 0 (AdvPLIC.adoc:559-562)")
  WR(SB+0x1bc4, 0xffffffff)
  RD(x8, SB+0x1bc4)
  SA_SOFT(x8, 0x0, "T-08 (b) S domain 0x1BC4 reads 0 after sw 0xFFFFFFFF (:559-562 :358-362)")
  RD(x8, SB+0x1bc0)
  SA_SOFT(x8, 0x0, "T-08 (c) S domain 0x1BC0 (mmsiaddrcfg location) reads 0 (:559-562)")
  RD(x8, SB+0x1bc8)
  SA_SOFT(x8, 0x0, "T-08 (d) S domain 0x1BC8 (smsiaddrcfg location) reads 0 (:667-668)")
  RD(x8, SB+0x1bcc)
  SA_SOFT(x8, 0x0, "T-08 (e) S domain 0x1BCC (smsiaddrcfgh location) reads 0 (:667-668)")
  SA_SOFT_END

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 4
v15_sv:  .fill 16*8, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
