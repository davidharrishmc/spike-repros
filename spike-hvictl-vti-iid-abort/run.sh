#!/bin/sh
# Usage: ./run.sh [path/to/spike]    (default: spike on PATH)
S=${1:-spike}
cd "$(dirname "$0")" || exit 1

echo "=== rv64"
"$S" --instructions=100000000 --isa=rv64imafdcbvh_zicbom_zicboz_zicbop_zicfilp_zicfiss_zicond_zicsr_zicntr_zicclsm_ziccif_zifencei_zihintntl_zihintpause_zihpm_zimop_zabha_zacas_zawrs_zfa_zfbfmin_zfh_zcb_zcmop_zbc_zkn_zks_zkr_zkt_zvfbfmin_zvfbfwma_zvfh_zvbb_zvbc_zvkg_zvkned_zvknha_zvknhb_zvksed_zvksh_zvkt_sscofpmf_smcntrpmf_sstc_svinval_svade_svadu_svnapot_svpbmt_smstateen_smaia_ssaia_smcsrind_sscsrind_ssqosid_ssnpm_smmpm_smnpm_smdbltrp_ssdbltrp_zama16b u30-aia-a-spike-04.spike-rv64-max.elf 2>&1; echo "exit status $?"

echo "=== rv32"
"$S" --instructions=100000000 --isa=rv32imafdcbvh_zicbom_zicboz_zicbop_zicfilp_zicfiss_zicond_zicsr_zicntr_zicclsm_ziccif_zifencei_zihintntl_zihintpause_zihpm_zimop_zabha_zacas_zawrs_zfa_zfbfmin_zfh_zcb_zcmop_zbc_zkn_zks_zkr_zkt_zvfbfmin_zvfbfwma_zvfh_zvbb_zvbc_zvkg_zvkned_zvknha_zvknhb_zvksed_zvksh_zvkt_sscofpmf_smcntrpmf_sstc_svinval_svade_svadu_smstateen_smaia_ssaia_smcsrind_sscsrind_ssqosid_smdbltrp_ssdbltrp_zama16b u30-aia-a-spike-04.spike-rv32-max.elf 2>&1; echo "exit status $?"
