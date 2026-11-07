# Spike: mvien[13] and hvien[13] (LCOFI) are read-only zero with Smcdeleg, Sscofpmf and Smaia

DUT: Spike f90d5af. Run: spike --isa=rv64imafdcbvh_..._smcsrind_sscsrind_smcdeleg_ssccfg_... <elf> (riscv-arch-test config/spike/spike-rv64-max/run_cmd.txt plus smcdeleg_ssccfg; rv32 likewise)

Test `mvien_hvien_lcofi_writable.S` (boots to M-mode): CDE=1; `csrs mvien, 1<<13`, read; `csrs hvien, 1<<13`, read.

Expected (riscv-isa-manual src/priv/smcdeleg.adoc (upstream/main)): "For implementations that support Smcdeleg, Sscofpmf, and Smaia, the local-counter-overflow
interrupt (LCOFI) bit (bit 13) in each of CSRs mvip and mvien is implemented and writable." and "... Smaia/Ssaia, and
the H extension, the LCOFI bit (bit 13) in each of hvip and hvien is implemented and writable."

Actual: mvien[13] reads 0 (the test stops at that first check).

`probe/hv.S` (bare metal, rv64, M-mode; `probe/l.ld`, prebuilt `probe/hv.elf`) shows all four bits. It sets
menvcfg.CDE=1, then `csrs` bit 13 of mvip, mvien, hvien and hvip and reads each back, and stores
tohost = 8 | mvien[13] | hvien[13]<<1 | hvip[13]<<2 | mvip[13]<<4 (bit 3 is a marker, so Spike always prints
FAILED; the value is the readout).

    spike --isa=rv64gch_sscofpmf_smaia_ssaia_smcsrind_sscsrind_smcdeleg_ssccfg probe/hv.elf

Expected: `*** FAILED *** (tohost = 31)` (all four writable). Actual: `*** FAILED *** (tohost = 8)`: mvien[13],
hvien[13], mvip[13] and hvip[13] all read 0.

History: riscv-isa-sim PR #1887 (for #1886) deliberately made hvip.LCOFI read-only zero, because Spike did not
implement AIA then, and without AIA that is correct. Spike now implements Smaia/Ssaia, so that reason no longer
applies.

Cause: riscv/csr_init.cc: `mvien = std::make_shared<masked_csr_t>(proc, CSR_MVIEN, MIP_SEIP | MIP_SSIP, 0)` and
`hvien = std::make_shared<aia_csr_t>(proc, CSR_HVIEN, 0, 0)`: neither mask includes MIP_LCOFIP when Smcdeleg and
Sscofpmf are enabled. `mvip_csr_t::unlogged_write` and `hvip_csr_t::unlogged_write` (riscv/csrs.cc) likewise keep
only SEIP/SSIP/STIP and VSEIP/VSTIP/VSSIP.

Passing DUTs: Whisper 6b8cce1, QEMU 11.1.3 (QEMU 11.1.2 fails for the known qemu#3969).

Each directory holds the test source (riscv-arch-test tests_ai framework: boots to S-mode unless noted, M-level CSRs via the T-SBI ecall interface), the ELF, its objdump, the DUT's output and (where small) an instruction trace. A failing check prints `RVCP-SUMMARY: TEST FAILED` with the check's description, the expected and the bad value; a passing run prints no failure. Signalling was double-checked: the same ELFs pass on the DUTs listed as passing below.
