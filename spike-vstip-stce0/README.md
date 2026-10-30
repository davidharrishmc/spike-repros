# Spike: hip.VSTIP keeps a stale vstimecmp comparison after henvcfg.STCE or menvcfg.STCE is cleared

With Sstc, hip.VSTIP is hvip.VSTIP OR the vstimecmp comparison (time + htimedelta >= vstimecmp), but the
comparison counts only while henvcfg.STCE = 1 (henvcfg.STCE is read-only 0 while menvcfg.STCE = 0). The Sstc
spec says that when henvcfg.STCE is 0, "VSTIP in hip reverts to its defined behavior as if this extension is not
implemented", which is hvip.VSTIP alone.

Spike keeps the comparison in mip's own VSTIP bit and ORs hvip in when mip and hip are read.
`time_counter_csr_t::sync` (riscv/csrs.cc) writes that bit only while henvcfg.STCE = 1. Once STCE is cleared,
the last comparison result stays latched, so hip.VSTIP reads 1 even with hvip.VSTIP = 0.

## Reproduce

    make run        # needs riscv64-unknown-elf-gcc and spike on PATH

`vstip.S` runs in M-mode with hvip = 0 and htimedelta = 0. It sets vstimecmp = 0 with menvcfg.STCE = henvcfg.STCE = 1,
so hip.VSTIP = 1. It then:

- clears henvcfg.STCE and reads hip.VSTIP, which must be 0;
- sets henvcfg.STCE again, clears menvcfg.STCE, and reads hip.VSTIP, which must be 0.

It waits 10000 loop iterations before each read. It writes tohost = 100*(step 0) + 10*(case 1) + (case 2).

- Expected: 100.
- Spike prints `*** FAILED *** (tohost = 111)`.

`spike-master.log` is the `-l --log-commits` output. The wait-loop iterations and the final spin are removed, and
every `csrr ..., hip` returns 0x40.

Seen on riscv-isa-sim master 4c6a9bc7 with `--isa=rv64gch_sstc`.
