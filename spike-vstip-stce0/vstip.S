# Spike keeps hip.VSTIP = 1 from a vstimecmp comparison after STCE is cleared.
# With henvcfg.STCE = 0 (or menvcfg.STCE = 0, which makes henvcfg.STCE read-only 0), hip.VSTIP must revert
# to its behavior without Sstc: hvip.VSTIP alone, which is 0 here.
#   Step 0: menvcfg.STCE = henvcfg.STCE = 1, htimedelta = 0, hvip = 0, vstimecmp = 0: hip.VSTIP = 1
#   Case 1: clear henvcfg.STCE: hip.VSTIP must be 0
#   Case 2: set henvcfg.STCE again (hip.VSTIP = 1), then clear menvcfg.STCE: hip.VSTIP must be 0
# tohost = 100*(step 0 VSTIP) + 10*(case 1 VSTIP) + (case 2 VSTIP), so a pass is 100.
# (Spike reports any tohost other than 1 as FAILED; 100 is still the correct result.)

#define CSR_MENVCFG    0x30a
#define CSR_HTIMEDELTA 0x605
#define CSR_HENVCFG    0x60a
#define CSR_HIP        0x644
#define CSR_HVIP       0x645
#define CSR_VSTIMECMP  0x24d

    .section .text.init
    .globl _start
_start:
    la    t0, trap
    csrw  mtvec, t0
    li    t0, 1
    slli  t0, t0, 63                # STCE is bit 63 of menvcfg and henvcfg
    csrs  CSR_MENVCFG, t0
    csrs  CSR_HENVCFG, t0
    csrw  CSR_HTIMEDELTA, zero
    csrw  CSR_HVIP, zero
    csrw  CSR_VSTIMECMP, zero       # time + htimedelta >= 0 always holds
    jal   wait
    csrr  s1, CSR_HIP               # step 0: expect VSTIP = 1

    csrc  CSR_HENVCFG, t0           # case 1: henvcfg.STCE = 0
    jal   wait
    csrr  s2, CSR_HIP               # expect VSTIP = 0

    csrs  CSR_HENVCFG, t0
    jal   wait
    csrc  CSR_MENVCFG, t0           # case 2: menvcfg.STCE = 0, so henvcfg.STCE reads 0
    jal   wait
    csrr  s3, CSR_HIP               # expect VSTIP = 0

    srli  s1, s1, 6
    andi  s1, s1, 1
    srli  s2, s2, 6
    andi  s2, s2, 1
    srli  s3, s3, 6
    andi  s3, s3, 1
    li    t1, 100
    mul   a0, s1, t1
    li    t1, 10
    mul   s2, s2, t1
    add   a0, a0, s2
    add   a0, a0, s3
    j     done

# Let time advance well past several timer updates
wait:
    li    t1, 10000
1:  addi  t1, t1, -1
    bnez  t1, 1b
    ret

trap:                               # no trap is expected; report 999
    li    a0, 999
done:
    slli  a0, a0, 1
    ori   a0, a0, 1
    la    t1, tohost
    sd    a0, 0(t1)
1:  j     1b

    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost: .dword 0
    .align 6
    .globl fromhost
fromhost: .dword 0
