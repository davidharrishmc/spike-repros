// u31-aia-b-T-17b (verify v15b): a forwarded source whose target EIID is 0 sends an MSI with data 0 (ignored by the
// IMSIC); the hart continues.
// Spec (specs/aia/src/AdvPLIC.adoc): :962-969 EIID "able to hold at least values 0 through N"; a write sets it to the
//  low k bits of the value (EIID 0 is legal); :1263-1264 "The data for an outgoing MSI write is taken from the EIID
//  field of target[i], zero-extended to 32 bits."; :1201-1203 an MSI is sent when IP, IE and domaincfg.IE are 1;
//  :521-525 after activation the target fields are UNSPECIFIED (Spike's reset/after-activation value is 0);
//  IMSIC.adoc:208-209 a write of a non-identity (0) to seteipnum is ignored.
// Platform: Spike's NS16550 THR-empty interrupt drives S-domain source 1 (level high while IER.ETBEI = 1).
// Setup: root delegates source 1; S: MSI mode, IE = 1, source 1 Level1, target[1] written 0 (hart 0, guest 0, EIID 0),
// IE[1] = 1; the wire rises -> MSI with data 0. Expected: the hart reaches the checks; S-file eip word 0 = 0.
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
  WR(SB+0x3004, 0)
  RD(x20, SB+0x3004)
  WR(SB+0x1edc, 1)
  SIMSIC_C(0x80, 0xffffffff)
  INFO("T-17b: setup done; raising the source wire (MSI with EIID 0 follows)")
  WIRE_HIGH
  li x10, 200
3: addi x10, x10, -1
  bnez x10, 3b
  SIMSIC_R(x21, 0x80)
  WIRE_LOW
  SA_SOFT(x20, 0x0, "T-17b setup: S target[1] = 0 (hart 0, guest 0, EIID 0) (AdvPLIC.adoc:962-969)")
  SA_SOFT(x21, 0x0, "T-17b forwarded MSI with EIID 0: the hart continues and no S-file eip bit is set (:1263-1264; IMSIC.adoc:208-209)")
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
