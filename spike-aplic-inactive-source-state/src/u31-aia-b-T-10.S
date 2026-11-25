// u31-aia-b-T-10 (verify v15b): the interrupt-enable bit of a source that is inactive in a domain (SM = Inactive, or
// delegated to a child, or not delegated to this child) is read-only zero, and stays zero when the source becomes
// active again.
// Spec (specs/aia/src/AdvPLIC.adoc): :516-525 "An interrupt source is inactive in the interrupt domain if either the
//  source is delegated to a child domain (D = 1) or it is not delegated (D = 0) and SM is Inactive. Whenever
//  interrupt source i is inactive in an interrupt domain, the corresponding interrupt-pending and interrupt-enable
//  bits within the domain are read-only zeros ... If source i is changed from inactive to an active mode, the
//  interrupt source's pending and enable bits remain zeros, unless set automatically ..." (enable bits are never set
//  automatically); :799-802 setienum: "A write to setienum is ignored if the value written is not an active interrupt
//  source number in the domain."; :138-142 a source not delegated to a child domain "appear[s] to the domain as being
//  not implemented"; :450-454 / :789-791 unimplemented sources read 0.
// Setup: root source 1 Level1 (SM=6, the one non-zero SM Spike supports), root source 2 delegated to the S domain
// (child index 0), root source 3 inactive (sourcecfg 0; unimplemented on Whisper, N=2: reads 0 either way).
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
  WR(MB+0x1fdc, 2)
  WR(MB+0x1fdc, 3)
  // (a) root: setienum 3, source 3 inactive
  WR(MB+0x1edc, 3)
  RDBIT(x8, MB+0x1e00, 3)
  SA_SOFT(x8, 0x0, "T-10 (a) root: setienum 3 (source 3 inactive): setie[0] bit 3 stays 0 (AdvPLIC.adoc:516-521 :799-802)")
  // (b) root: setienum 2, source 2 delegated (inactive in the root)
  WR(MB+0x1edc, 2)
  RDBIT(x8, MB+0x1e00, 2)
  SA_SOFT(x8, 0x0, "T-10 (b) root: setienum 2 (source 2 delegated): setie[0] bit 2 stays 0 (:516-521 :799-802)")
  // (c) root: source 1 active, IE set (control), then made inactive, then active again
  WR(MB+0x1edc, 1)
  RDBIT(x8, MB+0x1e00, 1)
  SA_SOFT(x8, 0x1, "T-10 (c0) control: root setienum 1 (source 1 active) sets setie[0] bit 1 (:799-802)")
  WR(MB+0x4, 0x0)
  RDBIT(x8, MB+0x1e00, 1)
  SA_SOFT(x8, 0x0, "T-10 (c1) root: sourcecfg[1] = 0 (inactive): setie[0] bit 1 reads 0 (:516-521)")
  WR(MB+0x4, 0x6)
  RDBIT(x8, MB+0x1e00, 1)
  SA_SOFT(x8, 0x0, "T-10 (c2) root: sourcecfg[1] = Level1 again: setie[0] bit 1 remains 0 (:521-525)")
  // (d) S domain: source 2 delegated to S but Inactive there
  WR(SB+0x8, 0x0)
  WR(SB+0x1edc, 2)
  RDBIT(x8, SB+0x1e00, 2)
  SA_SOFT(x8, 0x0, "T-10 (d) S: setienum 2 (source 2 delegated to S, SM Inactive in S): S setie[0] bit 2 stays 0 (:516-521 :799-802)")
  WR(SB+0x8, 0x6)
  WR(SB+0x1edc, 2)
  RDBIT(x8, SB+0x1e00, 2)
  SA_SOFT(x8, 0x1, "T-10 (d0) control: S sourcecfg[2] = Level1, setienum 2 sets S setie[0] bit 2 (:799-802)")
  WR(SB+0x8, 0x400)
  RDBIT(x8, SB+0x1e00, 2)
  SA_SOFT(x8, 0x0, "T-10 (e) S (leaf): sw 0x400 to sourcecfg[2] sets it to 0 (inactive): S setie[0] bit 2 reads 0 (:478-480 :516-521)")
  WR(SB+0x8, 0x6)
  WR(SB+0x1edc, 2)
  WR(MB+0x8, 0x0)
  RDBIT(x8, SB+0x1e00, 2)
  SA_SOFT(x8, 0x0, "T-10 (f) root undelegates source 2: S setie[0] bit 2 reads 0 (source appears not implemented in S) (:138-142 :789-791)")
  WR(SB+0x1edc, 2)
  RDBIT(x8, SB+0x1e00, 2)
  SA_SOFT(x8, 0x0, "T-10 (g) S setienum 2 for a source not delegated to S is ignored (:138-142 :799-802)")
  // leave everything inactive
  WR(MB+0x4, 0x0)
  SA_SOFT_END

RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 4
v15_sv:  .fill 16*8, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
