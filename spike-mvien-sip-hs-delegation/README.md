# An M-level interrupt is taken in HS-mode when mvien/mvip make the same bit pending in sip

Spike reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f, riscv-aia 9507866 and riscv-debug-spec 40e5c35; failing on Spike master 37397920 (2026-11-24), on 982f078 (the riscv-arch-test CI pin) and on 020edce.

## What is wrong

In HS-mode with mideleg[1] = 0, mip.SSIP = mie.SSIE = 1 (an M-level supervisor software interrupt), and
mvien[1] = mvip[1] = 1 (so sip[1] = 1 as the S-level virtual SSI; sie[1] = 0), Spike takes the interrupt in HS-mode
(scause = Interrupt | 1). The M-level interrupt stays pending, so the hart re-enters the HS handler forever (the test
sets menvcfg.DTE = 1 so the second entry ends as a double trap, mcause 16).

## Correct behavior

The interrupt is pending and enabled at M level and not delegated, so it traps to M-mode (machine.adoc:1343-1348);
traps to a more-privileged mode take priority (AIA MSLevel.adoc:65-68). With mvien[1] = 1, mvip[1] is a separate
bit independent of mip.SSIP (MSLevel.adoc:572-573) and cannot change where the M-level interrupt goes.

```
HS-mode, mideleg[1] = 0, mip.SSIP = mie.SSIE = 1, mvien[1] = mvip[1] = 1, sie[1] = 0
  Expected: trap to M, mcause = Interrupt | 1
  Observed: trap to HS, scause = Interrupt | 1, repeated (ends as mcause 16 with DTE = 1)
```

## How to run

```
./run.sh /path/to/spike
```

Cases:
- rv64: `u30-aia-a-spike-05.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32: `u30-aia-a-spike-05.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)

Files:
- `run.sh`: runs every case on the Spike binary given as argument.
- `u30-aia-a-spike-05.spike-rv64-max.elf` (+ `.objdump`)
- `u30-aia-a-spike-05.spike-rv32-max.elf` (+ `.objdump`)
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the ELF name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Spike master 982f078 (key lines)

```
=== rv64
SA-MISMATCH: HS, M-level SSI pending+enabled (mideleg[1]=0), sip[1]=mvip[1]=1: mcause (16 = taken to HS first, then double trap) expect=0x8000000000000001 got=0x0000000000000010
SA-MISMATCH: HS, M-level SSI: scause untouched (Interrupt|1 = trap was taken in HS) expect=0x0000000000000000 got=0x8000000000000001
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-spike-05.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv32
SA-MISMATCH: HS, M-level SSI pending+enabled (mideleg[1]=0), sip[1]=mvip[1]=1: mcause (16 = taken to HS first, then double trap) expect=0x80000001 got=0x00000010
SA-MISMATCH: HS, M-level SSI: scause untouched (Interrupt|1 = trap was taken in HS) expect=0x00000000 got=0x80000001
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-spike-05.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
```
