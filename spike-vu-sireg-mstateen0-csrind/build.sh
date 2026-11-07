#!/bin/sh
# Build every reproducer for RV64 and RV32: <name>-spike-rvX.elf (HTIF tohost exit, Spike and Whisper)
# and <name>-qemu-rvX.elf (virt test-finisher exit).
for src in *.S; do n=${src%.S}
  for x in 64 32; do a=$([ $x = 64 ] && echo lp64 || echo ilp32)
    riscv64-unknown-elf-gcc -march=rv${x}i_zicsr -mabi=$a -nostdlib -T link.ld -x assembler-with-cpp $src -o $n-spike-rv$x.elf
    riscv64-unknown-elf-gcc -DQEMU_FINISHER -march=rv${x}i_zicsr -mabi=$a -nostdlib -T link.ld -x assembler-with-cpp $src -o $n-qemu-rv$x.elf
  done
done
