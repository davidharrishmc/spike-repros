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

## Issues

- [riscv-isa-sim#2511](https://github.com/riscv-software-src/riscv-isa-sim/issues/2511): Debug Module: dmcontrol.haltreq reads back the value written
- [riscv-isa-sim#2512](https://github.com/riscv-software-src/riscv-isa-sim/issues/2512): Debug Module: unimplemented DM registers return a failed DMI op instead of 0
- [riscv-isa-sim#2513](https://github.com/riscv-software-src/riscv-isa-sim/issues/2513): Debug Module: dmactive=0 does not reset data, progbuf or System Bus registers
- [riscv-isa-sim#2514](https://github.com/riscv-software-src/riscv-isa-sim/issues/2514): Debug Module: sbaddress/sbdata registers are present when System Bus Access is not implemented
- [riscv-isa-sim#2515](https://github.com/riscv-software-src/riscv-isa-sim/issues/2515): Debug Module: Access Register with transfer=0 fails on aarsize
- [riscv-isa-sim#2516](https://github.com/riscv-software-src/riscv-isa-sim/issues/2516): Debug Module: Access Register accepts aarpostincrement and postexec when they are not supported
- [riscv-isa-sim#2517](https://github.com/riscv-software-src/riscv-isa-sim/issues/2517): Sdext: interrupts are taken during single step although dcsr.stepie is hard-wired to 0
- [riscv-isa-sim#2518](https://github.com/riscv-software-src/riscv-isa-sim/issues/2518): JTAG DTM: BYPASS captures the last bit shifted in, and unimplemented IR values don't select BYPASS
- [riscv-isa-sim#2519](https://github.com/riscv-software-src/riscv-isa-sim/issues/2519): JTAG DTM: failed DMI status is not sticky, and dtmcs.dmistat always reads 0
- [riscv-isa-sim#2520](https://github.com/riscv-software-src/riscv-isa-sim/issues/2520): Debug Module: accessing abstractcs, abstractauto or progbuf while an abstract command is busy does not set cmderr
- [riscv-isa-sim#2521](https://github.com/riscv-software-src/riscv-isa-sim/issues/2521): Debug Module: with --dm-auth, an unauthenticated DM exposes hart state
- [riscv-isa-sim#2522](https://github.com/riscv-software-src/riscv-isa-sim/issues/2522): Debug Module (Debug 1.0): Access Register with bit 23 set is not rejected
- [riscv-isa-sim#2523](https://github.com/riscv-software-src/riscv-isa-sim/issues/2523): Debug Module (Debug 1.0): abstractauto bits for data/progbuf registers that don't exist are writable
- [riscv-isa-sim#2524](https://github.com/riscv-software-src/riscv-isa-sim/issues/2524): Sdext: dcsr.prv (WARL in Debug 1.0) stores the reserved encoding 2
- [riscv-isa-sim#2525](https://github.com/riscv-software-src/riscv-isa-sim/issues/2525): Debug Module: haltsum0 is not implemented (reads fail with op 2)
- [riscv-debug-spec#1230](https://github.com/riscv/riscv-debug-spec/issues/1230): Security: "should not implement" authdata when it can't unlock the DM, is that a must?
