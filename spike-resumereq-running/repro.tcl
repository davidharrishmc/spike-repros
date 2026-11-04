# Spike: a resume request written while the hart is running is not
# ignored. Spike remembers it and resumes the hart the next time the hart
# halts. Run by run.sh: OpenOCD connects to Spike's remote-bitbang port.

init
poll off

proc rd {a} { return [format 0x%08x [riscv dmi_read $a]] }
proc wr {a v} { riscv dmi_write $a [format 0x%08x $v] }
proc state {} {
    set s [rd 0x11]
    return [format "dmstatus=%s (allhalted=%d allrunning=%d allresumeack=%d)" $s \
        [expr {($s >> 9) & 1}] [expr {($s >> 11) & 1}] [expr {($s >> 17) & 1}]]
}
# haltreq=1 until halted, then haltreq=0; then wait and report the state.
proc halt_and_report {label} {
    wr 0x10 0x80000001
    for {set i 0} {$i < 100 && !(([rd 0x11] >> 9) & 1)} {incr i} {}
    wr 0x10 0x00000001
    sleep 100
    echo "$label: [state]"
}
proc resume {} {
    wr 0x10 0x40000001
    for {set i 0} {$i < 100 && !(([rd 0x11] >> 17) & 1)} {incr i} {}
    wr 0x10 0x00000001
}

wr 0x10 0x00000001
sleep 200
echo "start: [state]"

# Control: halt without any earlier resume request. The hart stays halted.
halt_and_report "control, halt only"
resume
echo "after resume: [state]"

# Bug: write resumereq=1 while the hart is running, then halt it.
wr 0x10 0x40000001
wr 0x10 0x00000001
echo "after resumereq to running hart: [state]"
halt_and_report "halt after resumereq to running hart"

shutdown
