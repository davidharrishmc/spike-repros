# APLIC: interrupt-enable bits, target registers and in_clrip ignore whether a source is active in the domain; root setie/clrie masks are inverted; target writes test the value instead of the index

Spike reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f, riscv-aia 9507866 and riscv-debug-spec 40e5c35; failing on Spike master 37397920 (2026-11-24), on 982f078 (the riscv-arch-test CI pin) and on 020edce.

## What is wrong

Five parts, one ELF each (all RV64 and RV32):

- T-10: setienum sets IE of an inactive source (SM = 0), of a source delegated to the child, and (S domain) of a
  source not delegated to it; IE stays 1 after the source becomes inactive (sourcecfg = 0, leaf D = 1 write,
  undelegation) and is still 1 after re-activation.
- T-11: in the root, sw ~0 to setie[0] does not enable active source 1 but sets IE of delegated source 2 (setie[0]
  reads 0x4); sw ~0 to clrie[0] does not clear IE[1].
- T-12: root target[1] (MSI mode) ignores sw 0x406 (keeps 5); S target[2] ignores sw 3. A target write is accepted only
  if the value written is itself an accessible source number, so no Hart Index > 0, Guest Index or EIID > 1023 can be
  written.
- T-13: target[i] of an inactive or delegated source keeps and accepts values.
- T-16: in_clrip of a source inactive in the S domain returns the raw wire (1) instead of the rectified input (0).

## Correct behavior

AdvPLIC.adoc:516-525: while a source is inactive in a domain, its pending and enable bits and target[i] are read-only
zeros; after re-activation the enable bit remains zero. :793-795 setie sets IE only for active sources; :812 clrie
clears IE; :798-802 setienum is ignored for a source that is not active. :962-969 a target write sets EIID to the low
k bits of the value written (Hart Index and Guest Index WLRL). :549-550 the rectified input of an inactive source is
zero; :753-757 in_clrip returns the rectified inputs.

## How to run

```
./run.sh /path/to/spike
```

Cases:
- rv64 T-10: `u31-aia-b-T-10.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32 T-10: `u31-aia-b-T-10.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)
- rv64 T-11: `u31-aia-b-T-11.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32 T-11: `u31-aia-b-T-11.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)
- rv64 T-12: `u31-aia-b-T-12.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32 T-12: `u31-aia-b-T-12.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)
- rv64 T-13: `u31-aia-b-T-13.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32 T-13: `u31-aia-b-T-13.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)
- rv64 T-16: `u31-aia-b-T-16.spike-rv64-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv64-max/run_cmd.txt`)
- rv32 T-16: `u31-aia-b-T-16.spike-rv32-max.elf` (Spike options from riscv-arch-test `config/spike/spike-rv32-max/run_cmd.txt`)

Files:
- `run.sh`: runs every case on the Spike binary given as argument.
- `u31-aia-b-T-10.spike-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-10.spike-rv32-max.elf` (+ `.objdump`)
- `u31-aia-b-T-11.spike-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-11.spike-rv32-max.elf` (+ `.objdump`)
- `u31-aia-b-T-12.spike-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-12.spike-rv32-max.elf` (+ `.objdump`)
- `u31-aia-b-T-13.spike-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-13.spike-rv32-max.elf` (+ `.objdump`)
- `u31-aia-b-T-16.spike-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-16.spike-rv32-max.elf` (+ `.objdump`)
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the ELF name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Spike master 982f078 (key lines)

```
=== rv64 T-10
SA-MISMATCH: T-10 (a) root: setienum 3 (source 3 inactive): setie[0] bit 3 stays 0 (AdvPLIC.adoc:516-521 :799-802) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T-10 (b) root: setienum 2 (source 2 delegated): setie[0] bit 2 stays 0 (:516-521 :799-802) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T-10 (c1) root: sourcecfg[1] = 0 (inactive): setie[0] bit 1 reads 0 (:516-521) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T-10 (c2) root: sourcecfg[1] = Level1 again: setie[0] bit 1 remains 0 (:521-525) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T-10 (d) S: setienum 2 (source 2 delegated to S, SM Inactive in S): S setie[0] bit 2 stays 0 (:516-521 :799-802) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T-10 (e) S (leaf): sw 0x400 to sourcecfg[2] sets it to 0 (inactive): S setie[0] bit 2 reads 0 (:478-480 :516-521) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T-10 (f) root undelegates source 2: S setie[0] bit 2 reads 0 (source appears not implemented in S) (:138-142 :789-791) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T-10 (g) S setienum 2 for a source not delegated to S is ignored (:138-142 :799-802) expect=0x0000000000000000 got=0x0000000000000001
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-10.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv32 T-10
SA-MISMATCH: T-10 (a) root: setienum 3 (source 3 inactive): setie[0] bit 3 stays 0 (AdvPLIC.adoc:516-521 :799-802) expect=0x00000000 got=0x00000001
SA-MISMATCH: T-10 (b) root: setienum 2 (source 2 delegated): setie[0] bit 2 stays 0 (:516-521 :799-802) expect=0x00000000 got=0x00000001
SA-MISMATCH: T-10 (c1) root: sourcecfg[1] = 0 (inactive): setie[0] bit 1 reads 0 (:516-521) expect=0x00000000 got=0x00000001
SA-MISMATCH: T-10 (c2) root: sourcecfg[1] = Level1 again: setie[0] bit 1 remains 0 (:521-525) expect=0x00000000 got=0x00000001
SA-MISMATCH: T-10 (d) S: setienum 2 (source 2 delegated to S, SM Inactive in S): S setie[0] bit 2 stays 0 (:516-521 :799-802) expect=0x00000000 got=0x00000001
SA-MISMATCH: T-10 (e) S (leaf): sw 0x400 to sourcecfg[2] sets it to 0 (inactive): S setie[0] bit 2 reads 0 (:478-480 :516-521) expect=0x00000000 got=0x00000001
SA-MISMATCH: T-10 (f) root undelegates source 2: S setie[0] bit 2 reads 0 (source appears not implemented in S) (:138-142 :789-791) expect=0x00000000 got=0x00000001
SA-MISMATCH: T-10 (g) S setienum 2 for a source not delegated to S is ignored (:138-142 :799-802) expect=0x00000000 got=0x00000001
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-10.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv64 T-11
SA-MISMATCH: T-11 (a) root setie[0] sw 0xFFFFFFFF sets IE[1] of active source 1 (AdvPLIC.adoc:793-795) expect=0x0000000000000001 got=0x0000000000000000
SA-MISMATCH: T-11 (b) root setie[0] after sw 0xFFFFFFFF = 0x2 (only active source 1) (:793-795 :516-521) expect=0x0000000000000002 got=0x0000000000000004
SA-MISMATCH: T-11 (c) root clrie[0] sw 0xFFFFFFFF clears IE[1] of active source 1 (:812) expect=0x0000000000000000 got=0x0000000000000001
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-11.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv32 T-11
SA-MISMATCH: T-11 (a) root setie[0] sw 0xFFFFFFFF sets IE[1] of active source 1 (AdvPLIC.adoc:793-795) expect=0x00000001 got=0x00000000
SA-MISMATCH: T-11 (b) root setie[0] after sw 0xFFFFFFFF = 0x2 (only active source 1) (:793-795 :516-521) expect=0x00000002 got=0x00000004
SA-MISMATCH: T-11 (c) root clrie[0] sw 0xFFFFFFFF clears IE[1] of active source 1 (:812) expect=0x00000000 got=0x00000001
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-11.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv64 T-12
SA-MISMATCH: T-12 (b) root target[1] after sw 0x406 = EIID 0x406 (k = 11) or 6 (k <= 10); 0x406 shown as 6 (:962-969) expect=0x0000000000000006 got=0x0000000000000005
SA-MISMATCH: T-12 (d) S target[2] after sw 3 = 3 (EIID 3) (:962-969) expect=0x0000000000000003 got=0x0000000000000002
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-12.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
RVCP: END OF DEBUG INFORMATION
exit status 1
=== rv32 T-12
SA-MISMATCH: T-12 (b) root target[1] after sw 0x406 = EIID 0x406 (k = 11) or 6 (k <= 10); 0x406 shown as 6 (:962-969) expect=0x00000006 got=0x00000005
SA-MISMATCH: T-12 (d) S target[2] after sw 3 = 3 (EIID 3) (:962-969) expect=0x00000003 got=0x00000002
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-12.S"
RVCP: DEBUG INFORMATION FOLLOWS
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
```
