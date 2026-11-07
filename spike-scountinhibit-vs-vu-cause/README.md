# Spike: scountinhibit from VS/VU mode: no trap with CDE=1 (VS), virtual instead of illegal with CDE=0 (VU)

DUT: Spike f90d5af. Run: spike --isa=rv64imafdcbvh_..._smcsrind_sscsrind_smcdeleg_ssccfg_... <elf> (riscv-arch-test config/spike/spike-rv64-max/run_cmd.txt plus smcdeleg_ssccfg; rv32 likewise)

Tests (H implemented; mcounteren/hcounteren all ones):
- `scountinhibit_vs_cde1_virtual.S`: menvcfg.CDE=1, VS-mode `csrr x7, scountinhibit`. Expected: virtual instruction
  (cause 22): riscv-isa-manual src/priv/smcdeleg.adoc (upstream/main) "When Supervisor Counter Delegation is enabled, attempts to access scountinhibit from VS-mode or
  VU-mode raise a virtual-instruction exception." Actual: no trap.
- `scountinhibit_vu_cde0_illegal.S`: menvcfg.CDE=0, VU-mode `csrr x7, scountinhibit`. Expected: illegal instruction
  (cause 2): "When menvcfg.CDE=0, attempts to access scountinhibit raise an illegal-instruction exception" (from every
  mode, riscv-isa-manual issue 2087); the access would be illegal in HS-mode too, so it is not HS-qualified and is not
  a virtual-instruction case. Actual: virtual instruction (cause 22).

Cause: `scntinhibit_csr_t::verify_permissions()` calls `csr_t::verify_permissions()` (the generic S-level CSR check,
virtual from VU) before its CDE check, and has no V=1 check for CDE=1.

Passing DUTs: QEMU 11.1.2, Whisper 6b8cce1 rv64, Imperas (Smcdeleg=T).

Each directory holds the test source (riscv-arch-test tests_ai framework: boots to S-mode unless noted, M-level CSRs via the T-SBI ecall interface), the ELF, its objdump, the DUT's output and (where small) an instruction trace. A failing check prints `RVCP-SUMMARY: TEST FAILED` with the check's description, the expected and the bad value; a passing run prints no failure. Signalling was double-checked: the same ELFs pass on the DUTs listed as passing below.
