# Spike RV32: sireg5 at siselect 0x5F (hpmevent31h) raises illegal instruction

DUT: Spike f90d5af, rv32. Run: spike --isa=rv32imafdcbvh_..._smcsrind_sscsrind_smcdeleg_ssccfg_... <elf> (riscv-arch-test config/spike/spike-rv32-max/run_cmd.txt plus smcdeleg_ssccfg; the full command is in spike-rv32-max/config/run_cmd.txt)

Test `rv32_sireg5_hpmevent31h.S`: CDE=1, mcounteren all ones; S-mode reads sireg5 at siselect 0x5E (control, no
trap) and 0x5F.

Expected (riscv-isa-manual src/priv/smcdeleg.adoc (upstream/main), Indirect HPM State Mappings): siselect 0x5F maps sireg5 to hpmevent31h (Zihpm and Sscofpmf). With
counter 31 delegated, the read does not trap.

Actual: illegal instruction at 0x5F.

Cause: riscv/csr_init.cc, CSR_SIREG5 case: `for (size_t j = 0; j < (SISELECT_SMCDELEG_END -
SISELECT_SMCDELEG_HPMEVENT_3); j++)` misses the `+ 1` that the sireg/sireg2/sireg4 loops have, so 0x5F gets no proxy.

Passing DUTs: QEMU 11.1.2 rv32, Whisper 6b8cce1 rv32.

Each directory holds the test source (riscv-arch-test tests_ai framework: boots to S-mode unless noted, M-level CSRs via the T-SBI ecall interface), the ELF, its objdump, the DUT's output and (where small) an instruction trace. A failing check prints `RVCP-SUMMARY: TEST FAILED` with the check's description, the expected and the bad value; a passing run prints no failure. Signalling was double-checked: the same ELFs pass on the DUTs listed as passing below.
