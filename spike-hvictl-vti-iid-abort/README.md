# hvictl.VTI = 1 with IID = 0, 4 or 8 aborts Spike (assertion in select_an_interrupt_with_default_priority)

Spike reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f, riscv-aia 9507866 and riscv-debug-spec 40e5c35; failing on Spike master 37397920 (2026-11-24), on 982f078 (the riscv-arch-test CI pin) and on 020edce.

## What is wrong

In VS-mode with vsstatus.SIE = 1 and hvictl = VTI | IID 4 | IPRIOM | IPRIO 5 (vstopi correctly reads 0x40005), Spike
stops with `processor.cc:293: ... select_an_interrupt_with_default_priority(reg_t) const: Assertion '0' failed.`
IID = 0 (with IPRIO 5, so vstopi is nonzero) and IID = 8 abort the same way.

## Correct behavior

IID is WARL with at least 6 bits and all 2^k values are supported (AIA VSLevel.adoc:411-415); when vstopi is nonzero
and VS-mode has SIE = 1, the hart takes a trap to VS-mode for the interrupt in vstopi.IID (VSLevel.adoc:509-511).

```
VS-mode, vsstatus.SIE = 1, hvictl.VTI = 1, IID = 4
  Expected: trap to VS-mode, vscause = Interrupt | 4
  Observed: Spike aborts (assertion)
Control: IID = 3: trap to VS-mode, vscause = Interrupt | 3 (correct)
```

## How to run

```
./run.sh /path/to/spike
```

Cases:
- rv64: `u30-aia-a-spike-04.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32: `u30-aia-a-spike-04.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)

Files:
- `run.sh`: runs every case on the Spike binary given as argument.
- `u30-aia-a-spike-04.spike-rv64-max.elf` (+ `.objdump`)
- `u30-aia-a-spike-04.spike-rv32-max.elf` (+ `.objdump`)
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the ELF name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Spike master 982f078 (key lines)

```
=== rv64
spike: ../riscv/processor.cc:293: reg_t processor_t::select_an_interrupt_with_default_priority(reg_t) const: Assertion `0' failed.
exit status 255
=== rv32
spike: ../riscv/processor.cc:293: reg_t processor_t::select_an_interrupt_with_default_priority(reg_t) const: Assertion `0' failed.
exit status 255
```
