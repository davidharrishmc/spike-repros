# hip.VSEIP stays 1 after hstatus.VGEIN changes from a pending guest interrupt file to 0

Spike f90d5af (master, 2026-11-04). Guest external interrupt 1 is pending (hgeip = 2, hvip = 0):

- hstatus.VGEIN = 1: hip.VSEIP reads 1, which is correct.
- hstatus.VGEIN = 0: hip.VSEIP must read 0, but Spike reads 1.

Changing VGEIN from 0 to 1 updates VSEIP correctly.

The cause is in `riscv/csrs.cc`, `hstatus_csr_t::unlogged_write`. It calls `imsic->vs[new_vgein]->update_mip()` only
when `new_vgein != 0`, so the VSEIP that the old guest file set is never cleared.

Files:
- `exp_vseip.elf`: the prebuilt ELF, for the riscv-arch-test spike-rv64-max configuration.
- `exp_vseip.S`: its source. It is a riscv-arch-test tests_ai test; rebuild it in riscv-arch-test with
  `tests_ai/run_ai.sh`.
- `run.sh`: the Spike command line.
- `spike-observed.log`: the observed output.

The test reports `SUCCESS` when correct. Spike prints
`step 1: hip.VSEIP vg=0 he=0; expect 0x0000000000000000` and fails.
