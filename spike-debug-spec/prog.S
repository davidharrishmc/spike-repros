# Hart setup for the reproducers: an M-mode software interrupt is pending
# and enabled in mie, but mstatus.MIE=0, so it is not taken until the
# debugger sets mstatus.MIE. x5/x6 hold distinct values.
    .section .text.init
    .globl _start
_start:
    la    t0, handler
    csrw  mtvec, t0
    li    t0, 8              # mie.MSIE
    csrw  mie, t0
    li    t0, 0x2000000      # CLINT msip
    li    t1, 1
    sw    t1, 0(t0)
    li    x5, 0x55
    li    x6, 0x66
    .globl loop
loop:
    j     loop

    .align 2
    .globl handler
handler:
    nop
    nop
    j     handler

    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost: .dword 0
    .align 6
    .globl fromhost
fromhost: .dword 0
