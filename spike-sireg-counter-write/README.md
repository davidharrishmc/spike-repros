# Spike: writes to a delegated counter (or hpmevent) through sireg* raise illegal instruction

DUT: Spike f90d5af (riscv-arch-test CI pin). Run: spike --isa=rv64imafdcbvh_..._smcsrind_sscsrind_smcdeleg_ssccfg_... <elf> (riscv-arch-test config/spike/spike-rv64-max/run_cmd.txt plus smcdeleg_ssccfg; rv32 likewise)

Tests (CDE=1, mcounteren all ones):
- `sireg_counter_write.S`: siselect 0x40 (cycle); S-mode `csrw sireg4, x6` (RV32) and `csrw sireg, x6`. Expected:
  no trap. Actual: illegal instruction (scause 2) on the first write.
- `sireg_csrrw_old_value.S`: siselect 0x43 (hpmcounter3): the setup write `csrw sireg, x6`
  traps (illegal) already.
- `rv32_sireg5_write.S` (RV32): siselect 0x43, `csrw sireg5, x6` (hpmevent3h) traps.

Expected (riscv-isa-manual src/priv/smcdeleg.adoc (upstream/main)): "These extensions provide a means for M-mode to allow writing select counters and event selectors
from S/HS-mode"; "When a counter i is delegated ... sireg* aliases counter i." So a delegated counter is writable
through sireg* from M and S mode.

Cause: riscv/csr_init.cc registers the user-level read-only counters (csrmap[CSR_CYCLE], CSR_HPMCOUNTER3+j, and
counter_proxy_csr_t objects numbered as CSR_HPMCOUNTER3H+j) as the sireg* proxies, and
`sscsrind_reg_csr_t::verify_permissions()` ends with `proxy_csr->verify_permissions(insn, write)`, which rejects any
write to a read-only (0xC00-0xC9F) CSR number.

Passing DUTs: Whisper 6b8cce1 rv64, QEMU (for the plain csrw).

Each directory holds the test source (riscv-arch-test tests_ai framework: boots to S-mode unless noted, M-level CSRs via the T-SBI ecall interface), the ELF, its objdump, the DUT's output and (where small) an instruction trace. A failing check prints `RVCP-SUMMARY: TEST FAILED` with the check's description, the expected and the bad value; a passing run prints no failure. Signalling was double-checked: the same ELFs pass on the DUTs listed as passing below.
