// Bare-metal harness: every trap goes to M-mode (medeleg = mideleg = 0). Each CASE enters a mode with mret,
// runs one instruction, and expects either a given mcause on that instruction or (CASE_OK) no trap, which
// shows up as the following ecall. Exit status = bitmask of failed cases (bit id-1); 0 = pass.
#define MSTATEEN0  0x30C
#define MSTATEEN0H 0x31C
#define HSTATEEN0  0x60C
#define HSTATEEN0H 0x61C
#define MSTATUSH   0x310
#define SISELECT   0x150
#define SIREG      0x151
#define VSISELECT  0x250
#define VSIREG     0x251
#define MENVCFG    0x30A
#define MENVCFGH   0x31A
#define U 0
#define S 1

// Enter mode (mpp, mpv) at the address in t1. V=1 modes are entered with sret from HS-mode (hstatus.SPV=1),
// because QEMU 11.1 does not let M-mode write mstatus.MPV (https://gitlab.com/qemu-project/qemu/-/issues/4588).
.macro ENTER mpp, mpv
  li t0, 0x1800
  csrc mstatus, t0
  .if \mpv
  li t0, 1 << 11
  csrs mstatus, t0          // MPP = S: mret to the HS stub below
  li t0, 0x80
  csrs hstatus, t0          // SPV = 1
  li t0, 0x100
  csrc sstatus, t0
  .if \mpp
  csrs sstatus, t0          // SPP = S (VS) or U (VU)
  .endif
  csrw sepc, t1
  la t0, 4f
  csrw mepc, t0
  mret
4: sret
  .else
  li t0, \mpp << 11
  csrs mstatus, t0
  csrw mepc, t1
  mret
  .endif
.endm

// expect mcause \cause on the instruction
.macro CASE id, mpp, mpv, cause, insn:vararg
  li s0, \id
  li s1, \cause
  la s2, 2f
  la s3, 1f
  mv t1, s3
  ENTER \mpp, \mpv
1: \insn
  ecall
2:
.endm

// expect no trap: the ecall that follows traps with cause 8 (U/VU), 9 (HS) or 10 (VS)
.macro CASE_OK id, mpp, mpv, insn:vararg
  li s0, \id
  li s1, 8 + \mpp + (\mpp & \mpv)
  la s2, 2f
  la s3, 3f
  la t1, 1f
  ENTER \mpp, \mpv
1: \insn
3: ecall
2:
.endm

.macro START
  .globl _start
_start:
  la t0, mtrap
  csrw mtvec, t0
  li s4, 0
  li t0, -1
  csrw pmpaddr0, t0
  li t0, 0x1F
  csrw pmpcfg0, t0          // PMP entry 0: NAPOT over all memory, RWX, so lower modes can run
  j main
mtrap:
  csrr t0, mcause
  csrr t1, mepc
  bne t1, s3, 1f
  beq t0, s1, 2f
1:
  li t2, 1
  addi t3, s0, -1
  sll t2, t2, t3
  or s4, s4, t2
2:
  csrw mepc, s2             // continue in M-mode through mret, which also clears MPV
  li t0, 0x1800
  csrs mstatus, t0
  mret
main:
.endm

.macro FINISH
  mv a0, s4
#ifdef QEMU_FINISHER
  li t0, 0x5555
  beqz a0, 1f
  slli t0, a0, 16
  li t1, 0x3333
  or t0, t0, t1
1:
  li t1, 0x100000
  sw t0, 0(t1)
#else
  slli a0, a0, 1
  ori a0, a0, 1
  la t0, tohost
  sw a0, 0(t0)
#endif
9: j 9b
  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
.endm

// mstateen0/hstateen0 bit 60 (CSRIND): set or clear from M-mode. On RV32, bit 28 of the high halves.
.macro STATEEN op, csr, csrh
#if __riscv_xlen == 64
  li t0, 1
  slli t0, t0, 60
  \op \csr, t0
#else
  li t0, 1 << 28
  \op \csrh, t0
#endif
.endm

// all ones in mstateen0 and hstateen0 (low half first: QEMU #4611 clears mstateen0h on an mstateen0 write)
.macro STATEEN_ALL
  li t0, -1
  csrw MSTATEEN0, t0
#if __riscv_xlen == 32
  csrw MSTATEEN0H, t0
#endif
  csrw HSTATEEN0, t0
#if __riscv_xlen == 32
  csrw HSTATEEN0H, t0
#endif
.endm
