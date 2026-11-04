# Reproducers for Spike Debug Module / DTM / Sdext deviations from the
# RISC-V Debug Specification (0.13.2 and 1.0 ratified).
# Run by run.sh: OpenOCD connects to Spike's remote-bitbang port.
# Each check prints one line:
#   RESULT <n> <name>: observed <x>; spec requires <y> -> BUG|OK

init
poll off

proc rd {a} {
    if {[catch {riscv dmi_read $a} v]} { return "FAILED" }
    return [format 0x%08x $v]
}
proc wr {a v} {
    if {[catch {riscv dmi_write $a [format 0x%08x [expr {$v & 0xffffffff}]]} e]} { return "FAILED" }
    return "ok"
}
proc result {n name observed required ok} {
    echo [format "RESULT %s %s: observed %s; spec requires %s -> %s" \
        $n $name $observed $required [expr {$ok ? "OK" : "BUG"}]]
}

set DMCONTROL 0x10
set DMSTATUS 0x11
set ABSTRACTCS 0x16
set COMMAND 0x17
set ABSTRACTAUTO 0x18

proc wait_busy {} {
    global ABSTRACTCS
    for {set i 0} {$i < 100} {incr i} {
        set v [rd $ABSTRACTCS]
        if {!($v & 0x1000)} { break }
    }
    return [expr {([rd $ABSTRACTCS] >> 8) & 7}]
}
proc clrerr {} { global ABSTRACTCS; wr $ABSTRACTCS 0x700 }
proc cmd {c} { global COMMAND; clrerr; wr $COMMAND $c; return [wait_busy] }
# 64-bit access register read/write (aarsize=3, transfer=1)
proc rdreg {regno} {
    set e [cmd [expr {(3 << 20) | (1 << 17) | $regno}]]
    return [expr {([rd 0x05] << 32) | [rd 0x04]}]
}
proc wrreg {regno val} {
    wr 0x04 [expr {$val & 0xffffffff}]
    wr 0x05 [expr {($val >> 32) & 0xffffffff}]
    return [cmd [expr {(3 << 20) | (1 << 17) | (1 << 16) | $regno}]]
}
proc halted {} { global DMSTATUS; return [expr {([rd $DMSTATUS] >> 9) & 1}] }
proc halt {} {
    global DMCONTROL
    wr $DMCONTROL 0x80000001
    for {set i 0} {$i < 100 && ![halted]} {incr i} {}
    wr $DMCONTROL 0x00000001
}
proc resume {} {
    global DMCONTROL DMSTATUS
    wr $DMCONTROL 0x40000001
    for {set i 0} {$i < 100} {incr i} {
        if {([rd $DMSTATUS] >> 17) & 1} { break }
    }
    wr $DMCONTROL 0x00000001
}

wr $DMCONTROL 0x00000001
sleep 200

if {$SESSION eq "default"} {

# 1. dmcontrol.haltreq is W (0.13.2) / WARZ (1.0): reads return 0.
wr $DMCONTROL 0x80000001
set v [rd $DMCONTROL]
result 1 "dmcontrol.haltreq reads back" "dmcontrol=$v" "bit 31 reads 0" [expr {!(($v >> 31) & 1)}]
for {set i 0} {$i < 100 && ![halted]} {incr i} {}
wr $DMCONTROL 0x00000001

# 2. Unimplemented / unlisted DM registers read 0, writes have no effect;
#    no specified case in which the DM responds with an error.
# OpenOCD's "riscv dmi_read" does not report a failed op, so use raw
# scans: a read, then a nop whose capture shows the read's op and data.
irscan riscv.cpu 0x10
set dtmcs [expr {"0x[drscan riscv.cpu 32 0x10000]"}]
set W [expr {(($dtmcs >> 4) & 0x3f) + 34}]
proc raw_read {a} {
    global W
    irscan riscv.cpu 0x10
    drscan riscv.cpu 32 0x10000
    irscan riscv.cpu 0x11
    drscan riscv.cpu $W [format 0x%x [expr {($a << 34) | 1}]]
    set c [expr {"0x[drscan riscv.cpu $W 0]"}]
    return [list [expr {$c & 3}] [format 0x%08x [expr {($c >> 2) & 0xffffffff}]]]
}
proc raw_write {a v} {
    global W
    irscan riscv.cpu 0x10
    drscan riscv.cpu 32 0x10000
    irscan riscv.cpu 0x11
    drscan riscv.cpu $W [format 0x%x [expr {($a << 34) | ($v << 2) | 2}]]
    set c [expr {"0x[drscan riscv.cpu $W 0]"}]
    return [expr {$c & 3}]
}
foreach {a name} {0x0e data10 0x19 confstrptr0 0x1d nextdm 0x2f progbuf15 0x50 unlisted-0x50} {
    lassign [raw_read $a] op v
    result 2 "read $name ($a): op/data" "$op/$v" "0/0x00000000" [expr {$op == 0 && $v eq "0x00000000"}]
}
foreach {a name} {0x1d nextdm} {
    set op [raw_write $a 0]
    result 2 "write $name ($a): op" $op "0 (no effect, no error)" [expr {$op == 0}]
}
irscan riscv.cpu 0x10
drscan riscv.cpu 32 0x10000
irscan riscv.cpu 0x11

# 3. dmactive=0 returns DM state to reset values; data0 resets to 0.
wr 0x04 0x12345678
wr $DMCONTROL 0x00000000
for {set i 0} {$i < 100 && ([rd $DMCONTROL] & 1)} {incr i} {}
wr $DMCONTROL 0x00000001
for {set i 0} {$i < 100 && !([rd $DMCONTROL] & 1)} {incr i} {}
set v [rd 0x04]
result 3 "data0 after dmactive 1->0->1" $v "0x00000000 (reset value)" [expr {$v eq "0x00000000"}]

# 4. With sbasize=0 / no sbaccess bits, sbaddress0 / sbdata0 are not present
#    (so they read 0).
set sbcs [rd 0x38]
wr 0x39 0x80000000
set v [rd 0x39]
result 4 "sbaddress0 with sbcs=$sbcs" $v "0x00000000 (register not present)" [expr {$v eq "0x00000000"}]
wr 0x3d 0x00001234
set v [rd 0x3d]
result 4 "sbdata1 with sbcs=$sbcs" $v "0x00000000 (register not present)" [expr {$v eq "0x00000000"}]
# Writing the absent sbdata0 must have no effect, so sbcs stays 0.
wr 0x3c 0x00005678
for {set i 0} {$i < 100 && ([rd 0x38] & 0x00200000)} {incr i} {}
set v [rd 0x38]
result 4 "sbcs after writing sbdata0 (absent)" $v "0x00000000 (no effect)" [expr {$v eq "0x00000000"}]
wr 0x38 0x00007000

# 5. transfer=0: aarsize is not looked at ("without having to worry about
#    placing valid values into aarsize or regno").
set e [cmd [expr {(4 << 20) | 0x1005}]]
result 5 "Access Register transfer=0 aarsize=4 cmderr" $e "0 (nothing to do)" [expr {$e == 0}]

# 6. aarpostincrement=1 must either increment regno or fail with cmderr=2.
set e [cmd [expr {(3 << 20) | (1 << 19) | (1 << 17) | 0x1005}]]
set first [rd 0x04]
wr $ABSTRACTAUTO 0x1
set aa [rd $ABSTRACTAUTO]
rd 0x04
wr $ABSTRACTAUTO 0x0
wait_busy
set second [rd 0x04]
result 6 "aarpostincrement read x5 (0x55), x6=0x66: cmderr=$e first=$first, abstractauto=$aa, after autoexec" $second "0x00000066, or cmderr=2" [expr {$e == 2 || $second eq "0x00000066"}]

halt

# 7. dcsr.stepie=0 (Spike hard-wires it): interrupts disabled while stepping.
set dcsr [rdreg 0x7b0]
wrreg 0x7b0 [expr {$dcsr | 0x804}]
set dcsr1 [rdreg 0x7b0]
wrreg 0x7b0 [expr {($dcsr | 0x4) & ~0x800}]
set mstatus [rdreg 0x300]
wrreg 0x300 [expr {$mstatus | 0x8}]
set mip [rdreg 0x344]
set dpc0 [rdreg 0x7b1]
resume
for {set i 0} {$i < 100 && ![halted]} {incr i} {}
set dpc [rdreg 0x7b1]
set mcause [rdreg 0x342]
set cause [expr {([rdreg 0x7b0] >> 6) & 7}]
result 7 [format "step with stepie=0 (stepie reads %d), mip=0x%x, MIE=1, dpc before=0x%x (loop=%s): dpc/mcause/dcsr.cause" \
    [expr {($dcsr1 >> 11) & 1}] $mip $dpc0 $LOOP] \
    [format "0x%x/0x%x/%d" $dpc $mcause $cause] \
    [format "%s/0x0/4 (no interrupt taken)" $LOOP] \
    [expr {$dpc == $LOOP && $mcause == 0}]

# 9. DTM: BYPASS captures 0; unimplemented IR values select BYPASS.
irscan riscv.cpu 0x1f
drscan riscv.cpu 1 1
set v [drscan riscv.cpu 1 0]
result 9 "BYPASS (IR 0x1f) capture after shifting in 1" $v "0" [expr {$v == 0}]
foreach ir {0x00 0x05} {
    irscan riscv.cpu 0x01
    drscan riscv.cpu 32 0
    irscan riscv.cpu $ir
    set v [drscan riscv.cpu 8 0xa5]
    result 9 "IR $ir, 8-bit DR scan of 0xa5" "0x$v" "0x4a (1-bit BYPASS: 0 then TDI delayed)" [expr {"0x$v" == 0x4a}]
}

# 10. DTM: a failed DMI op is sticky until dmireset, and dtmcs.dmistat
#     reports it. (nextdm read fails on Spike, see 2.)
irscan riscv.cpu 0x10
set dtmcs [expr {"0x[drscan riscv.cpu 32 0x10000]"}]
set abits [expr {($dtmcs >> 4) & 0x3f}]
set w [expr {$abits + 34}]
irscan riscv.cpu 0x11
drscan riscv.cpu $w [format 0x%x [expr {(0x1d << 34) | 1}]]
set c1 [expr {"0x[drscan riscv.cpu $w 0]" & 3}]
set c2 [expr {"0x[drscan riscv.cpu $w 0]" & 3}]
irscan riscv.cpu 0x10
set dmistat [expr {("0x[drscan riscv.cpu 32 0]" >> 10) & 3}]
result 10 "after a failed DMI read: op of next two nop scans / dtmcs.dmistat" "$c1, $c2 / $dmistat" "2, 2 / 2 (sticky until dmireset)" \
    [expr {$c1 == 2 && $c2 == 2 && $dmistat == 2}]
irscan riscv.cpu 0x10
drscan riscv.cpu 32 0x10000
irscan riscv.cpu 0x11

} elseif {$SESSION eq "busy"} {

# 12. Accesses made while an abstract command is executing. The Program
#     Buffer counts x5 down (addi x5,x5,-1; bnez x5,.-4), so a command
#     with postexec=1 stays busy for many DMI scans.
halt
wr 0x20 0xfff28293
wr 0x21 0xfe029ee3
proc start_busy {} {
    global COMMAND ABSTRACTCS
    wrreg 0x1005 0x40000
    clrerr
    wr $COMMAND [expr {1 << 18}]
    return [expr {([rd $ABSTRACTCS] >> 12) & 1}]
}
proc finish_busy {} {
    global ABSTRACTCS
    for {set i 0} {$i < 20000 && ([rd $ABSTRACTCS] & 0x1000)} {incr i} {}
    return [expr {([rd $ABSTRACTCS] >> 8) & 7}]
}
# 12a. Control: no access while busy.
set b [start_busy]
set e [finish_busy]
result 12a "control, no access while busy (busy=$b): cmderr" $e "0" [expr {$e == 0}]
# 12b-f. Each access below must set cmderr to 1 (busy).
foreach {n what script} {
    12b "write abstractcs (0)" {wr $ABSTRACTCS 0}
    12c "write command (postexec, transfer=0)" {wr $COMMAND [expr {1 << 18}]}
    12d "write abstractauto (0)" {wr $ABSTRACTAUTO 0}
    12e "read progbuf0" {rd 0x20}
    12f "write progbuf0 (same value)" {wr 0x20 0xfff28293}
} {
    set b [start_busy]
    eval $script
    set e [finish_busy]
    result $n "$what while busy (busy=$b): cmderr" $e "1 (busy)" [expr {$e == 1}]
}
# 12g. resumereq written while busy (1.0: "Writes to this bit should be
#      ignored while an abstract command is executing").
set b [start_busy]
wr $DMCONTROL 0x40000001
set st [rd $DMSTATUS]
wr $DMCONTROL 0x00000001
finish_busy
for {set i 0} {$i < 20} {incr i} { rd $DMSTATUS }
set h [halted]
result 12g [format "resumereq written while busy (busy=%d; allresumeack right after the write=%d): halted after the command" $b [expr {($st >> 17) & 1}]] \
    $h "1 (should: write ignored)" [expr {$h == 1}]
} elseif {$SESSION eq "auth"} {

# 13. Spike run with --dm-auth: while dmstatus.authenticated=0 the DM
#     "must not ... expose details about the harts connected to the DM";
#     all DM registers except the listed exceptions read 0.
set st [rd $DMSTATUS]
set hs [rd 0x40]
set hi [rd 0x12]
set ac [rd $ABSTRACTCS]
result 13 "unauthenticated reads: dmstatus/haltsum0/hartinfo/abstractcs" "$st/$hs/$hi/$ac" "only authenticated/authbusy/version nonzero in dmstatus; others 0" \
    [expr {($st & ~0x000000cf) == 0 && $hs eq "0x00000000" && $hi eq "0x00000000" && $ac eq "0x00000000"}]

} elseif {$SESSION eq "v10"} {

# Checks against rules that are new in Debug 1.0 (Spike reports
# dmstatus.version=2, i.e. 0.13, so these apply only if Spike targets 1.0).
halt
set da [rdreg 0x1005]
# 14. Access Register bit 23 is defined as 0: "if bits that are defined
#     as 0 aren't 0, then the DM must set cmderr to 2".
set e [cmd [expr {(1 << 23) | (3 << 20) | (1 << 17) | 0x1005}]]
result 14 "(1.0) Access Register read of x5 with bit 23=1: cmderr" $e "2 (not supported)" [expr {$e == 2}]
# 15. abstractauto: "bits corresponding to implemented progbuf and data
#     registers must be writable. Other bits must be hard-wired to 0."
set ds [rd $ABSTRACTCS]
set dc [expr {$ds & 0xf}]
set pb [expr {($ds >> 24) & 0x1f}]
wr $ABSTRACTAUTO 0xffffffff
set aa [rd $ABSTRACTAUTO]
wr $ABSTRACTAUTO 0
set want [format 0x%08x [expr {((1 << $pb) - 1) << 16 | ((1 << $dc) - 1)}]]
result 15 "(1.0) abstractauto after writing all 1s (datacount=$dc, progbufsize=$pb)" $aa $want [expr {$aa eq $want}]
# 16. dcsr.prv is WARL in 1.0; 2 is reserved, so it must read back legal.
set dcsr [rdreg 0x7b0]
wrreg 0x7b0 [expr {($dcsr & ~3) | 2}]
set p [expr {[rdreg 0x7b0] & 3}]
wrreg 0x7b0 $dcsr
result 16 "(1.0) dcsr.prv after writing 2 (reserved)" $p "0, 1 or 3 (WARL: legal value)" [expr {$p != 2}]
# 17. resumereq is W1: "When read the returned value should be 0." (a
#     recommendation). Written with haltreq=1 so it is ignored.
wr $DMCONTROL 0xc0000001
set v [rd $DMCONTROL]
wr $DMCONTROL 0x00000001
result 17 "(1.0, should) dmcontrol after writing haltreq=1 resumereq=1" $v "bit 30 reads 0" [expr {!(($v >> 30) & 1)}]


# 18. Security (1.0): "Implementations where it's not possible to unlock
#     the DM by using authdata should not implement that register." (a
#     recommendation). Without --dm-auth the DM is always authenticated.
set st [rd $DMSTATUS]
set ad [rd 0x30]
result 18 [format "(1.0, should) authdata with dmstatus.authenticated=%d" [expr {($st >> 7) & 1}]] $ad "0x00000000 (not implemented)" [expr {$ad eq "0x00000000"}]
} elseif {$SESSION eq "p2"} {

# 19. Spike run with -p2. haltsum0 is required in 0.13.2 and, in 1.0,
#     "might not be present if fewer than 2 harts are connected to this
#     DM". With 2 harts and hart 0 halted, bit 0 must read 1.
halt
set h [halted]
irscan riscv.cpu 0x10
set dtmcs [expr {"0x[drscan riscv.cpu 32 0x10000]"}]
set W [expr {(($dtmcs >> 4) & 0x3f) + 34}]
irscan riscv.cpu 0x11
drscan riscv.cpu $W [format 0x%x [expr {(0x40 << 34) | 1}]]
set c [expr {"0x[drscan riscv.cpu $W 0]"}]
set op [expr {$c & 3}]
set v [format 0x%08x [expr {($c >> 2) & 0xffffffff}]]
irscan riscv.cpu 0x10
drscan riscv.cpu 32 0x10000
result 19 "haltsum0 with 2 harts, hart 0 halted (dmstatus.allhalted=$h): op/data" "$op/$v" "0/bit 0 set" [expr {$op == 0 && ($v & 1)}]

} elseif {$SESSION eq "rti"} {

# 10b. Spike run with --dmi-rti: a scan that arrives before the
#      required Run-Test/Idle cycles gets busy (op 3), sticky until
#      dmireset; dtmcs.dmistat must report it.
halt
irscan riscv.cpu 0x10
set dtmcs [expr {"0x[drscan riscv.cpu 32 0x10000]"}]
set w [expr {(($dtmcs >> 4) & 0x3f) + 34}]
irscan riscv.cpu 0x11
drscan riscv.cpu $w [format 0x%x [expr {(0x11 << 34) | 1}]]
set c1 [expr {"0x[drscan riscv.cpu $w 0]" & 3}]
irscan riscv.cpu 0x10
set dmistat [expr {("0x[drscan riscv.cpu 32 0]" >> 10) & 3}]
result 10 "back-to-back DMI scans with --dmi-rti: op of second scan / dtmcs.dmistat" "$c1 / $dmistat" "3 / 3" \
    [expr {$c1 == 3 && $dmistat == 3}]
drscan riscv.cpu 32 0x10000

} else {

# 11. progbufsize=0: postexec=0 is the only supported variant, so
#     postexec=1 must fail with cmderr=2.
halt
set ps [expr {([rd $ABSTRACTCS] >> 24) & 0x1f}]
set e [cmd [expr {(1 << 18)}]]
result 11 "Access Register postexec=1, transfer=0 with progbufsize=$ps: cmderr" $e "2 (not supported)" [expr {$e == 2}]

}

shutdown
