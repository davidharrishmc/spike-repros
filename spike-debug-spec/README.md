# Spike Debug Module / DTM / Sdext deviations from the RISC-V Debug Specification

One reproducer for several riscv-isa-sim issues. Each issue has its own check in `repro.tcl`, and `run.sh` can run one issue's checks alone:

```
SPIKE=/path/to/spike ./run.sh 2512     # only the checks for riscv-isa-sim#2512
SPIKE=/path/to/spike ./run.sh          # every check
```

`run.sh` builds `prog.S`, starts Spike with the options the check needs, and runs `repro.tcl` in OpenOCD against Spike's remote-bitbang port. Each check prints a `RESULT <n>` line with the observed value, the value the spec requires, and BUG or OK. A single issue takes a few seconds; the whole run takes about 10 seconds.

Needs `riscv64-unknown-elf-gcc` and OpenOCD (tested with 0.12.0+dev-02355-g74d0cff2f). The output on riscv-isa-sim master 75fb7ef0 (2026-11-02) is in `expected-output.txt`.

| Issue | Command | Check in `repro.tcl` | Spike session |
|---|---|---|---|
| [riscv-isa-sim#2511](https://github.com/riscv-software-src/riscv-isa-sim/issues/2511): dmcontrol.haltreq reads back the value written | `./run.sh 2511` | 1 ([line 70](repro.tcl#L70)) | default |
| [riscv-isa-sim#2512](https://github.com/riscv-software-src/riscv-isa-sim/issues/2512): unimplemented DM registers return a failed DMI op instead of 0 | `./run.sh 2512` | 2 ([line 77](repro.tcl#L77)) | default |
| [riscv-isa-sim#2513](https://github.com/riscv-software-src/riscv-isa-sim/issues/2513): dmactive=0 does not reset data, progbuf or System Bus registers | `./run.sh 2513` | 3 ([line 114](repro.tcl#L114)) | default |
| [riscv-isa-sim#2514](https://github.com/riscv-software-src/riscv-isa-sim/issues/2514): sbaddress/sbdata registers are present when System Bus Access is not implemented | `./run.sh 2514` | 4 ([line 123](repro.tcl#L123)) | default |
| [riscv-isa-sim#2515](https://github.com/riscv-software-src/riscv-isa-sim/issues/2515): Access Register with transfer=0 fails on aarsize | `./run.sh 2515` | 5 ([line 139](repro.tcl#L139)) | default |
| [riscv-isa-sim#2516](https://github.com/riscv-software-src/riscv-isa-sim/issues/2516): Access Register accepts aarpostincrement and postexec when they are not supported | `./run.sh 2516` | 6, 11 ([line 149](repro.tcl#L149)) | default; progsize0 (`--dm-progsize=0`, check 11 at line 353) |
| [riscv-isa-sim#2517](https://github.com/riscv-software-src/riscv-isa-sim/issues/2517): interrupts are taken during single step although dcsr.stepie is hard-wired to 0 | `./run.sh 2517` | 7 ([line 162](repro.tcl#L162)) | default |
| [riscv-isa-sim#2518](https://github.com/riscv-software-src/riscv-isa-sim/issues/2518): BYPASS captures the last bit shifted in, and unimplemented IR values don't select BYPASS | `./run.sh 2518` | 9 ([line 182](repro.tcl#L182)) | default |
| [riscv-isa-sim#2519](https://github.com/riscv-software-src/riscv-isa-sim/issues/2519): failed DMI status is not sticky, and dtmcs.dmistat always reads 0 | `./run.sh 2519` | 10 ([line 195](repro.tcl#L195)) | default; rti (`--dmi-rti=20`, line 335) |
| [riscv-isa-sim#2520](https://github.com/riscv-software-src/riscv-isa-sim/issues/2520): accessing abstractcs, abstractauto or progbuf while an abstract command is busy does not set cmderr | `./run.sh 2520` | 12a-12f ([line 216](repro.tcl#L216)) | busy |
| [riscv-isa-sim#2521](https://github.com/riscv-software-src/riscv-isa-sim/issues/2521): with --dm-auth, an unauthenticated DM exposes hart state | `./run.sh 2521` | 13 ([line 264](repro.tcl#L264)) | auth (`--dm-auth`) |
| [riscv-isa-sim#2522](https://github.com/riscv-software-src/riscv-isa-sim/issues/2522): (Debug 1.0) Access Register with bit 23 set is not rejected | `./run.sh 2522` | 14 ([line 280](repro.tcl#L280)) | v10 |
| [riscv-isa-sim#2523](https://github.com/riscv-software-src/riscv-isa-sim/issues/2523): (Debug 1.0) abstractauto bits for data/progbuf registers that don't exist are writable | `./run.sh 2523` | 15 ([line 284](repro.tcl#L284)) | v10 |
| [riscv-isa-sim#2524](https://github.com/riscv-software-src/riscv-isa-sim/issues/2524): dcsr.prv (WARL in Debug 1.0) stores the reserved encoding 2 | `./run.sh 2524` | 16 ([line 294](repro.tcl#L294)) | v10 |
| [riscv-isa-sim#2525](https://github.com/riscv-software-src/riscv-isa-sim/issues/2525): haltsum0 is not implemented (reads fail with op 2) | `./run.sh 2525` | 19 ([line 316](repro.tcl#L316)) | p2 (`-p2`) |

Notes:
- Checks 1-13 and 19 are required by both ratified versions of the Debug spec, 0.13.2 and 1.0. Checks 14-16 test rules that are new in 1.0 (Spike's DM reports `dmstatus.version`=2, 0.13); those issues say so.
- 12a is a control and prints OK. 12c (a `command` write while busy) also prints OK: Spike handles that case.
- Checks 12g, 17 and 18 are "should" rules and are not filed as Spike bugs. Check 18 is the subject of [riscv-debug-spec#1230](https://github.com/riscv/riscv-debug-spec/issues/1230) (Security: "should not implement" authdata when it can't unlock the DM, is that a must?). Run them with `./run.sh 12g`, `./run.sh 17` or `./run.sh 18`.
- `./run.sh <issue>` still runs every check of that issue's session, in order on one Spike instance, but prints only that issue's lines.
