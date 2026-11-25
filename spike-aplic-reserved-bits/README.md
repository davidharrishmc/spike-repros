# APLIC: the S-level domain reads 0x80000000 at the mmsiaddrcfgh offset, and sourcecfg stores reserved bits

Spike reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f, riscv-aia 9507866 and riscv-debug-spec 40e5c35; failing on Spike master 37397920 (2026-11-24), on 982f078 (the riscv-arch-test CI pin) and on 020edce.

## What is wrong

T-08: in the supervisor-level domain (0x0D000000), offset 0x1BC4 (mmsiaddrcfgh) reads 0x80000000, also after
sw 0xFFFFFFFF. T-09: root sourcecfg[1] stores and returns every reserved bit (sw 0xFFFFFBF9 reads 0xFFFFFBFE; with
D = 1, bits 31:11 read back as written).

## Correct behavior

AdvPLIC.adoc:559-562: mmsiaddrcfg/mmsiaddrcfgh are never implemented for domains not at machine level, and their
eight bytes are read-only zeros. :466-470 and :488-491: in both sourcecfg formats "All other register bits are reserved
and read as zeros."

```
S domain 0x1BC4: Expected 0, Observed 0x80000000
root sourcecfg[1] after sw 0xFFFFFBF9: Expected 0x00000006 (SM legalised, reserved bits 0), Observed 0xFFFFFBFE
```

## How to run

```
./run.sh /path/to/spike
```

Cases:
- rv64 T-08: `u31-aia-b-T-08.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32 T-08: `u31-aia-b-T-08.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)
- rv64 T-09: `u31-aia-b-T-09.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32 T-09: `u31-aia-b-T-09.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)

Files:
- `run.sh`: runs every case on the Spike binary given as argument.
- `u31-aia-b-T-08.spike-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-08.spike-rv32-max.elf` (+ `.objdump`)
- `u31-aia-b-T-09.spike-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-09.spike-rv32-max.elf` (+ `.objdump`)
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the ELF name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Spike master 982f078 (key lines)

```
=== rv64 T-08
SA-MISMATCH: T-08 (a) S domain offset 0x1BC4 (mmsiaddrcfgh location) reads 0 (AdvPLIC.adoc:559-562) expect=0x0000000000000000 got=0x0000000080000000
SA-MISMATCH: T-08 (b) S domain 0x1BC4 reads 0 after sw 0xFFFFFFFF (:559-562 :358-362) expect=0x0000000000000000 got=0x0000000080000000
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-08.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv32 T-08
SA-MISMATCH: T-08 (a) S domain offset 0x1BC4 (mmsiaddrcfgh location) reads 0 (AdvPLIC.adoc:559-562) expect=0x00000000 got=0x80000000
SA-MISMATCH: T-08 (b) S domain 0x1BC4 reads 0 after sw 0xFFFFFFFF (:559-562 :358-362) expect=0x00000000 got=0x80000000
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-08.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv64 T-09
SA-MISMATCH: T-09 (a) sourcecfg[1] after sw 0xFFFFFBF9 (D=0): bits 31:3 read 0 (AdvPLIC.adoc:482-491) expect=0x0000000000000000 got=0x000000001fffff7f
SA-MISMATCH: T-09 (b) sourcecfg[1] after sw 0xFFFFFBFE (D=0, SM=6): bits 31:3 read 0 (:482-491) expect=0x0000000000000000 got=0x000000001fffff7f
SA-MISMATCH: T-09 (c) sourcecfg[1] after sw 0x3F8 (D=0, SM=0): bits 31:3 read 0 (:482-491) expect=0x0000000000000000 got=0x000000000000007f
SA-MISMATCH: T-09 (d) sourcecfg[1] after sw 0xFFFFFFFF (D=1): bits 31:11 read 0 (:462-470) expect=0x0000000000000000 got=0x00000000001fffff
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-09.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv32 T-09
SA-MISMATCH: T-09 (a) sourcecfg[1] after sw 0xFFFFFBF9 (D=0): bits 31:3 read 0 (AdvPLIC.adoc:482-491) expect=0x00000000 got=0x1fffff7f
SA-MISMATCH: T-09 (b) sourcecfg[1] after sw 0xFFFFFBFE (D=0, SM=6): bits 31:3 read 0 (:482-491) expect=0x00000000 got=0x1fffff7f
SA-MISMATCH: T-09 (c) sourcecfg[1] after sw 0x3F8 (D=0, SM=0): bits 31:3 read 0 (:482-491) expect=0x00000000 got=0x0000007f
SA-MISMATCH: T-09 (d) sourcecfg[1] after sw 0xFFFFFFFF (D=1): bits 31:11 read 0 (:462-470) expect=0x00000000 got=0x001fffff
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-09.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
```
