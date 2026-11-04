#!/bin/bash
# Usage: SPIKE=/path/to/spike ./run.sh
# Needs riscv64-unknown-elf-gcc and OpenOCD (riscv-openocd or upstream >= 0.12).
set -e
cd "$(dirname "$0")"
SPIKE=${SPIKE:-spike}
riscv64-unknown-elf-gcc -march=rv64gc -mabi=lp64d -nostdlib -nostartfiles \
    -T link.ld -o prog.elf prog.S
port=$((20000 + RANDOM % 20000))
$SPIKE --isa=rv64gc --rbb-port=$port prog.elf &
spid=$!
sleep 1
openocd -c "set PORT $port" -f openocd.cfg -f repro.tcl 2>&1 | grep -E '^(start|control|after|halt)' || true
kill $spid 2>/dev/null || true; wait $spid 2>/dev/null || true
