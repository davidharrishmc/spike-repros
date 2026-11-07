  .section .text.init; .globl _start
_start:
  li t0, 1; slli t0, t0, 60; csrs 0x30a, t0   # menvcfg.CDE
  li t0, (1<<13); csrs 0x309, t0; csrr t4, 0x309  # mvip
  li t0, (1<<13)
  csrs 0x308, t0       # mvien
  csrr t1, 0x308
  csrs 0x608, t0       # hvien
  csrr t2, 0x608
  csrs 0x645, t0       # hvip
  csrr t3, 0x645
  srli t1, t1, 13; andi t1, t1, 1
  srli t2, t2, 13; andi t2, t2, 1
  srli t3, t3, 13; andi t3, t3, 1
  slli t2, t2, 1
  slli t3, t3, 2
  or a0, t1, t2; or a0, a0, t3
  srli t4, t4, 13; andi t4, t4, 1; slli t4, t4, 4; or a0, a0, t4
  ori a0, a0, 8
  slli a0, a0, 1; ori a0, a0, 1
  la t0, tohost; sw a0, 0(t0)
1: j 1b
  .data; .align 3; .globl tohost; tohost: .dword 0; .globl fromhost; fromhost: .dword 0
