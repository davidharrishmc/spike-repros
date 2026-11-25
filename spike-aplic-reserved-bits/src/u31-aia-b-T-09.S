// u31-aia-b-T-09 (verify v15b): reserved bits of a root-domain sourcecfg register read 0.
// Spec (specs/aia/src/AdvPLIC.adoc): :462-470 delegated format (D=1): bit 10 D, bits 9:0 Child Index (WLRL), "All
//  other register bits are reserved and read as zeros."; :482-491 non-delegated format (D=0): bit 10 D, bits 2:0 SM
//  (WARL), "All other register bits are reserved and read as zeros."
// Expected: root sourcecfg[1] after sw 0xFFFFFBF9 / 0xFFFFFBFE / 0x000003F8 (D=0): bits 31:3 read 0 (SM is WARL, not
//  checked); after sw 0xFFFFFFFF (D=1; the root has a child domain): bits 31:11 read 0 (Child Index WLRL, not
//  checked). Source 1 exists on both platforms (Whisper N=2, Spike DT 53).
##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Zicsr', 'Smaia']
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
  RD(x20, MB+0x4)
  WR(MB+0x4, 0xfffffbf9)
  RD(x8, MB+0x4)
  srli x8, x8, 3
  SA_SOFT(x8, 0x0, "T-09 (a) sourcecfg[1] after sw 0xFFFFFBF9 (D=0): bits 31:3 read 0 (AdvPLIC.adoc:482-491)")
  WR(MB+0x4, 0xfffffbfe)
  RD(x8, MB+0x4)
  srli x8, x8, 3
  SA_SOFT(x8, 0x0, "T-09 (b) sourcecfg[1] after sw 0xFFFFFBFE (D=0, SM=6): bits 31:3 read 0 (:482-491)")
  WR(MB+0x4, 0x3f8)
  RD(x8, MB+0x4)
  srli x8, x8, 3
  SA_SOFT(x8, 0x0, "T-09 (c) sourcecfg[1] after sw 0x3F8 (D=0, SM=0): bits 31:3 read 0 (:482-491)")
  WR(MB+0x4, 0xffffffff)
  RD(x8, MB+0x4)
  srli x8, x8, 11
  SA_SOFT(x8, 0x0, "T-09 (d) sourcecfg[1] after sw 0xFFFFFFFF (D=1): bits 31:11 read 0 (:462-470)")
  WRR(MB+0x4, x20)
  SA_SOFT_END

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 4
v15_sv:  .fill 16*8, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
