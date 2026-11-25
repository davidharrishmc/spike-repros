// u31-aia-b-T-15 (verify v15b): in MSI delivery mode a Level1 source keeps its pending bit while it cannot be
// forwarded, and is forwarded as soon as IE (or domaincfg.IE) becomes 1.
// Spec (specs/aia/src/AdvPLIC.adoc): :1013-1020 Level1/Level0 with DM = 1: "The pending bit is set to one by a
//  low-to-high transition in the rectified input value ... The pending bit is cleared whenever the rectified input
//  value is low, when the interrupt is forwarded by MSI, or by a relevant write to an in_clrip register or to
//  clripnum."; :1201-1203 "An MSI is sent for a specific source only when the source's corresponding pending and
//  enable bits are both one and the IE field of register domaincfg is also one."; :392-399 domaincfg.IE "has no
//  effect on any other APLIC state, including the interrupt-enable and interrupt-pending bits"; :730-732 a read of
//  setip returns the pending bits. Ruling aia#153 (jhauser): "an MSI is sent only when both the IP and IE bits of an
//  interrupt source are set (bit value = 1) simultaneously" (IP must therefore persist until IE is set); aia#58: the
//  wire must stay asserted (it does here: the UART wire is held high throughout each part).
// Platform: Spike's NS16550 THR-empty interrupt (IER.ETBEI) drives S-domain source 1 (device tree), level high.
// Parts: (a) IE[1] = 0, wire rises: setip[0] bit 1 = 1, no MSI; setienum 1 -> MSI (S-file eip[1] = 1).
//        (b) IE[1] = 1, domaincfg.IE = 0, wire rises: setip bit 1 = 1, no MSI; domaincfg.IE = 1 -> MSI.
// Results are recorded in x20-x25 while the wire is high (the UART is the print path) and checked afterwards.
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
  #if defined(V15_WHISPER) || !defined(IMSIC_S_FILE)
  INFO("no software-drivable APLIC source wire on this platform (Spike: UART = S-domain source 1): not applicable")
  j v15_end
  #endif
  // S-level IMSIC file: eidelivery 1, eithreshold 0, eie[1] = 1, eip[1] = 0
  SIMSIC_W(0x70, 1)
  SIMSIC_W(0x72, 0)
  SIMSIC_S(0xC0, 0x2)
  SIMSIC_C(0x80, 0x2)
  // root delegates source 1 to the S domain; S domain in MSI mode
  WR(MB+0x4, 0x400)
  WR(SB+0x0, 0x80000104)
  RDBIT(x8, SB+0x0, 2)
  bnez x8, 1f
  INFO("S domain cannot be put in MSI mode: not applicable")
  j v15_end
1:
  WR(SB+0x4, 0x6)
  RD(x8, SB+0x4)
  li x7, 6
  beq x8, x7, 2f
  INFO("Level1 not supported for S source 1: not applicable")
  j v15_end
2:
  WR(SB+0x3004, 1)
  RD(x8, SB+0x3004)
  SA_SOFT(x8, 0x1, "T-15 setup: S target[1] = hart 0, guest 0, EIID 1")
  // (a) IE[1] = 0
  WR(SB+0x1fdc, 1)
  SIMSIC_C(0x80, 0x2)
  WIRE_HIGH
  RDBIT(x20, SB+0x1c00, 1)
  SIMSIC_R(x21, 0x80)
  srli x21, x21, 1
  andi x21, x21, 1
  WR(SB+0x1edc, 1)
  li x10, 1000
3: SIMSIC_R(x22, 0x80)
  srli x22, x22, 1
  andi x22, x22, 1
  bnez x22, 4f
  addi x10, x10, -1
  bnez x10, 3b
4:
  WIRE_LOW
  // (b) IE[1] = 1, domaincfg.IE = 0
  SIMSIC_C(0x80, 0x2)
  WR(SB+0x0, 0x80000004)
  WIRE_HIGH
  SIMSIC_R(x23, 0x80)
  srli x23, x23, 1
  andi x23, x23, 1
  RDBIT(x24, SB+0x1c00, 1)
  WR(SB+0x0, 0x80000104)
  li x10, 1000
5: SIMSIC_R(x25, 0x80)
  srli x25, x25, 1
  andi x25, x25, 1
  bnez x25, 6f
  addi x10, x10, -1
  bnez x10, 5b
6:
  WIRE_LOW
  SA_SOFT(x20, 0x1, "T-15 (a1) wire high with IE[1] = 0: setip[0] bit 1 (IP) = 1 (AdvPLIC.adoc:1013-1020 :730-732)")
  SA_SOFT(x21, 0x0, "T-15 (a2) control: no MSI while IE[1] = 0 (:1201-1203)")
  SA_SOFT(x22, 0x1, "T-15 (a3) setienum 1 with IP[1] = 1 sends the MSI: S-file eip[1] = 1 (:1201-1203, aia#153)")
  SA_SOFT(x23, 0x0, "T-15 (b1) control: no MSI while domaincfg.IE = 0 (:392-394)")
  SA_SOFT(x24, 0x1, "T-15 (b2) wire high with domaincfg.IE = 0: IP[1] = 1 (:396-399 :1013-1020)")
  SA_SOFT(x25, 0x1, "T-15 (b3) domaincfg.IE = 1 forwards the pending source: S-file eip[1] = 1 (:392-394 :1201-1203)")
  WR(SB+0x4, 0x0)
  WR(MB+0x4, 0x0)
v15_end:
  SA_SOFT_END

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 4
v15_sv:  .fill 16*8, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
