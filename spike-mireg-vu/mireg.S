# Spike raises virtual-instruction for the M-level CSRs mireg/mireg2-6 accessed with V=1.
# Being M-level, any access below M must raise illegal-instruction (mcause 2).
#   Case 1: csrr mireg from VU, mstateen0.CSRIND=1, hstateen0.CSRIND=1
#   Case 2: csrr mireg from VS, mstateen0.CSRIND=1, hstateen0.CSRIND=0
# Expected: both trap with mcause 2.  tohost = 100*(case 1 mcause) + (case 2 mcause), so a pass is 202.
# (Spike reports any tohost other than 1 as FAILED; 202 is still the correct result.)

#define CSRIND   (1 << 60)
#define MPP      (3 << 11)
#define MPP_S    (1 << 11)
#define MPV      (1 << 39)

    .section .text.init
    .globl _start
_start:
    la    t0, trap
    csrw  mtvec, t0
    li    t0, CSRIND
    csrs  0x30c, t0                 # mstateen0.CSRIND = 1

    # Case 1: VU, hstateen0.CSRIND = 1
    li    s0, 1
    csrs  0x60c, t0                 # hstateen0.CSRIND = 1
    li    t0, MPP
    csrc  mstatus, t0               # MPP = U
    li    t0, MPV
    csrs  mstatus, t0               # MPV = 1
    la    t0, guest
    csrw  mepc, t0
    mret

case2:
    # Case 2: VS, hstateen0.CSRIND = 0
    mv    s1, t0                    # case 1 mcause
    li    s0, 2
    li    t0, CSRIND
    csrc  0x60c, t0                 # hstateen0.CSRIND = 0
    li    t0, MPP
    csrc  mstatus, t0
    li    t0, MPP_S
    csrs  mstatus, t0               # MPP = S
    li    t0, MPV
    csrs  mstatus, t0               # MPV = 1
    la    t0, guest
    csrw  mepc, t0
    mret

guest:
    csrr  a0, 0x351                 # mireg (M-level): must raise illegal instruction
    ecall                           # reached only if csrr did not trap: reports mcause 8 or 10

trap:
    csrr  t0, mcause
    li    t1, 1
    beq   s0, t1, case2
    li    t1, 100                   # case 2 done: tohost = 100*s1 + t0
    mul   s1, s1, t1
    add   t0, t0, s1
    slli  t0, t0, 1
    ori   t0, t0, 1
    la    t1, tohost
    sd    t0, 0(t1)
1:  j     1b

    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost: .dword 0
    .align 6
    .globl fromhost
fromhost: .dword 0
