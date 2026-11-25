// u31-aia-b-T-17 (verify v15b): genmsi with EIID 0 is a legal write: an extempore MSI with data 0 is sent (an IMSIC
// ignores identity 0), Busy returns to 0, and the hart continues.
// Spec (specs/aia/src/AdvPLIC.adoc): :858-862 genmsi: bits 31:18 Hart Index (WLRL), 12 Busy, 10:0 EIID (WARL);
//  :866-873 "a write to genmsi causes Busy to become one ... EIID (External Interrupt Identity) specifies the data
//  value for the MSI. Fields Hart Index and EIID have the same formats and behavior as in a target register";
//  :962-969 target EIID is a k-bit field "able to hold at least values 0 through N" and a write sets it to the low
//  k bits of the value (so EIID 0 is a legal value); :875-877 Busy reverts to false once the MSI has left;
//  IMSIC.adoc:208-209 "A write to seteipnum_le is ignored if the value written is not an implemented interrupt
//  identity number" (identities are 1..N: identity 0 does not exist).
// Setup: root domain DM = 1 (Spike: read-only 1); MSI addresses: Spike uses a custom mechanism (mmsiaddrcfgh reads
// 0x80000000, L = 1); Whisper boots with L = 0, so the test programs mmsiaddrcfg = IMSIC_M_FILE >> 12.
// Parts: (a) control genmsi hart 0 EIID 1 -> M-file eip[1] = 1; (b) genmsi EIID 0 -> Busy 0, M-file eip word 0
//  unchanged (0); (c) genmsi EIID 2 afterwards -> eip[2] = 1.
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
  #ifndef IMSIC_M_FILE
  INFO("no IMSIC on this configuration: not applicable")
  j v15_end
  #endif
  WR(MB+0x0, 0x80000004)
  RDBIT(x8, MB+0x0, 2)
  bnez x8, 1f
  INFO("root domain cannot be put in MSI mode: not applicable")
  j v15_end
1:
  RD(x8, MB+0x1bc4)
  srli x8, x8, 31
  bnez x8, 2f
  WR(MB+0x1bc0, (IMSIC_M_FILE >> 12))
  WR(MB+0x1bc4, 0)
2:
  MIMSIC_W(0x70, 1)
  MIMSIC_W(0x72, 0)
  MIMSIC_S(0xC0, 0x6)
  MIMSIC_C(0x80, 0xffffffff)
  // (a) control
  WR(MB+0x3000, 1)
  li x10, 1000
3: RDBIT(x8, MB+0x3000, 12)
  beqz x8, 4f
  addi x10, x10, -1
  bnez x10, 3b
4:
  MIMSIC_R(x8, 0x80)
  andi x8, x8, 0x6
  SA_SOFT(x8, 0x2, "T-17 (a) control: genmsi hart 0 EIID 1 sets M-file eip[1] (AdvPLIC.adoc:866-873)")
  MIMSIC_C(0x80, 0xffffffff)
  INFO("T-17: control (a) done; writing genmsi = 0 (hart 0, EIID 0)")
  // (b) EIID 0
  WR(MB+0x3000, 0)
  li x10, 1000
5: RDBIT(x8, MB+0x3000, 12)
  beqz x8, 6f
  addi x10, x10, -1
  bnez x10, 5b
6:
  SA_SOFT(x8, 0x0, "T-17 (b1) genmsi EIID 0: the hart continues and Busy returns to 0 (:875-877 :962-969)")
  MIMSIC_R(x8, 0x80)
  SA_SOFT(x8, 0x0, "T-17 (b2) genmsi EIID 0: no M-file eip bit is set (IMSIC.adoc:208-209)")
  // (c) still working
  WR(MB+0x3000, 2)
  li x10, 1000
7: RDBIT(x8, MB+0x3000, 12)
  beqz x8, 8f
  addi x10, x10, -1
  bnez x10, 7b
8:
  MIMSIC_R(x8, 0x80)
  andi x8, x8, 0x6
  SA_SOFT(x8, 0x4, "T-17 (c) genmsi EIID 2 after the EIID-0 MSI sets M-file eip[2] (:866-873)")
  MIMSIC_C(0x80, 0xffffffff)
  MIMSIC_C(0xC0, 0x6)
  MIMSIC_S(0xC0, 0x2)
v15_end:
  SA_SOFT_END

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 4
v15_sv:  .fill 16*8, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
