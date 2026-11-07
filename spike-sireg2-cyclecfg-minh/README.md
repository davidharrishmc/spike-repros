# Spike: cyclecfg read through sireg2/sireg5 shows MINH

DUT: Spike f90d5af. Run: spike --isa=rv64imafdcbvh_..._smcsrind_sscsrind_smcdeleg_ssccfg_... <elf> (riscv-arch-test config/spike/spike-rv64-max/run_cmd.txt plus smcdeleg_ssccfg; rv32 likewise)

Test `sireg2_cyclecfg_minh.S` (boots to M-mode): CDE=1, mcounteren.CY=1, mcyclecfg bits 63:32 = MINH|SINH
(0x60000000). S-mode (siselect 0x40) reads sireg2 (RV64) / sireg5 (RV32).

Expected (riscv-isa-manual src/priv/smcdeleg.adoc (upstream/main)): "If Smcntrpmf is implemented, counter configuration register bit 62 (MINH) is read-only 0 when
accessed through sireg*." So the read returns 0x20000000.

Actual: 0x60000000 (MINH visible) on rv64 and rv32.

Cause: the sireg2/sireg5 proxies at 0x40/0x42 are `counter_proxy_csr_t` objects over csrmap[CSR_MCYCLECFG(H)] /
CSR_MINSTRETCFG(H) with no MINH mask (riscv/csr_init.cc).

Passing DUTs: Whisper 6b8cce1 rv64.

Each directory holds the test source (riscv-arch-test tests_ai framework: boots to S-mode unless noted, M-level CSRs via the T-SBI ecall interface), the ELF, its objdump, the DUT's output and (where small) an instruction trace. A failing check prints `RVCP-SUMMARY: TEST FAILED` with the check's description, the expected and the bad value; a passing run prints no failure. Signalling was double-checked: the same ELFs pass on the DUTs listed as passing below.
