# Spike reproducers

Standalone reproducers for issues filed against [riscv-software-src/riscv-isa-sim](https://github.com/riscv-software-src/riscv-isa-sim). Each directory has a README.md, the source, a prebuilt ELF, a Makefile, the observed Spike log and, where there is one, a possible fix. The matching .tar.gz holds the same directory.

| Issue | Directory | Tarball |
|---|---|---|
| [riscv-isa-sim#2082](https://github.com/riscv-software-src/riscv-isa-sim/issues/2082) | [spike-vu-sireg-mstateen0-csrind](spike-vu-sireg-mstateen0-csrind/) | [spike-vu-sireg-mstateen0-csrind.tar.gz](spike-vu-sireg-mstateen0-csrind.tar.gz) |
| [riscv-isa-sim#2501](https://github.com/riscv-software-src/riscv-isa-sim/issues/2501) | [spike-mireg-vu](spike-mireg-vu/) | [spike-mireg-vu.tar.gz](spike-mireg-vu.tar.gz) |
| [riscv-isa-sim#2504](https://github.com/riscv-software-src/riscv-isa-sim/issues/2504) | [spike-vstip-stce0](spike-vstip-stce0/) | [spike-vstip-stce0.tar.gz](spike-vstip-stce0.tar.gz) |
| [riscv-isa-sim#2511](https://github.com/riscv-software-src/riscv-isa-sim/issues/2511)-[#2525](https://github.com/riscv-software-src/riscv-isa-sim/issues/2525) (Debug spec; list in the directory README) | [spike-debug-spec](spike-debug-spec/) | [spike-debug-spec.tar.gz](spike-debug-spec.tar.gz) |
| [riscv-isa-sim#2527](https://github.com/riscv-software-src/riscv-isa-sim/issues/2527) | [spike-resumereq-running](spike-resumereq-running/) | [spike-resumereq-running.tar.gz](spike-resumereq-running.tar.gz) |
| [riscv-isa-sim#2530](https://github.com/riscv-software-src/riscv-isa-sim/issues/2530) | [spike-ss-gstage](spike-ss-gstage/) | [spike-ss-gstage.tar.gz](spike-ss-gstage.tar.gz) |
| [riscv-isa-sim#2531](https://github.com/riscv-software-src/riscv-isa-sim/issues/2531) | [spike-vgein-stale-vseip](spike-vgein-stale-vseip/) | [spike-vgein-stale-vseip.tar.gz](spike-vgein-stale-vseip.tar.gz) |
| [riscv-isa-sim#2534](https://github.com/riscv-software-src/riscv-isa-sim/issues/2534) | [spike-dte0-sie](spike-dte0-sie/) | [spike-dte0-sie.tar.gz](spike-dte0-sie.tar.gz) |
| [riscv-isa-sim#2535](https://github.com/riscv-software-src/riscv-isa-sim/issues/2535) | [spike-sireg-counter-write](spike-sireg-counter-write/) | [spike-sireg-counter-write.tar.gz](spike-sireg-counter-write.tar.gz) |
| [riscv-isa-sim#2536](https://github.com/riscv-software-src/riscv-isa-sim/issues/2536) | [spike-scountinhibit-nondeleg-write](spike-scountinhibit-nondeleg-write/) | [spike-scountinhibit-nondeleg-write.tar.gz](spike-scountinhibit-nondeleg-write.tar.gz) |
| [riscv-isa-sim#2537](https://github.com/riscv-software-src/riscv-isa-sim/issues/2537) | [spike-scountinhibit-vs-vu-cause](spike-scountinhibit-vs-vu-cause/) | [spike-scountinhibit-vs-vu-cause.tar.gz](spike-scountinhibit-vs-vu-cause.tar.gz) |
| [riscv-isa-sim#2538](https://github.com/riscv-software-src/riscv-isa-sim/issues/2538) | [spike-mvien-hvien-lcofi](spike-mvien-hvien-lcofi/) | [spike-mvien-hvien-lcofi.tar.gz](spike-mvien-hvien-lcofi.tar.gz) |
| [riscv-isa-sim#2539](https://github.com/riscv-software-src/riscv-isa-sim/issues/2539) | [spike-rv32-sireg5-hpmevent31h](spike-rv32-sireg5-hpmevent31h/) | [spike-rv32-sireg5-hpmevent31h.tar.gz](spike-rv32-sireg5-hpmevent31h.tar.gz) |
| [riscv-isa-sim#2540](https://github.com/riscv-software-src/riscv-isa-sim/issues/2540) | [spike-sireg2-cyclecfg-minh](spike-sireg2-cyclecfg-minh/) | [spike-sireg2-cyclecfg-minh.tar.gz](spike-sireg2-cyclecfg-minh.tar.gz) |
| [riscv-isa-sim#2595](https://github.com/riscv-software-src/riscv-isa-sim/issues/2595) | [spike-hvictl-vti-exception-to-vs](spike-hvictl-vti-exception-to-vs/) | [spike-hvictl-vti-exception-to-vs.tar.gz](spike-hvictl-vti-exception-to-vs.tar.gz) |
| [riscv-isa-sim#2596](https://github.com/riscv-software-src/riscv-isa-sim/issues/2596) | [spike-hvictl-vti-iid-abort](spike-hvictl-vti-iid-abort/) | [spike-hvictl-vti-iid-abort.tar.gz](spike-hvictl-vti-iid-abort.tar.gz) |
| [riscv-isa-sim#2597](https://github.com/riscv-software-src/riscv-isa-sim/issues/2597) | [spike-mvien-sip-hs-delegation](spike-mvien-sip-hs-delegation/) | [spike-mvien-sip-hs-delegation.tar.gz](spike-mvien-sip-hs-delegation.tar.gz) |
| [riscv-isa-sim#2598](https://github.com/riscv-software-src/riscv-isa-sim/issues/2598) | [spike-rv32-mip-seip-latch](spike-rv32-mip-seip-latch/) | [spike-rv32-mip-seip-latch.tar.gz](spike-rv32-mip-seip-latch.tar.gz) |
| [riscv-isa-sim#2599](https://github.com/riscv-software-src/riscv-isa-sim/issues/2599) | [spike-imsic-reserved-selects](spike-imsic-reserved-selects/) | [spike-imsic-reserved-selects.tar.gz](spike-imsic-reserved-selects.tar.gz) |
| [riscv-isa-sim#2600](https://github.com/riscv-software-src/riscv-isa-sim/issues/2600) | [spike-amo-imsic-aplic](spike-amo-imsic-aplic/) | [spike-amo-imsic-aplic.tar.gz](spike-amo-imsic-aplic.tar.gz) |
| [riscv-isa-sim#2601](https://github.com/riscv-software-src/riscv-isa-sim/issues/2601) | [spike-aplic-inactive-source-state](spike-aplic-inactive-source-state/) | [spike-aplic-inactive-source-state.tar.gz](spike-aplic-inactive-source-state.tar.gz) |
| [riscv-isa-sim#2602](https://github.com/riscv-software-src/riscv-isa-sim/issues/2602) | [spike-aplic-msi-pending-lost](spike-aplic-msi-pending-lost/) | [spike-aplic-msi-pending-lost.tar.gz](spike-aplic-msi-pending-lost.tar.gz) |
| [riscv-isa-sim#2603](https://github.com/riscv-software-src/riscv-isa-sim/issues/2603) | [spike-aplic-eiid0-abort](spike-aplic-eiid0-abort/) | [spike-aplic-eiid0-abort.tar.gz](spike-aplic-eiid0-abort.tar.gz) |
| [riscv-isa-sim#2604](https://github.com/riscv-software-src/riscv-isa-sim/issues/2604) | [spike-aplic-reserved-bits](spike-aplic-reserved-bits/) | [spike-aplic-reserved-bits.tar.gz](spike-aplic-reserved-bits.tar.gz) |
| [riscv-isa-sim#2617](https://github.com/riscv-software-src/riscv-isa-sim/issues/2617) | [spike-rv32-midelegh-virtual-instruction](spike-rv32-midelegh-virtual-instruction/) | [spike-rv32-midelegh-virtual-instruction.tar.gz](spike-rv32-midelegh-virtual-instruction.tar.gz) |
