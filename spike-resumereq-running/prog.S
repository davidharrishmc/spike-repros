# The hart just loops.
    .section .text.init
    .globl _start
_start:
    j     _start

    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost: .dword 0
