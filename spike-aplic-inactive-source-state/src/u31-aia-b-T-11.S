// u31-aia-b-T-11 (verify v15b): root-domain setie[k]/clrie[k] bulk writes act on the domain's active sources.
// Spec (specs/aia/src/AdvPLIC.adoc): :793-795 "On a write to a setie register, for each bit that is one in the 32-bit
//  value written, if that bit position corresponds to an active interrupt source, the interrupt-enable bit for that
//  source is set to one."; :812 "On a write to a clrie register, for each bit that is one in the 32-bit value
//  written, the interrupt-enable bit for that source is cleared."; :516-521 IE of inactive (incl. delegated) sources
//  read-only 0.
// Setup: root source 1 Level1 (active), source 2 delegated to S (inactive in the root), 3.. inactive/unimplemented.
// Expected: root setie[0] after sw 0xFFFFFFFF = 0x2; after setienum 1 + sw 0xFFFFFFFF to clrie[0], setie[0] = 0.
// Control (S domain, source 2 Level1): S setie[0] after sw ~0 = 0x4; after S clrie[0] sw ~0 = 0.
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
  WR(MB+0x4, 0x6)
  WR(MB+0x8, 0x400)
  WR(MB+0xc, 0x0)
  WR(MB+0x1fdc, 1)
  RDBIT(x8, MB+0x1e00, 1)
  SA_SOFT(x8, 0x0, "T-11 setup: clrienum 1 clears root IE[1] (:817-821)")
  WR(MB+0x1e00, 0xffffffff)
  RDBIT(x8, MB+0x1e00, 1)
  SA_SOFT(x8, 0x1, "T-11 (a) root setie[0] sw 0xFFFFFFFF sets IE[1] of active source 1 (AdvPLIC.adoc:793-795)")
  RD(x8, MB+0x1e00)
  SA_SOFT(x8, 0x2, "T-11 (b) root setie[0] after sw 0xFFFFFFFF = 0x2 (only active source 1) (:793-795 :516-521)")
  WR(MB+0x1edc, 1)
  WR(MB+0x1f00, 0xffffffff)
  RDBIT(x8, MB+0x1e00, 1)
  SA_SOFT(x8, 0x0, "T-11 (c) root clrie[0] sw 0xFFFFFFFF clears IE[1] of active source 1 (:812)")
  // control in the S domain
  WR(SB+0x8, 0x6)
  WR(SB+0x1fdc, 2)
  WR(SB+0x1e00, 0xffffffff)
  RD(x8, SB+0x1e00)
  SA_SOFT(x8, 0x4, "T-11 (d) control: S setie[0] after sw 0xFFFFFFFF = 0x4 (only source 2, delegated and active in S) (:793-795)")
  WR(SB+0x1f00, 0xffffffff)
  RD(x8, SB+0x1e00)
  SA_SOFT(x8, 0x0, "T-11 (e) control: S clrie[0] sw 0xFFFFFFFF clears it (:812)")
  WR(SB+0x8, 0x0)
  WR(MB+0x8, 0x0)
  WR(MB+0x4, 0x0)
  SA_SOFT_END

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 4
v15_sv:  .fill 16*8, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
