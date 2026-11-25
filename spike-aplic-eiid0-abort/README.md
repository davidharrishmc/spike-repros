# APLIC: genmsi with EIID 0, or a forwarded source whose target EIID is 0, aborts Spike

Spike reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f, riscv-aia 9507866 and riscv-debug-spec 40e5c35; failing on Spike master 37397920 (2026-11-24), on 982f078 (the riscv-arch-test CI pin) and on 020edce.

## What is wrong

T-17: in the root domain (MSI mode), sw to genmsi with Hart Index 0 and EIID 0 stops Spike with
`aplic.cc:119: void aplic_t::send_msi(uint32_t, uint32_t, uint32_t): Assertion '(eiid != 0) && (it != procs.end())' failed.`
T-17b: an S-domain Level1 source whose target is still 0 (the reset value) aborts the same way on its first wire edge.

## Correct behavior

EIID is a WARL field that "is able to hold at least values 0 through N" and a target/genmsi write sets its low k bits
(AdvPLIC.adoc:858-873, :962-969), so 0 is a legal EIID; target fields are also UNSPECIFIED after activation
(:521-525). The MSI data is EIID (:1263-1264); an IMSIC ignores a seteipnum write that is not an implemented identity
(IMSIC.adoc:208-209), so an EIID-0 MSI has no effect. Busy returns to 0 once the MSI is sent (:875-877).

```
genmsi = EIID 0 (after a control genmsi = 1 that sets M-file eip[1])
  Expected: no effect, Busy reads 0, simulation continues
  Observed: assertion failure, Spike aborts
```

## How to run

```
./run.sh /path/to/spike
```

Cases:
- rv64 genmsi: `u31-aia-b-T-17.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32 genmsi: `u31-aia-b-T-17.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)
- rv64 target: `u31-aia-b-T-17b.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32 target: `u31-aia-b-T-17b.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)

Files:
- `run.sh`: runs every case on the Spike binary given as argument.
- `u31-aia-b-T-17.spike-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-17.spike-rv32-max.elf` (+ `.objdump`)
- `u31-aia-b-T-17b.spike-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-17b.spike-rv32-max.elf` (+ `.objdump`)
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the ELF name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Spike master 982f078 (key lines)

```
=== rv64 genmsi
SA-SOFT-INFO: T-17: control (a) done; writing genmsi = 0 (hart 0, EIID 0)
spike: ../riscv/aplic.cc:119: void aplic_t::send_msi(uint32_t, uint32_t, uint32_t): Assertion `(eiid != 0) && (it != procs.end())' failed.
exit status 255
=== rv32 genmsi
SA-SOFT-INFO: T-17: control (a) done; writing genmsi = 0 (hart 0, EIID 0)
spike: ../riscv/aplic.cc:119: void aplic_t::send_msi(uint32_t, uint32_t, uint32_t): Assertion `(eiid != 0) && (it != procs.end())' failed.
exit status 255
=== rv64 target
SA-SOFT-INFO: T-17b: setup done; raising the source wire (MSI with EIID 0 follows)
spike: ../riscv/aplic.cc:119: void aplic_t::send_msi(uint32_t, uint32_t, uint32_t): Assertion `(eiid != 0) && (it != procs.end())' failed.
exit status 255
=== rv32 target
SA-SOFT-INFO: T-17b: setup done; raising the source wire (MSI with EIID 0 follows)
spike: ../riscv/aplic.cc:119: void aplic_t::send_msi(uint32_t, uint32_t, uint32_t): Assertion `(eiid != 0) && (it != procs.end())' failed.
exit status 255
```
