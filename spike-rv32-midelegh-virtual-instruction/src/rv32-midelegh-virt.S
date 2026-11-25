// rv32-midelegh-virt (RV32, H + Smaia/Ssaia + Smstateen): a VS-mode or VU-mode access to the machine-level CSR
// midelegh (0x313) must raise an illegal-instruction exception (2), whatever hstateen0.AIA holds.
//
// Privileged spec, hypervisor.adoc (norm:H_cause_virtual_instruction): a virtual-instruction exception (22) replaces
//   illegal-instruction only "if the attempted instruction is HS-qualified"; for a high-half CSR
//   (norm:H_cause_virtual_instruction_high) only "if the same CSR instruction for the corresponding low-half CSR
//   ... is HS-qualified". csrr mideleg is not valid in HS-mode, so csrr midelegh is not HS-qualified.
// AIA CSRs.adoc, "Access control by the state-enable CSRs": the hstateen0 bits "concern only the state potentially
//   accessible to a virtual machine executing in privilege modes VS and VU"; bit 59 AIA: "CSRs siph and sieh (RV32
//   only) and stopi (really vsiph, vsieh, and vstopi)". midelegh is not among them.
//
// Every check prints an SA-MISMATCH line on failure and the test continues.
##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'U', 'H', 'Smaia', 'Ssaia', 'Smstateen']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####
#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#if __riscv_xlen != 32
#error "RV32 only: midelegh exists only when XLEN = 32"
#endif

// mstateen0 = all ones; hstateen0 = all ones with bit 59 (AIA, bit 27 of hstateen0h) = _AIA
#define SET_STATEEN(_HH)       \
  li x7, -1                   ;\
  csrw 0x30c, x7              ;\
  csrw 0x31c, x7              ;\
  csrw 0x60c, x7              ;\
  li x7, _HH                  ;\
  csrw 0x61c, x7
#define HSTATEEN0_AIA_1 SET_STATEEN(0xffffffff)
#define HSTATEEN0_AIA_0 SET_STATEEN(0xf7ffffff)

// Enter the mode with _GOTO, execute one CSR instruction, return to M-mode, and check the cause of the trap
// taken by the CSR instruction (x14; -1 = no trap).
#define RD(_GOTO, _CSR, _EXP, _MSG) \
  SA_TRY(1) ;\
  _GOTO ;\
  csrrs x7, _CSR, x0 ;\
  RVTEST_TSBI_GOTO_MMODE ;\
  AI_OUTCOME ;\
  SA_SOFT(x14, _EXP, _MSG)
#define WR(_GOTO, _CSR, _EXP, _MSG) \
  SA_TRY(1) ;\
  _GOTO ;\
  csrrw x7, _CSR, x0 ;\
  RVTEST_TSBI_GOTO_MMODE ;\
  AI_OUTCOME ;\
  SA_SOFT(x14, _EXP, _MSG)
#define VS RVTEST_TSBI_GOTO_VSMODE
#define VU RVTEST_TSBI_GOTO_VUMODE
#define HS RVTEST_TSBI_GOTO_SMODE
#define U  RVTEST_TSBI_GOTO_UMODE

RVTEST_BEGIN
  // ---- control: midelegh exists (M-mode read, no trap)
  SA_TRY(1)
  csrrs x7, 0x313, x0
  AI_OUTCOME
  SA_SOFT(x14, -1, "control: M-mode csrr midelegh: no trap")

  // ---- control: hstateen0.AIA = 1
  HSTATEEN0_AIA_1
  RD(VS, 0x313, 2, "control: hstateen0.AIA = 1, VS csrr midelegh: illegal instruction (2)")
  RD(VU, 0x313, 2, "control: hstateen0.AIA = 1, VU csrr midelegh: illegal instruction (2)")

  // ---- mstateen0.AIA = 1, hstateen0.AIA = 0
  HSTATEEN0_AIA_0
  RD(VS, 0x313, 2, "hstateen0.AIA = 0, VS csrr midelegh: illegal instruction (2), not virtual instruction (22)")
  RD(VU, 0x313, 2, "hstateen0.AIA = 0, VU csrr midelegh: illegal instruction (2), not virtual instruction (22)")
  WR(VS, 0x313, 2, "hstateen0.AIA = 0, VS csrw midelegh: illegal instruction (2), not virtual instruction (22)")
  WR(VU, 0x313, 2, "hstateen0.AIA = 0, VU csrw midelegh: illegal instruction (2), not virtual instruction (22)")

  // ---- controls with hstateen0.AIA = 0: the other machine-level CSRs, HS/U-mode, and a CSR the bit does control
  RD(VS, 0x303, 2, "control: hstateen0.AIA = 0, VS csrr mideleg: illegal instruction (2)")
  RD(VU, 0x303, 2, "control: hstateen0.AIA = 0, VU csrr mideleg: illegal instruction (2)")
  RD(VS, 0x314, 2, "control: hstateen0.AIA = 0, VS csrr mieh: illegal instruction (2)")
  RD(VS, 0x354, 2, "control: hstateen0.AIA = 0, VS csrr miph: illegal instruction (2)")
  RD(VS, 0x318, 2, "control: hstateen0.AIA = 0, VS csrr mvienh: illegal instruction (2)")
  RD(VS, 0x319, 2, "control: hstateen0.AIA = 0, VS csrr mviph: illegal instruction (2)")
  RD(VS, 0x312, 2, "control: hstateen0.AIA = 0, VS csrr medelegh: illegal instruction (2)")
  RD(HS, 0x313, 2, "control: hstateen0.AIA = 0, HS csrr midelegh: illegal instruction (2)")
  RD(U,  0x313, 2, "control: hstateen0.AIA = 0, U csrr midelegh: illegal instruction (2)")
  RD(VS, 0x114, 22, "control: hstateen0.AIA = 0, VS csrr sieh (really vsieh): virtual instruction (22)")

  HSTATEEN0_AIA_1
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
