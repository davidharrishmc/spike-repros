# Spike: an scountinhibit write clears mcountinhibit bits of non-delegated counters

DUT: Spike f90d5af. Run: spike --isa=rv64imafdcbvh_..._smcsrind_sscsrind_smcdeleg_ssccfg_... <elf> (riscv-arch-test config/spike/spike-rv64-max/run_cmd.txt plus smcdeleg_ssccfg; rv32 likewise)

Test `scountinhibit_nondeleg_write.S`: menvcfg.CDE=1, mcounteren = 0x55555555, mcountinhibit = 0xFFFFFFFD (M-mode,
T-SBI). S-mode executes `csrw scountinhibit, x0`. Then mcountinhibit is read.

Expected (spec, riscv-isa-manual src/priv/smcdeleg.adoc (upstream/main)): "For counters not delegated to S-mode, the associated bits in scountinhibit are read-only
zero." The write cannot change the non-delegated mcountinhibit bits, so mcountinhibit = 0xAAAAAAA8 (IMPL & ~mcounteren).

Actual: mcountinhibit = 0 (bad value printed = 0xaaaaaaa8 = the XOR with the expected value).

Cause: riscv/csrs.cc `scntinhibit_csr_t::unlogged_write()` does
`state->mcountinhibit->write(state->mcounteren->read() & val)`, a full write; it should merge with the
non-delegated bits of mcountinhibit.

Passing DUTs: Whisper 6b8cce1 rv64, Imperas (Smcdeleg=T). QEMU 11.1.x has the same bug (separate report).

Each directory holds the test source (riscv-arch-test tests_ai framework: boots to S-mode unless noted, M-level CSRs via the T-SBI ecall interface), the ELF, its objdump, the DUT's output and (where small) an instruction trace. A failing check prints `RVCP-SUMMARY: TEST FAILED` with the check's description, the expected and the bad value; a passing run prints no failure. Signalling was double-checked: the same ELFs pass on the DUTs listed as passing below.
