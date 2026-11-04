# Spike: a resume request written to a running hart is not ignored ([riscv-isa-sim#2527](https://github.com/riscv-software-src/riscv-isa-sim/issues/2527))

`SPIKE=/path/to/spike ./run.sh` builds `prog.S` (a one-instruction loop) and runs `repro.tcl` in OpenOCD against Spike's remote-bitbang port.

1. Control: halt the hart with haltreq. It stays halted.
2. Resume it normally.
3. While it is running, write `dmcontrol.resumereq`=1. Resume ack is cleared, and the hart keeps running.
4. Halt it with haltreq again.

The Debug spec says the resume request in step 3 is ignored, because the hart was not halted when it was written. So after step 4, `allresumeack` must be 0. Spike resumes the hart as soon as it halts (resume ack goes to 1), and the hart halts again only because haltreq is still set.

Needs `riscv64-unknown-elf-gcc` and OpenOCD (tested with 0.12.0+dev-02355-g74d0cff2f). Output on riscv-isa-sim master 75fb7ef0 (2026-11-02): `expected-output.txt`.
