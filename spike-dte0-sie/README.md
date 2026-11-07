# Spike: SIE cannot be set with menvcfg.DTE = 0 after SDT was 1

riscv-isa-sim#2374 (fixed by #2375) is still reproducible at f90d5af5 (2026-11-04).

Sequence (M-mode): `menvcfg.DTE = 1`, `mstatus.SDT = 1`, `menvcfg.DTE = 0`, then `csrsi sstatus, 2` (SIE = 1).
With `menvcfg.DTE = 0` the hart behaves as though Ssdbltrp is not implemented and `sstatus.SDT` reads 0, so the
write must set SIE. Spike leaves SIE = 0, through `sstatus` and through `mstatus`.

#2375 added the DTE check to `sstatus_proxy_csr_t::unlogged_write`, but that function then calls
`mstatus->write()`, and `mstatus_csr_t::unlogged_write` rebuilds the value from the hidden `this->val` (whose SDT is
still 1, the DTE=0 write mask excludes SDT) and clears SIE unconditionally:
`new_mstatus = (new_mstatus & MSTATUS_SDT) ? (new_mstatus & ~MSTATUS_SIE) : new_mstatus;`

`make run`: exit code / tohost = bitmask of failed checks (bit 1 SDT read, bit 2 SIE via sstatus, bit 3 SIE via
mstatus). Expected: PASS. Actual: `*** FAILED *** (tohost = 12)` (checks 2 and 3).
