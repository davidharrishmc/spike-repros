# APLIC in MSI mode keeps no pending bits: an interrupt that arrives while IE or domaincfg.IE is 0 is lost

Spike reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f, riscv-aia 9507866 and riscv-debug-spec 40e5c35; failing on Spike master 37397920 (2026-11-24), on 982f078 (the riscv-arch-test CI pin) and on 020edce.

## What is wrong

S-domain source 1, Level1, MSI delivery mode, wire (UART THR-empty) held high. (a) With IE[1] = 0 the rising edge
leaves setip bit 1 = 0, and a later setienum 1 sends no MSI. (b) With IE[1] = 1 and domaincfg.IE = 0 the edge leaves
IP = 0, and setting domaincfg.IE = 1 sends no MSI.

## Correct behavior

AdvPLIC.adoc:1013-1020: in MSI mode the pending bit of a Level source is set by a low-to-high transition of the
rectified input and cleared only when the input is low, when the interrupt is forwarded, or by in_clrip/clripnum.
:1201-1203: an MSI is sent when the pending bit, the enable bit and domaincfg.IE are all one. :392-399: domaincfg.IE
does not affect the pending bits. So enabling the source (or the domain) later must send the MSI.

```
(a) edge with IE[1] = 0; then setienum 1
  Expected: setip bit 1 = 1; MSI sent after setienum (S-file eip[1] = 1)
  Observed: setip bit 1 = 0; no MSI
(b) edge with domaincfg.IE = 0; then domaincfg.IE = 1
  Expected: IP = 1; MSI sent after IE = 1
  Observed: IP = 0; no MSI
```

## How to run

```
./run.sh /path/to/spike
```

Cases:
- rv64: `u31-aia-b-T-15.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32: `u31-aia-b-T-15.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)

Files:
- `run.sh`: runs every case on the Spike binary given as argument.
- `u31-aia-b-T-15.spike-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-15.spike-rv32-max.elf` (+ `.objdump`)
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the ELF name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Spike master 982f078 (key lines)

```
=== rv64
SA-MISMATCH: T-15 (a1) wire high with IE[1] = 0: setip[0] bit 1 (IP) = 1 (AdvPLIC.adoc:1013-1020 :730-732) expect=0x0000000000000001 got=0x0000000000000000
SA-MISMATCH: T-15 (a3) setienum 1 with IP[1] = 1 sends the MSI: S-file eip[1] = 1 (:1201-1203, aia#153) expect=0x0000000000000001 got=0x0000000000000000
SA-MISMATCH: T-15 (b2) wire high with domaincfg.IE = 0: IP[1] = 1 (:396-399 :1013-1020) expect=0x0000000000000001 got=0x0000000000000000
SA-MISMATCH: T-15 (b3) domaincfg.IE = 1 forwards the pending source: S-file eip[1] = 1 (:392-394 :1201-1203) expect=0x0000000000000001 got=0x0000000000000000
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-15.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv32
SA-MISMATCH: T-15 (a1) wire high with IE[1] = 0: setip[0] bit 1 (IP) = 1 (AdvPLIC.adoc:1013-1020 :730-732) expect=0x00000001 got=0x00000000
SA-MISMATCH: T-15 (a3) setienum 1 with IP[1] = 1 sends the MSI: S-file eip[1] = 1 (:1201-1203, aia#153) expect=0x00000001 got=0x00000000
SA-MISMATCH: T-15 (b2) wire high with domaincfg.IE = 0: IP[1] = 1 (:396-399 :1013-1020) expect=0x00000001 got=0x00000000
SA-MISMATCH: T-15 (b3) domaincfg.IE = 1 forwards the pending source: S-file eip[1] = 1 (:392-394 :1201-1203) expect=0x00000001 got=0x00000000
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-15.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
```
