// mstateen0.CSRIND = 0: every access to siselect, sireg*, vsiselect, vsireg* from below M-mode raises
// illegal-instruction (cause 2), including VS/VU accesses that are otherwise virtual-instruction
// (src/priv/smcsrind.adoc, norm:Sscsrind_csrs_access_control; the section's rules "take precedence"
// when Smstateen is implemented).
#include "common.h"
  START
  STATEEN_ALL
  STATEEN csrc, MSTATEEN0, MSTATEEN0H
  CASE 1, S, 0, 2, csrr a1, SISELECT     // HS siselect (control)
  CASE 2, U, 1, 2, csrr a1, SISELECT     // VU siselect
  CASE 3, U, 1, 2, csrr a1, SIREG        // VU sireg
  CASE 4, S, 1, 2, csrr a1, SIREG        // VS sireg
  CASE 5, S, 1, 2, csrr a1, VSISELECT    // VS vsiselect
  CASE 6, S, 1, 2, csrr a1, VSIREG       // VS vsireg
  CASE 7, U, 1, 2, csrr a1, VSISELECT    // VU vsiselect
  STATEEN csrs, MSTATEEN0, MSTATEEN0H
  CASE 8, U, 1, 22, csrr a1, SIREG       // control: VU sireg with CSRIND = 1 is virtual-instruction
  FINISH
