#!/bin/bash
# Usage: SPIKE=/path/to/spike ./run.sh
# Needs riscv64-unknown-elf-gcc and OpenOCD (riscv-openocd or upstream >= 0.12).
set -e
cd "$(dirname "$0")"
SPIKE=${SPIKE:-spike}
riscv64-unknown-elf-gcc -march=rv64gc -mabi=lp64d -nostdlib -nostartfiles \
    -T link.ld -o prog.elf prog.S
LOOP=$(riscv64-unknown-elf-nm prog.elf | awk '$3=="loop"{print "0x"$1}')
run() {   # $1 = session name, rest = extra Spike options
    local session=$1; shift
    local port=$((20000 + RANDOM % 20000))
    $SPIKE --isa=rv64gc --rbb-port=$port "$@" prog.elf &
    local spid=$!
    sleep 1
    openocd -c "set PORT $port; set SESSION $session; set LOOP $LOOP" \
        -f openocd.cfg -f repro.tcl 2>&1 | grep '^RESULT' || true
    kill $spid 2>/dev/null || true; wait $spid 2>/dev/null || true
}
$SPIKE --help 2>&1 | head -1
run default
run progsize0 --dm-progsize=0
run rti --dmi-rti=20
run busy
run auth --dm-auth
run v10
run p2 -p2
