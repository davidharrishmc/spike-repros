# Spike Debug Module / DTM / Sdext deviations from the RISC-V Debug Specification

`SPIKE=/path/to/spike ./run.sh` builds `prog.S` and runs Spike seven times. Each run uses a different Spike option set and runs the named session of `repro.tcl`:

| Session | Spike options | Checks |
|---|---|---|
| default | (none) | 1-7, 9, 10 |
| progsize0 | `--dm-progsize=0` | 11 |
| rti | `--dmi-rti=20` | 10 (busy) |
| busy | (none) | 12a-12g: accesses while an abstract command is executing |
| auth | `--dm-auth` | 13 |
| v10 | (none) | 14-18: rules that are new in Debug 1.0 |
| p2 | `-p2` | 19: haltsum0 with 2 harts |

Each time, OpenOCD runs `repro.tcl` against Spike's remote-bitbang port. Each check prints a `RESULT <n>` line with the observed value, the value the spec requires, and BUG or OK.
- Checks 1-13 and 19, except 12g, are required by both ratified versions of the Debug spec: 0.13.2 and 1.0.
- 12a is a control and prints OK. 12c (a `command` write) also prints OK: Spike handles that case.
- 12g and 14-18 test rules that are new in 1.0.
- 12g, 17 and 18 are "should" rules.
- Spike's DM reports `dmstatus.version`=2 (0.13).

Needs `riscv64-unknown-elf-gcc` and OpenOCD (tested with 0.12.0+dev-02355-g74d0cff2f). The whole run takes about 10 seconds.

Output on riscv-isa-sim master 75fb7ef0 (2026-11-02): see `expected-output.txt`.
