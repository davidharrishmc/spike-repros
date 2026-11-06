# Spike: shadow stack accesses skip the G-stage W check and the G-stage PBMT=IO check

The Zicfiss chapter of the privileged spec says:

- "When G-stage page tables are active, the shadow stack instructions that access memory require the G-stage
  page table to have read-write permission for the accessed memory; else a store/AMO guest-page-fault exception
  is raised."
- "If the memory referenced by SSPUSH, C.SSPUSH, SSPOPCHK, C.SSPOPCHK, SSAMOSWAP.W and SSAMOSWAP.D instructions is
  not idempotent, then the instructions cause a store/AMO access-fault exception." With Svpbmt, a nonzero G-stage
  PBMT overrides the PMA, so a G-stage PBMT=IO page is not idempotent.

`mmu_t::s2xlate` (riscv/mmu.cc) is not told that an access is a shadow stack access. It checks only R for
SSPOPCHK, which is a LOAD, and it never applies the PBMT=IO check that `walk` applies to the VS-stage
(`... || pte_pbmt == PBMT_IO) && ss_access`).

## Reproduce

    make run        # needs riscv64-unknown-elf-gcc and spike on PATH

`ss_gstage.S` enters VS-mode with VS-stage SS gigapages over two G-stage leaves:

- Case 1: SSPOPCHK through a read-only G-stage leaf (no W). Expected: store/AMO guest-page fault (23).
- Case 2: SSPUSH through a read-write G-stage leaf with PBMT=IO (menvcfg.PBMTE=1). Expected: store/AMO access fault (7).

Traps go to M-mode, which records mcause. tohost = 10000 + 100*(case 1 mcause) + (case 2 mcause), 0 meaning no trap.

- Expected: 12307. Sail 0.16 prints `FAILURE: 12307`, and Whisper writes the same value.
- Spike prints `*** FAILED *** (tohost = 10000)`: neither access traps.

`spike-master.log` is the `-l --log-commits` output around the two accesses.

Seen on riscv-isa-sim master 75fb7ef0 and f90d5af with `--isa=rv64gch_zicfiss_zimop_zaamo_svpbmt`.
