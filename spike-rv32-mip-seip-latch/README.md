# RV32 with Smaia: csrrs/csrrc of mip and any write of miph copy the external SEIP into the software SEIP (mvip[9])

Spike reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f, riscv-aia 9507866 and riscv-debug-spec 40e5c35; failing on Spike master 37397920 (2026-11-24), on 982f078 (the riscv-arch-test CI pin) and on 020edce.

## What is wrong

RV32, Smaia, mvien[9] = 0, mvip[9] = 0, S-level external interrupt asserted by the S IMSIC file (mip.SEIP reads 1).
(1) `csrs mip, SSIP; csrc mip, SSIP` leaves mvip[9] = 1. (2) `csrw miph, x0` leaves mvip[9] = 1. In both cases
mip.SEIP stays 1 after the IMSIC signal is removed. RV64 is correct for (1) since #2399 (fix for #2360).

## Correct behavior

Only the software-writable SEIP bit takes part in the read-modify-write of mip (machine.adoc:1438-1443). miph
accesses only bits 63:32 of mip (AIA CSRs.adoc:14-15). With mvien[9] = 0, mvip[9] is the software-writable SEIP
(MSLevel.adoc:579-581), so neither instruction may change it.

```
RV32, external SEIP = 1, mvip[9] = 0
  Expected: mvip[9] = 0 after csrs/csrc mip and after csrw miph; mip.SEIP = 0 once the IMSIC signal clears
  Observed: mvip[9] = 1; mip.SEIP stays 1
```

The RV64 ELFs are controls (they pass).

## How to run

```
./run.sh /path/to/spike
```

Cases:
- rv32 csrrs/csrrc mip: `u30-aia-a-T-09.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)
- rv32 csrw miph: `u30-aia-a-spike-06.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)
- rv64 control csrrs/csrrc: `u30-aia-a-T-09.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)

Files:
- `run.sh`: runs every case on the Spike binary given as argument.
- `u30-aia-a-T-09.spike-rv32-max.elf` (+ `.objdump`)
- `u30-aia-a-spike-06.spike-rv32-max.elf` (+ `.objdump`)
- `u30-aia-a-T-09.spike-rv64-max.elf` (+ `.objdump`)
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the ELF name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Spike master 982f078 (key lines)

```
=== rv32 csrrs/csrrc mip
SA-MISMATCH: T-09: csrs/csrc mip.SSIP leaves mvip[9] = 0 (machine.adoc:1438-1443) expect=0x00000000 got=0x00000001
SA-MISMATCH: T-09: external SEIP cleared: mip.SEIP = 0 (no latched software bit) expect=0x00000000 got=0x00000001
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-09.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv32 csrw miph
SA-MISMATCH: W30S-miph: RV32 csrw miph, x0 leaves mvip[9] (software SEIP) = 0 expect=0x00000000 got=0x00000001
SA-MISMATCH: W30S-miph: external SEIP cleared: mip.SEIP = 0 (no latched software bit) expect=0x00000000 got=0x00000001
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-spike-06.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv64 control csrrs/csrrc
RVCP-SUMMARY: TEST PASSED - Test File "u30-aia-a-T-09.S"
exit status 0
```
