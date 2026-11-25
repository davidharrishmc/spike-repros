// u31-aia-b-T-12 (verify v15b): a write to target[i] of an active source in MSI mode sets its fields from the value
// written, whatever that value is numerically.
// Spec (specs/aia/src/AdvPLIC.adoc): :886-890 target[i] of an active source determines the hart; :933-943 MSI-mode
//  format: bits 31:18 Hart Index (WLRL), 17:12 Guest Index (WLRL), 10:0 EIID (WARL), bit 11 reserved;
//  :962-969 "EIID is a k-bit unsigned integer field, where ceil(log2 N) <= k <= 11 ... A write to a target register
//  sets the k implemented bits of EIID equal to the least-significant k bits of the 32-bit value written."
//  (N = IMSIC identities >= 63, so k >= 6.)
// Setup: both domains DM = 1 (Spike: DM is read-only 1; Whisper: writable), IE = 0; root source 1 Level1; root
// delegates source 2 to S; S source 2 Level1. Hart Index 0 and Guest Index 0 are used, so only EIID varies.
// Expected: root target[1] after sw 5 = 5; after sw 0x406 = 0x406 (k = 11) or 6 (k <= 10); S target[2] after sw 2 = 2,
//  after sw 3 = 3.
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
  RDBIT(x8, MB+0x0, 2)
  RDBIT(x9, SB+0x0, 2)
  and x8, x8, x9
  bnez x8, v15_msi
  INFO("T-12: a domain cannot be put in MSI mode: not applicable")
  j v15_end
v15_msi:
  WR(MB+0x4, 0x6)
  WR(MB+0x3004, 5)
  RD(x8, MB+0x3004)
  SA_SOFT(x8, 0x5, "T-12 (a) control: root target[1] after sw 5 = 5 (AdvPLIC.adoc:933-969)")
  WR(MB+0x3004, 0x406)
  RD(x8, MB+0x3004)
  LI(x9, 0x406)
  bne x8, x9, 1f
  li x8, 6
1:
  SA_SOFT(x8, 0x6, "T-12 (b) root target[1] after sw 0x406 = EIID 0x406 (k = 11) or 6 (k <= 10); 0x406 shown as 6 (:962-969)")
  WR(MB+0x8, 0x400)
  WR(SB+0x8, 0x6)
  WR(SB+0x3008, 2)
  RD(x8, SB+0x3008)
  SA_SOFT(x8, 0x2, "T-12 (c) control: S target[2] after sw 2 = 2 (:933-969)")
  WR(SB+0x3008, 3)
  RD(x8, SB+0x3008)
  SA_SOFT(x8, 0x3, "T-12 (d) S target[2] after sw 3 = 3 (EIID 3) (:962-969)")
  WR(SB+0x8, 0x0)
  WR(MB+0x8, 0x0)
  WR(MB+0x4, 0x0)
v15_end:
  SA_SOFT_END

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 4
v15_sv:  .fill 16*8, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
