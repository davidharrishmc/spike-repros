# AMOs to IMSIC and APLIC registers are performed as a load plus a store

Spike reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f, riscv-aia 9507866 and riscv-debug-spec 40e5c35; failing on Spike master 37397920 (2026-11-24), on 982f078 (the riscv-arch-test CI pin) and on 020edce.

## What is wrong

`amoor.w` / `amoswap.w` of 7 to the M-level IMSIC interrupt file's seteipnum_le completes without a trap and sets
eip0 bit 7. `amoor.w 0x100` to the APLIC root domain's domaincfg (IE = 0) completes and sets domaincfg.IE.

## Correct behavior

AIA IMSIC.adoc:202-206 and AdvPLIC.adoc:364-368: only naturally aligned 32-bit simple reads and writes are supported;
"For other forms of accesses (other sizes, misaligned accesses, or AMOs), [an implementation] should preferably report
an access fault or bus error but must otherwise ignore the access." Legal outcomes: store/AMO access fault (cause 7),
or no trap with the register unchanged.

```
amoor.w 7 / amoswap.w 7 to IMSIC M-file seteipnum_le
  Expected: cause 7, or no trap and eip0 bit 7 = 0
  Observed: no trap, eip0 bit 7 = 1
amoor.w 0x100 to APLIC M-domain domaincfg (IE = 0)
  Expected: cause 7, or no trap and IE = 0
  Observed: no trap, IE = 1
Controls: sw to seteipnum_le sets the bit; sw to domaincfg clears IE (correct)
```

## How to run

```
./run.sh /path/to/spike
```

Cases:
- rv64 IMSIC: `u30-aia-a-T-06.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32 IMSIC: `u30-aia-a-T-06.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)
- rv64 APLIC: `u31-aia-b-T-01.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32 APLIC: `u31-aia-b-T-01.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)

Files:
- `run.sh`: runs every case on the Spike binary given as argument.
- `u30-aia-a-T-06.spike-rv64-max.elf` (+ `.objdump`)
- `u30-aia-a-T-06.spike-rv32-max.elf` (+ `.objdump`)
- `u31-aia-b-T-01.spike-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-01.spike-rv32-max.elf` (+ `.objdump`)
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the ELF name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Spike master 982f078 (key lines)

```
=== rv64 IMSIC
SA-MISMATCH: T-06: amoor.w 7 to seteipnum_le does not set eip0 bit 7 (IMSIC.adoc:202-206 must ignore) expect=0x0000000000000000 got=0x0000000000000080
SA-MISMATCH: T-06: amoswap.w 7 to seteipnum_le does not set eip0 bit 7 (IMSIC.adoc:202-206 must ignore) expect=0x0000000000000000 got=0x0000000000000080
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-06.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv32 IMSIC
SA-MISMATCH: T-06: amoor.w 7 to seteipnum_le does not set eip0 bit 7 (IMSIC.adoc:202-206 must ignore) expect=0x00000000 got=0x00000080
SA-MISMATCH: T-06: amoswap.w 7 to seteipnum_le does not set eip0 bit 7 (IMSIC.adoc:202-206 must ignore) expect=0x00000000 got=0x00000080
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-06.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv64 APLIC
SA-MISMATCH: T01: amoor.w 0x100 to domaincfg must not set IE (AdvPLIC.adoc:364-368: fault or ignore) expect=0x0000000000000000 got=0x0000000000000001
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-01.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv32 APLIC
SA-MISMATCH: T01: amoor.w 0x100 to domaincfg must not set IE (AdvPLIC.adoc:364-368: fault or ignore) expect=0x00000000 got=0x00000001
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-01.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
```
