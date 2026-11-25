# RV32: VS/VU-mode access to midelegh raises virtual-instruction instead of illegal-instruction when hstateen0.AIA = 0

Spike reproducer, 2026-11-25. Checked against riscv-isa-manual 3142f66f and riscv-aia 9507866; failing on Spike master 37397920 (2026-11-24) and on 982f078 (the riscv-arch-test CI pin).

## What is wrong

On RV32 with H, Smaia/Ssaia and Smstateen, with mstateen0.AIA = 1 and hstateen0.AIA = 0, a read or write of the
machine-level CSR midelegh (0x313) from VS-mode or VU-mode raises a virtual-instruction exception (cause 22).

## Correct behavior

midelegh is a machine-level CSR, so the access raises an illegal-instruction exception (cause 2), whatever hstateen0
holds.

- Privileged spec, hypervisor.adoc:2329-2337: "When V=1, a virtual-instruction exception (code 22) is normally raised
  instead of an illegal-instruction exception if the attempted instruction is _HS-qualified_ [...] An instruction is
  _HS-qualified_ if it would be valid to execute in HS-mode (for some values of the instruction's register operands),
  assuming fields TSR and TVM of CSR `mstatus` are both zero."
- hypervisor.adoc:2339-2346: "When V=1 and XLEN=32, an invalid attempt to access a high-half CSR raises a
  virtual-instruction exception instead of an illegal-instruction exception if the same CSR instruction for the
  corresponding _low-half_ CSR (e.g. `cycle` or `htimedelta`) is HS-qualified." `csrr mideleg` is not valid in HS-mode.
- AIA CSRs.adoc:425-435: the `hstateen0` bits "concern only the state potentially accessible to a virtual machine
  executing in privilege modes VS and VU"; "bit 59 AIA: CSRs `siph` and `sieh` (RV32 only) and `stopi` (really `vsiph`,
  `vsieh`, and `vstopi`)"; "If one of these bits is zero in `hstateen0`, and the same bit is one in `mstateen0`, then an
  attempt to access the corresponding state from VS or VU-mode raises a virtual instruction exception."

```
RV32, mstateen0.AIA = 1, hstateen0.AIA = 0
  VS csrr midelegh, VU csrr midelegh, VS csrw midelegh, VU csrw midelegh
    Expected: illegal instruction (mcause 2)
    Observed: virtual instruction (mcause 22)
Controls (all correct on Spike):
  hstateen0.AIA = 1: VS and VU csrr midelegh: 2
  hstateen0.AIA = 0: VS and VU csrr mideleg: 2; VS csrr mieh, miph, mvienh, mviph, medelegh: 2;
                     HS and U csrr midelegh: 2; VS csrr sieh (really vsieh): 22; M-mode csrr midelegh: no trap
```

## How to run

```
./run.sh /path/to/spike
```

Cases:
- rv32: `rv32-midelegh-virt.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)

Files:
- `run.sh`: runs the case on the Spike binary given as argument.
- `rv32-midelegh-virt.spike-rv32-max.elf` (+ `.objdump`, from `riscv64-unknown-elf-objdump -d`)
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the ELF name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Spike master 37397920 (982f078 prints the same)

```
=== rv32
SA-MISMATCH: hstateen0.AIA = 0, VS csrr midelegh: illegal instruction (2), not virtual instruction (22) expect=0x00000002 got=0x00000016
SA-MISMATCH: hstateen0.AIA = 0, VU csrr midelegh: illegal instruction (2), not virtual instruction (22) expect=0x00000002 got=0x00000016
SA-MISMATCH: hstateen0.AIA = 0, VS csrw midelegh: illegal instruction (2), not virtual instruction (22) expect=0x00000002 got=0x00000016
SA-MISMATCH: hstateen0.AIA = 0, VU csrw midelegh: illegal instruction (2), not virtual instruction (22) expect=0x00000002 got=0x00000016

RVCP-SUMMARY: TEST FAILED - Test File "rv32-midelegh-virt.S"

RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: Instruction: 0x00620863
RVCP: Approximate address (failure may be slightly after this): 0x80001b70
RVCP: Register: x6
RVCP: Bad Value:      0x00000004
RVCP: Expected value unavailable: reconstructed signature load is not LREG. Raw instruction: 0x00000213
RVCP: END OF DEBUG INFORMATION

*** FAILED *** (tohost = 1)
exit status 1
```
