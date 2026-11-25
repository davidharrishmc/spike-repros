// verify v15a, u31-aia-b-T-01 (Whisper, Spike): 32-bit AMOs to APLIC control-region registers must be either
// faulted or ignored; they must never be performed.
// Spec: AIA AdvPLIC.adoc:364-368 "Only naturally aligned 32-bit simple reads and writes are supported within an
//   interrupt domain's control region. Writes to read-only bytes are ignored. For other forms of accesses (other
//   sizes, misaligned accesses, or AMOs), implementations should preferably report an access fault or bus error but
//   must otherwise ignore the access."
// Legal outcomes per AMO: store/AMO access fault (cause 7) or no trap; in both cases no register changes.
// Checks: (all APLIC columns) amoor.w 0x100 to domaincfg (IE = 0) leaves IE = 0;
//         (Whisper boot state only: ADDR_SETIPNUM from rvmodel_macros.h) amoswap.w/amoor.w/amoadd.w of 1 to setipnum
//         leave IP[1] = 0, and amoor.w 2 to clrie[0] leaves IE[1] = 1.
// Source: tests/u31-aia-b/u31-aia-b-access.S (u31-aia-b-0024 0025).

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Zicsr', 'Zaamo']
# MARCH: rv${XLEN}ia_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define MB 0x0C000000
// trap outcome after an AMO: x14 = -1 (no trap) or 7 (store/AMO access fault)
#define OUTCOME_OK(_MSG) AI_OUTCOME; LI(x4, -1); beq x14, x4, 91f; SA_SOFT(x14, 7, _MSG); 91:
// x8 = bit _B of the word at _A
#define ABIT(_A, _B) LI(x6, _A); lw x8, 0(x6); srli x8, x8, _B; andi x8, x8, 1

RVTEST_BEGIN
  csrci mstatus, 8
  csrw mie, x0
  // ---- domaincfg (every APLIC): clear IE with a simple store, then amoor.w 0x100
  LI(x6, MB)
  lw x20, 0(x6)
  li x7, -0x101
  and x7, x20, x7
  sw x7, 0(x6)
  ABIT(MB, 8)
  SA_SOFT(x8, 0, "T01 control: sw clears domaincfg.IE")
  LI(x6, MB)
  li x7, 0x100
  SA_TRY(1)
  amoor.w x9, x7, (x6)
  OUTCOME_OK("T01: amoor.w to domaincfg: no trap or store/AMO access fault (7)")
  ABIT(MB, 8)
  SA_SOFT(x8, 0, "T01: amoor.w 0x100 to domaincfg must not set IE (AdvPLIC.adoc:364-368: fault or ignore)")
  LI(x6, MB)
  sw x20, 0(x6)
#ifdef ADDR_SETIPNUM
  // ---- Whisper boot state: M source 1 Edge1, IE[1] = 1, direct mode
  LI(x6, ADDR_CLRIPNUM)
  li x7, 1
  sw x7, 0(x6)
  ABIT(MB+0x1C00, 1)
  SA_SOFT(x8, 0, "T01 control: IP[1] = 0 after clripnum")
  LI(x6, ADDR_SETIPNUM)
  li x7, 1
  SA_TRY(1)
  amoswap.w x9, x7, (x6)
  OUTCOME_OK("T01: amoswap.w to setipnum: no trap or 7")
  ABIT(MB+0x1C00, 1)
  SA_SOFT(x8, 0, "T01: amoswap.w 1 to setipnum must not set IP[1]")
  LI(x6, ADDR_CLRIPNUM)
  li x7, 1
  sw x7, 0(x6)
  LI(x6, ADDR_SETIPNUM)
  li x7, 1
  SA_TRY(1)
  amoor.w x9, x7, (x6)
  OUTCOME_OK("T01: amoor.w to setipnum: no trap or 7")
  ABIT(MB+0x1C00, 1)
  SA_SOFT(x8, 0, "T01: amoor.w 1 to setipnum must not set IP[1]")
  LI(x6, ADDR_CLRIPNUM)
  li x7, 1
  sw x7, 0(x6)
  LI(x6, ADDR_SETIPNUM)
  li x7, 1
  SA_TRY(1)
  amoadd.w x9, x7, (x6)
  OUTCOME_OK("T01: amoadd.w to setipnum: no trap or 7")
  ABIT(MB+0x1C00, 1)
  SA_SOFT(x8, 0, "T01: amoadd.w 1 to setipnum must not set IP[1]")
  LI(x6, ADDR_CLRIPNUM)
  li x7, 1
  sw x7, 0(x6)
  // clrie[0]
  ABIT(MB+0x1E00, 1)
  SA_SOFT(x8, 1, "T01 control: IE[1] = 1 (boot)")
  LI(x6, MB+0x1F00)
  li x7, 2
  SA_TRY(1)
  amoor.w x9, x7, (x6)
  OUTCOME_OK("T01: amoor.w to clrie[0]: no trap or 7")
  ABIT(MB+0x1E00, 1)
  SA_SOFT(x8, 1, "T01: amoor.w 2 to clrie[0] must not clear IE[1]")
  LI(x6, MB+0x1EDC)
  li x7, 1
  sw x7, 0(x6)
#endif
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
