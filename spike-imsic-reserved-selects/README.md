# IMSIC: mireg/sireg with *iselect = 0x71 or 0x73-0x7F raise illegal-instruction instead of reading 0

Spike reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f, riscv-aia 9507866 and riscv-debug-spec 40e5c35; failing on Spike master 37397920 (2026-11-24), on 982f078 (the riscv-arch-test CI pin) and on 020edce.

## What is wrong

With miselect (or siselect) = 0x71, 0x73 or 0x7F, every read or write of mireg (sireg) raises an illegal-instruction
exception.

## Correct behavior

AIA IMSIC.adoc:417: "Register numbers 0x71 and 0x73-0x7F are reserved. When an *iselect CSR has one of these values,
reads from the matching *ireg CSR (mireg, sireg, or vsireg) return zero, and writes to the *ireg CSR are ignored."

```
M-mode, M and S files, *iselect = 0x71 / 0x73 / 0x7F: read, write -1, read
  Expected: no trap, reads 0
  Observed: illegal instruction (mcause 2) on every access
Control: *iselect = 0x70 (eidelivery) read: no trap (correct)
```

## How to run

```
./run.sh /path/to/spike
```

Cases:
- rv64: `u30-aia-a-T-07.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32: `u30-aia-a-T-07.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)

Files:
- `run.sh`: runs every case on the Spike binary given as argument.
- `u30-aia-a-T-07.spike-rv64-max.elf` (+ `.objdump`)
- `u30-aia-a-T-07.spike-rv32-max.elf` (+ `.objdump`)
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the ELF name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Spike master 982f078 (key lines)

```
=== rv64
SA-MISMATCH: T-07: M file select 0x71 read: no trap (IMSIC.adoc:417) expect=0x00000000000000ff got=0x0000000000001302
SA-MISMATCH: T-07: M file select 0x71 read returns 0 (IMSIC.adoc:417) expect=0x0000000000000000 got=0xffffffffffffffff
SA-MISMATCH: T-07: M file select 0x71 write -1: no trap (ignored, IMSIC.adoc:417) expect=0x00000000000000ff got=0x0000000000001302
SA-MISMATCH: T-07: M file select 0x71 reads 0 after writing -1 expect=0x0000000000000000 got=0xffffffffffffffff
SA-MISMATCH: T-07: M file select 0x73 read: no trap (IMSIC.adoc:417) expect=0x00000000000000ff got=0x0000000000001302
SA-MISMATCH: T-07: M file select 0x73 read returns 0 (IMSIC.adoc:417) expect=0x0000000000000000 got=0xffffffffffffffff
SA-MISMATCH: T-07: M file select 0x73 write -1: no trap (ignored, IMSIC.adoc:417) expect=0x00000000000000ff got=0x0000000000001302
SA-MISMATCH: T-07: M file select 0x73 reads 0 after writing -1 expect=0x0000000000000000 got=0xffffffffffffffff
SA-MISMATCH: T-07: M file select 0x7F read: no trap (IMSIC.adoc:417) expect=0x00000000000000ff got=0x0000000000001302
SA-MISMATCH: T-07: M file select 0x7F read returns 0 (IMSIC.adoc:417) expect=0x0000000000000000 got=0xffffffffffffffff
SA-MISMATCH: T-07: M file select 0x7F write -1: no trap (ignored, IMSIC.adoc:417) expect=0x00000000000000ff got=0x0000000000001302
SA-MISMATCH: T-07: M file select 0x7F reads 0 after writing -1 expect=0x0000000000000000 got=0xffffffffffffffff
SA-MISMATCH: T-07: S file select 0x71 read: no trap (IMSIC.adoc:417) expect=0x00000000000000ff got=0x0000000000001302
SA-MISMATCH: T-07: S file select 0x71 read returns 0 (IMSIC.adoc:417) expect=0x0000000000000000 got=0xffffffffffffffff
SA-MISMATCH: T-07: S file select 0x71 write -1: no trap (ignored, IMSIC.adoc:417) expect=0x00000000000000ff got=0x0000000000001302
SA-MISMATCH: T-07: S file select 0x71 reads 0 after writing -1 expect=0x0000000000000000 got=0xffffffffffffffff
SA-MISMATCH: T-07: S file select 0x73 read: no trap (IMSIC.adoc:417) expect=0x00000000000000ff got=0x0000000000001302
SA-MISMATCH: T-07: S file select 0x73 read returns 0 (IMSIC.adoc:417) expect=0x0000000000000000 got=0xffffffffffffffff
SA-MISMATCH: T-07: S file select 0x73 write -1: no trap (ignored, IMSIC.adoc:417) expect=0x00000000000000ff got=0x0000000000001302
SA-MISMATCH: T-07: S file select 0x73 reads 0 after writing -1 expect=0x0000000000000000 got=0xffffffffffffffff
SA-MISMATCH: T-07: S file select 0x7F read: no trap (IMSIC.adoc:417) expect=0x00000000000000ff got=0x0000000000001302
SA-MISMATCH: T-07: S file select 0x7F read returns 0 (IMSIC.adoc:417) expect=0x0000000000000000 got=0xffffffffffffffff
SA-MISMATCH: T-07: S file select 0x7F write -1: no trap (ignored, IMSIC.adoc:417) expect=0x00000000000000ff got=0x0000000000001302
SA-MISMATCH: T-07: S file select 0x7F reads 0 after writing -1 expect=0x0000000000000000 got=0xffffffffffffffff
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-07.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv32
SA-MISMATCH: T-07: M file select 0x71 read: no trap (IMSIC.adoc:417) expect=0x000000ff got=0x00001302
SA-MISMATCH: T-07: M file select 0x71 read returns 0 (IMSIC.adoc:417) expect=0x00000000 got=0xffffffff
SA-MISMATCH: T-07: M file select 0x71 write -1: no trap (ignored, IMSIC.adoc:417) expect=0x000000ff got=0x00001302
SA-MISMATCH: T-07: M file select 0x71 reads 0 after writing -1 expect=0x00000000 got=0xffffffff
SA-MISMATCH: T-07: M file select 0x73 read: no trap (IMSIC.adoc:417) expect=0x000000ff got=0x00001302
SA-MISMATCH: T-07: M file select 0x73 read returns 0 (IMSIC.adoc:417) expect=0x00000000 got=0xffffffff
SA-MISMATCH: T-07: M file select 0x73 write -1: no trap (ignored, IMSIC.adoc:417) expect=0x000000ff got=0x00001302
SA-MISMATCH: T-07: M file select 0x73 reads 0 after writing -1 expect=0x00000000 got=0xffffffff
SA-MISMATCH: T-07: M file select 0x7F read: no trap (IMSIC.adoc:417) expect=0x000000ff got=0x00001302
SA-MISMATCH: T-07: M file select 0x7F read returns 0 (IMSIC.adoc:417) expect=0x00000000 got=0xffffffff
SA-MISMATCH: T-07: M file select 0x7F write -1: no trap (ignored, IMSIC.adoc:417) expect=0x000000ff got=0x00001302
SA-MISMATCH: T-07: M file select 0x7F reads 0 after writing -1 expect=0x00000000 got=0xffffffff
SA-MISMATCH: T-07: S file select 0x71 read: no trap (IMSIC.adoc:417) expect=0x000000ff got=0x00001302
SA-MISMATCH: T-07: S file select 0x71 read returns 0 (IMSIC.adoc:417) expect=0x00000000 got=0xffffffff
SA-MISMATCH: T-07: S file select 0x71 write -1: no trap (ignored, IMSIC.adoc:417) expect=0x000000ff got=0x00001302
SA-MISMATCH: T-07: S file select 0x71 reads 0 after writing -1 expect=0x00000000 got=0xffffffff
SA-MISMATCH: T-07: S file select 0x73 read: no trap (IMSIC.adoc:417) expect=0x000000ff got=0x00001302
SA-MISMATCH: T-07: S file select 0x73 read returns 0 (IMSIC.adoc:417) expect=0x00000000 got=0xffffffff
SA-MISMATCH: T-07: S file select 0x73 write -1: no trap (ignored, IMSIC.adoc:417) expect=0x000000ff got=0x00001302
SA-MISMATCH: T-07: S file select 0x73 reads 0 after writing -1 expect=0x00000000 got=0xffffffff
SA-MISMATCH: T-07: S file select 0x7F read: no trap (IMSIC.adoc:417) expect=0x000000ff got=0x00001302
SA-MISMATCH: T-07: S file select 0x7F read returns 0 (IMSIC.adoc:417) expect=0x00000000 got=0xffffffff
SA-MISMATCH: T-07: S file select 0x7F write -1: no trap (ignored, IMSIC.adoc:417) expect=0x000000ff got=0x00001302
SA-MISMATCH: T-07: S file select 0x7F reads 0 after writing -1 expect=0x00000000 got=0xffffffff
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-07.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
```
