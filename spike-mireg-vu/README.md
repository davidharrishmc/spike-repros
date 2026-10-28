# Spike: mireg* accessed with V=1 raise virtual-instruction instead of illegal-instruction

mireg, mireg2-mireg6 (0x351, 0x352, 0x353, 0x355-0x357) are M-level CSRs. An access below M must raise
illegal-instruction. Spike raises virtual-instruction when V=1:

- From VU, always (the `state->v && state->prv == PRV_U` check, added by PR 2221 for sireg*/vsireg*, also catches mireg*).
- From VS, when mstateen0.CSRIND=1 and hstateen0.CSRIND=0 (the hstateen0 check). hstateen0.CSRIND only
  controls siselect/sireg*/vsiselect/vsireg*, not mireg*.

Both checks in `sscsrind_reg_csr_t::verify_permissions` (riscv/csrs.cc) run before the base privilege check,
and the class is shared by mireg*, sireg* and vsireg*.

## Reproduce

    make run        # needs riscv64-unknown-elf-gcc and spike on PATH

`mireg.S` runs both cases and writes tohost = 100*(case 1 mcause) + (case 2 mcause).
Expected 202 (illegal-instruction in both). Spike prints `*** FAILED *** (tohost = 2222)` (virtual-instruction
in both); with `-l` the log shows `exception trap_virtual_instruction` at the `csrr a0, mireg`.

Seen on riscv-isa-sim f2207b5a (master fb225a5f has the same code), `--isa=rv64gch_smstateen_smcsrind_sscsrind`.

## Fix

`spike-mireg-fix.patch` runs the base privilege check first for M-level CSRs; with it the test gives 202.
