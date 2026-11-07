// Pass/fail: x31 = 0 pass, else the number of the failing check.
// Spike and Whisper: tohost = (x31 << 1) | 1. QEMU virt: test finisher at 0x100000.
#if defined(QEMU)
#define EXIT  li t0, 0x100000; beqz x31, 1f; slli t1, x31, 16; li t2, 0x3333; or t1, t1, t2; sw t1, 0(t0); j .; 1: li t1, 0x5555; sw t1, 0(t0); j .
#else
#define EXIT  slli t0, x31, 1; ori t0, t0, 1; la t1, tohost; sw t0, 0(t1); sw zero, 4(t1); j .
#endif
#define CHECK(n, reg, val) li t4, val; beq reg, t4, 9f; li x31, n; j done; 9:
// CHECKC: record a failed check n in bit n of x31 and keep going.
#define CHECKC(n, reg, val) li t4, val; beq reg, t4, 9f; li t5, 1 << (n); or x31, x31, t5; 9:
