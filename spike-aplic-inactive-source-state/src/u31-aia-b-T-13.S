// u31-aia-b-T-13 (verify v15b): target[i] of a source that is inactive in the domain is read-only zero.
// Spec (specs/aia/src/AdvPLIC.adoc): :516-521 "Whenever interrupt source i is inactive in an interrupt domain, the
//  corresponding interrupt-pending and interrupt-enable bits within the domain are read-only zeros, and register
//  target[i] is also read-only zero."; :888 "If interrupt source i is inactive in this domain, register target[i] is
//  read-only zero."; :516-518 inactive = delegated (D = 1) or D = 0 with SM Inactive; :478-480 a leaf-domain write
//  with bit 10 set zeroes the whole sourcecfg.
// Setup: both domains DM = 1 where possible (values 1..5 used are legal in either format: direct-mode Hart 0 IPRIO v;
// MSI Hart 0 EIID v), IE = 0. Writes use small values so that Spike's value-gated target write (T-12) accepts them.
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
  WR(MB+0x0, 0x80000004)
  WR(SB+0x0, 0x80000004)
  // (a) root source 1 active, target 5 (control), then made inactive
  WR(MB+0x4, 0x6)
  WR(MB+0x3004, 5)
  RD(x8, MB+0x3004)
  SA_SOFT(x8, 0x5, "T-13 (a0) control: root target[1] of active source 1 after sw 5 = 5")
  WR(MB+0x4, 0x0)
  RD(x8, MB+0x3004)
  SA_SOFT(x8, 0x0, "T-13 (a) root sourcecfg[1] = 0 (inactive): target[1] reads 0 (AdvPLIC.adoc:516-521 :888)")
  WR(MB+0x3004, 3)
  RD(x8, MB+0x3004)
  SA_SOFT(x8, 0x0, "T-13 (b) root target[1] stays 0 after sw 3 while source 1 is inactive (:888)")
  // (c) root source 2 delegated: target[2] in the root
  WR(MB+0x8, 0x400)
  WR(MB+0x3008, 1)
  RD(x8, MB+0x3008)
  SA_SOFT(x8, 0x0, "T-13 (c) root target[2] of delegated source 2 reads 0 after sw 1 (:516-521 :888)")
  // (d) S source 2 active (control), then leaf D=1 write makes it inactive
  WR(SB+0x8, 0x6)
  WR(SB+0x3008, 2)
  RD(x8, SB+0x3008)
  SA_SOFT(x8, 0x2, "T-13 (d0) control: S target[2] of active source 2 after sw 2 = 2")
  WR(SB+0x8, 0x400)
  RD(x8, SB+0x8)
  SA_SOFT(x8, 0x0, "T-13 (d1) S (leaf) sourcecfg[2] after sw 0x400 = 0 (:478-480)")
  RD(x8, SB+0x3008)
  SA_SOFT(x8, 0x0, "T-13 (d) S target[2] reads 0 once source 2 is inactive in S (:516-521 :888)")
  WR(MB+0x8, 0x0)
  SA_SOFT_END

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 4
v15_sv:  .fill 16*8, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
