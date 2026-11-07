// Spike: with menvcfg.DTE=0, SIE cannot be set after SDT was 1 (riscv-isa-sim#2374 fix incomplete).
// When menvcfg.DTE is 0, the hart behaves as though Ssdbltrp is not implemented and sstatus.SDT is read-only 0,
// so a CSR write of SIE=1 must set SIE. Spike's mstatus write keeps the hidden SDT bit and clears SIE.
#include "exit.h"
  .section .text.init
  .globl _start
_start:
  li x31, 0
  li t0, 1
  slli t0, t0, 59
  csrs menvcfg, t0          // DTE = 1
  li t1, 0x01000000
  csrs mstatus, t1          // SDT = 1
  csrc menvcfg, t0          // DTE = 0: SDT reads 0
  csrr t2, sstatus
  srli t2, t2, 24
  andi t2, t2, 1
  CHECKC(1, t2, 0)           // sstatus.SDT reads 0 with DTE = 0
  csrsi sstatus, 2          // SIE = 1 through sstatus
  csrr t2, sstatus
  andi t2, t2, 2
  CHECKC(2, t2, 2)           // Spike: SIE = 0
  csrci sstatus, 2
  csrsi mstatus, 2          // SIE = 1 through mstatus
  csrr t2, mstatus
  andi t2, t2, 2
  CHECKC(3, t2, 2)
done:
  EXIT
  .section .tohost, "aw"
  .align 6
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
