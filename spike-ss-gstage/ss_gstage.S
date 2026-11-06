# Spike skips two G-stage checks for shadow stack (Zicfiss) accesses from a guest.
# The Zicfiss spec: "When G-stage page tables are active, the shadow stack instructions that access memory
# require the G-stage page table to have read-write permission for the accessed memory; else a store/AMO
# guest-page-fault exception is raised." and "If the memory referenced by SSPUSH, C.SSPUSH, SSPOPCHK,
# C.SSPOPCHK, SSAMOSWAP.W and SSAMOSWAP.D instructions is not idempotent, then the instructions cause a
# store/AMO access-fault exception."
#   Case 1: VS-mode SSPOPCHK on a VS-stage SS page whose G-stage leaf is read-only (no W): expect cause 23
#   Case 2: VS-mode SSPUSH on a VS-stage SS page (PBMT=PMA) whose G-stage leaf has PBMT=IO: expect cause 7
# The VS-stage tables map VA 0x80000000 (code, data) as a RWX gigapage and two SS gigapages at VA 0xC0000000
# and 0x100000000. The G-stage maps GPA 0x80000000 to itself (RWX), GPA 0xC0000000 read-only and GPA
# 0x100000000 read-write with PBMT=IO, both onto PA 0x80000000. Traps go to M-mode, which records mcause.
# tohost = 10000 + 100*(case 1 mcause) + (case 2 mcause), 0 meaning no trap: expected 12307.

#define CSR_MENVCFG 0x30a
#define CSR_HENVCFG 0x60a
#define CSR_HGATP   0x680
#define CSR_VSATP   0x280
#define CSR_SSP     0x011
#define PTE_V 0x01
#define PTE_R 0x02
#define PTE_W 0x04
#define PTE_X 0x08
#define PTE_U 0x10
#define PTE_A 0x40
#define PTE_D 0x80
#define PBMT_IO (2 << 61)
#define GIGA(pa) (((pa) >> 12) << 10)

    .section .text.init
    .globl _start
_start:
    la    t0, trap
    csrw  mtvec, t0
    li    t0, 1 << 42                   # mstatus.MDT, set at reset with Smdbltrp
    csrc  mstatus, t0
    li    t0, -1                        # PMP: everything to S/U
    csrw  pmpaddr0, t0
    li    t0, 0x1f
    csrw  pmpcfg0, t0
    li    t0, (1 << 62) | 8             # menvcfg.PBMTE, menvcfg.SSE
    csrs  CSR_MENVCFG, t0
    li    t0, 8                         # henvcfg.SSE
    csrs  CSR_HENVCFG, t0

    la    t0, vs_root                   # VS-stage: VA = GPA, gigapages
    li    t1, GIGA(0x80000000) | PTE_D | PTE_A | PTE_X | PTE_W | PTE_R | PTE_V
    sd    t1, 2*8(t0)
    li    t1, GIGA(0xC0000000) | PTE_D | PTE_A | PTE_W | PTE_V    # xwr=010: SS page
    sd    t1, 3*8(t0)
    li    t1, GIGA(0x100000000) | PTE_D | PTE_A | PTE_W | PTE_V   # xwr=010: SS page
    sd    t1, 4*8(t0)
    srli  t0, t0, 12
    li    t1, 8 << 60                   # Sv39
    or    t0, t0, t1
    csrw  CSR_VSATP, t0

    la    t0, g_root                    # G-stage, Sv39x4
    li    t1, GIGA(0x80000000) | PTE_D | PTE_A | PTE_U | PTE_X | PTE_W | PTE_R | PTE_V
    sd    t1, 2*8(t0)
    li    t1, GIGA(0x80000000) | PTE_D | PTE_A | PTE_U | PTE_R | PTE_V             # read-only
    sd    t1, 3*8(t0)
    li    t1, GIGA(0x80000000) | PBMT_IO | PTE_D | PTE_A | PTE_U | PTE_W | PTE_R | PTE_V
    sd    t1, 4*8(t0)
    srli  t0, t0, 12
    li    t1, 8 << 60                   # Sv39x4
    or    t0, t0, t1
    csrw  CSR_HGATP, t0
    hfence.gvma
    hfence.vvma

    # Case 1: ssp on the read-only G-stage alias of ssdata, which holds 0; x1 = 0 matches it.
    la    t0, ssdata
    li    t1, 0xC0000000 - 0x80000000
    add   t0, t0, t1
    csrw  CSR_SSP, t0
    la    s0, result1
    la    s1, case2
    la    t0, case1_vs
    j     enter_vs
case2:
    # Case 2: ssp on the PBMT=IO G-stage alias.
    la    t0, ssdata + 16
    li    t1, 0x100000000 - 0x80000000
    add   t0, t0, t1
    csrw  CSR_SSP, t0
    la    s0, result2
    la    s1, done
    la    t0, case2_vs
    j     enter_vs

enter_vs:                               # mret to VS-mode at t0
    csrw  mepc, t0
    li    t0, 3 << 11                   # MPP
    csrc  mstatus, t0
    li    t0, 1 << 11                   # MPP = S
    csrs  mstatus, t0
    li    t0, 1 << 39                   # MPV
    csrs  mstatus, t0
    mret

case1_vs:
    li    x1, 0
    sspopchk x1                         # expect a store/AMO guest-page fault (23)
    ecall
case2_vs:
    li    x1, 0x1234
    sspush x1                           # expect a store/AMO access fault (7)
    ecall

done:
    ld    t0, result1
    li    t1, 100
    mul   t0, t0, t1
    ld    t1, result2
    add   t0, t0, t1
    li    t1, 10000
    add   t0, t0, t1
    slli  t0, t0, 1
    ori   t0, t0, 1
    la    t1, tohost
    sd    t0, 0(t1)
1:  j     1b

    .align 2
trap:                                   # M-mode: an ecall from VS ends the case, any other trap is recorded
    csrr  t0, mcause
    li    t1, 10
    beq   t0, t1, 1f
    sd    t0, 0(s0)
    csrr  t0, mepc
    addi  t0, t0, 4
    csrw  mepc, t0
    mret                                # back to VS-mode, past the faulting instruction
1:  li    t0, 1 << 39                   # leave the guest: MPV = 0
    csrc  mstatus, t0
    jr    s1

    .section .tohost, "aw", @progbits
    .globl tohost
tohost:   .dword 0
    .globl fromhost
fromhost: .dword 0

    .data
    .align 14
g_root:   .zero 16384
vs_root:  .zero 4096
result1:  .dword 0
result2:  .dword 0
    .align 6
ssdata:   .zero 64
