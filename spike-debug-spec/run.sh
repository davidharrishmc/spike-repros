#!/bin/bash
# Usage: SPIKE=/path/to/spike ./run.sh [issue]
#   With no argument, runs every check. With a riscv-isa-sim issue number
#   (2511-2525) or a check number (1-19, 12a-12g), runs only the Spike
#   session that check needs and prints only its RESULT lines.
# Needs riscv64-unknown-elf-gcc and OpenOCD (riscv-openocd or upstream >= 0.12).
set -e
cd "$(dirname "$0")"
SPIKE=${SPIKE:-spike}

# issue -> check(s) in repro.tcl
case "${1:-}" in
    "")   CHECKS="" ;;
    2511) CHECKS="1" ;;
    2512) CHECKS="2" ;;
    2513) CHECKS="3" ;;
    2514) CHECKS="4" ;;
    2515) CHECKS="5" ;;
    2516) CHECKS="6 11" ;;
    2517) CHECKS="7" ;;
    2518) CHECKS="9" ;;
    2519) CHECKS="10" ;;
    2520) CHECKS="12a 12b 12c 12d 12e 12f" ;;
    2521) CHECKS="13" ;;
    2522) CHECKS="14" ;;
    2523) CHECKS="15" ;;
    2524) CHECKS="16" ;;
    2525) CHECKS="19" ;;
    *)    CHECKS="$1" ;;
esac

# check -> session(s) of repro.tcl that run it
sessions_for() {
    case $1 in
        1|2|3|4|5|6|7|9) echo default ;;
        10)              echo "default rti" ;;
        11)              echo progsize0 ;;
        12*)             echo busy ;;
        13)              echo auth ;;
        14|15|16|17|18)  echo v10 ;;
        19)              echo p2 ;;
        *) echo "unknown check or issue: $1" >&2; exit 1 ;;
    esac
}

# session -> Spike options
spike_opts() {
    case $1 in
        progsize0) echo "--dm-progsize=0" ;;
        rti)       echo "--dmi-rti=20" ;;
        auth)      echo "--dm-auth" ;;
        p2)        echo "-p2" ;;
    esac
}

riscv64-unknown-elf-gcc -march=rv64gc -mabi=lp64d -nostdlib -nostartfiles \
    -T link.ld -o prog.elf prog.S
LOOP=$(riscv64-unknown-elf-nm prog.elf | awk '$3=="loop"{print "0x"$1}')

if [ -z "$CHECKS" ]; then
    SESSIONS="default progsize0 rti busy auth v10 p2"
    FILTER='^RESULT '
else
    SESSIONS=$(for c in $CHECKS; do sessions_for "$c"; done | tr ' ' '\n' | awk '!seen[$0]++')
    FILTER="^RESULT ($(echo $CHECKS | tr ' ' '|')) "
fi

run() {   # $1 = session name
    local session=$1
    local port=$((20000 + RANDOM % 20000))
    echo "== session $session: spike --isa=rv64gc $(spike_opts $session)"
    $SPIKE --isa=rv64gc --rbb-port=$port $(spike_opts $session) prog.elf >/dev/null 2>&1 &
    local spid=$!
    sleep 1
    openocd -c "set PORT $port; set SESSION $session; set LOOP $LOOP" \
        -f openocd.cfg -f repro.tcl 2>&1 | grep -E "$FILTER" || true
    kill $spid 2>/dev/null || true; wait $spid 2>/dev/null || true
}
for s in $SESSIONS; do run $s; done
