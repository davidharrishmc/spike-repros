# hvictl.VTI = 1 with IID = n sends any trap with cause n to VS-mode, including exceptions raised in M-mode and HS-mode

Spike reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f, riscv-aia 9507866 and riscv-debug-spec 40e5c35; failing on Spike master 37397920 (2026-11-24), on 982f078 (the riscv-arch-test CI pin) and on 020edce.

## What is wrong

With hvictl = VTI | IID 2 (vstopi reads IID 2), an illegal instruction executed in M-mode, in HS-mode with medeleg = 0,
or in VS-mode with medeleg = 0 traps to VS-mode (vscause = 2). It should trap to M-mode (mcause = 2). With IID = 3 the
same illegal instruction traps to M correctly.

## Correct behavior

hvictl affects only vstopi and some VS-mode CSR accesses (AIA VSLevel.adoc:433-434). Exceptions are delegated only by
medeleg/hedeleg (hypervisor.adoc:361-363), and traps never move to a less-privileged mode (machine.adoc:1278).

```
illegal instruction in M, HS (medeleg = 0) and VS (medeleg = 0), hvictl.VTI = 1, IID = 2
  Expected: trap to M, mcause 2
  Observed: trap to VS, vscause 2 (from M-mode too)
Control: same with IID = 3: trap to M, mcause 2 (correct)
```

## How to run

```
./run.sh /path/to/spike
```

Cases:
- rv64: `u30-aia-a-spike-01.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32: `u30-aia-a-spike-01.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)

Files:
- `run.sh`: runs every case on the Spike binary given as argument.
- `u30-aia-a-spike-01.spike-rv64-max.elf` (+ `.objdump`)
- `u30-aia-a-spike-01.spike-rv32-max.elf` (+ `.objdump`)
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the ELF name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Spike master 982f078 (key lines)

```
=== rv64
SA-MISMATCH: (a) M-mode illegal insn, VTI=1 IID=2: number of traps into VS (must be 0) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: (a) M-mode illegal insn, VTI=1 IID=2: mcause (2; 10 = came back from a VS handler) expect=0x0000000000000002 got=0x000000000000000a
SA-MISMATCH: (a) VS handler vscause record (-1 = VS handler never ran) expect=0xffffffffffffffff got=0x0000000000000002
SA-MISMATCH: (b) HS-mode illegal insn, VTI=1 IID=2: number of traps into VS (must be 0) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: (b) HS-mode illegal insn, VTI=1 IID=2: mcause (2; 10 = came back from a VS handler) expect=0x0000000000000002 got=0x000000000000000a
SA-MISMATCH: (b) VS handler vscause record (-1 = VS handler never ran) expect=0xffffffffffffffff got=0x0000000000000002
SA-MISMATCH: (d) VS-mode illegal insn, medeleg=0, VTI=1 IID=2: number of traps into VS (must be 0) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: (d) VS-mode illegal insn, medeleg=0, VTI=1 IID=2: mcause (2; 10 = came back from a VS handler) expect=0x0000000000000002 got=0x000000000000000a
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-spike-01.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv32
SA-MISMATCH: (a) M-mode illegal insn, VTI=1 IID=2: number of traps into VS (must be 0) expect=0x00000000 got=0x00000001
SA-MISMATCH: (a) M-mode illegal insn, VTI=1 IID=2: mcause (2; 10 = came back from a VS handler) expect=0x00000002 got=0x0000000a
SA-MISMATCH: (a) VS handler vscause record (-1 = VS handler never ran) expect=0xffffffff got=0x00000002
SA-MISMATCH: (b) HS-mode illegal insn, VTI=1 IID=2: number of traps into VS (must be 0) expect=0x00000000 got=0x00000001
SA-MISMATCH: (b) HS-mode illegal insn, VTI=1 IID=2: mcause (2; 10 = came back from a VS handler) expect=0x00000002 got=0x0000000a
SA-MISMATCH: (b) VS handler vscause record (-1 = VS handler never ran) expect=0xffffffff got=0x00000002
SA-MISMATCH: (d) VS-mode illegal insn, medeleg=0, VTI=1 IID=2: number of traps into VS (must be 0) expect=0x00000000 got=0x00000001
SA-MISMATCH: (d) VS-mode illegal insn, medeleg=0, VTI=1 IID=2: mcause (2; 10 = came back from a VS handler) expect=0x00000002 got=0x0000000a
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-spike-01.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
```
