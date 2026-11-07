# Spike: VU-mode `sireg` raises virtual- instead of illegal-instruction when `mstateen0.CSRIND` = 0

Spike f90d5af (riscv-arch-test CI pin); unchanged on master c20813c (2026-11-07).

    spike --isa=rv64gch_smstateen_smcsrind_sscsrind mstateen0_csrind0-spike-rv64.elf; echo $?
    spike --isa=rv32gch_smstateen_smcsrind_sscsrind mstateen0_csrind0-spike-rv32.elf; echo $?
    # rebuild: ./build.sh (riscv64-unknown-elf-gcc)

Expected exit 0. Observed: exit 4 (`*** FAILED *** (tohost = 4)`), i.e. case 3 fails on both XLENs.

The probe runs in M-mode with medeleg = mideleg = 0, sets mstateen0 = hstateen0 = all ones, clears mstateen0.CSRIND
(bit 60; mstateen0h bit 28 on RV32), and enters each mode (VS/VU through an sret from HS-mode) to execute one CSR read.
Exit status = bit mask of failing cases (bit id-1).

| case | mode | access | expected | Spike |
|---|---|---|---|---|
| 1 | HS | siselect | 2 | 2 |
| 2 | VU | siselect | 2 | 2 |
| 3 | VU | sireg | 2 | **22** |
| 4 | VS | sireg | 2 | 2 |
| 5-7 | VS/VU | vsiselect, vsireg | 2 | 2 |
| 8 (control, CSRIND = 1) | VU | sireg | 22 | 22 |

Spec (src/priv/smcsrind.adoc, norm:Sscsrind_csrs_access_control): "When `mstateen0`[60]=0, an attempt to access one of
these CSRs [siselect, sireg*, vsiselect, vsireg*] from a privilege mode less privileged than M-mode results in an
illegal-instruction exception." The section says these requirements take precedence over the virtual-instruction
rules of the preceding section when Smstateen is implemented.

Cause: `virtualized_indirect_csr_t::verify_permissions` (riscv/csrs.cc) calls `virtualized_csr_t::verify_permissions`,
i.e. the generic `csr_t` privilege check, which throws virtual-instruction for VU < S before `sscsrind_reg_csr_t`
checks mstateen0.CSRIND. `siselect` (virtualized_with_special_permission_csr_t) does not do this and is correct.

Already reported as https://github.com/riscv-software-src/riscv-isa-sim/issues/2082, closed as completed on
2025-12-11, but the reported case still fails on master.
