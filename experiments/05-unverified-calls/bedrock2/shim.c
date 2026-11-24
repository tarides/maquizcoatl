/* shim.c: the trusted C shim of the Bedrock2 prototype.

   Bedrock2's language calls functions by name only (cmd.call) and
   reaches anything else through cmd.interact, an external action whose
   behaviour the proofs take from ext_spec; ToCString prints an action
   as a C call to a function of the action's name. These three functions
   are those actions: each makes one indirect call to a client function
   and returns the callee's raw int result, sign-extended to a word. The
   clamping and branching stay in the verified code. VU.v states each
   action's contract (the callee contract) as a hypothesis of its
   theorems. vu_call_apply_all also takes the address of the verified
   vu_i_apply (abi.c's wrapper of b2_vu_i_apply), which Bedrock2 cannot
   express (re-entrancy shape (a)). */

#include <stdint.h>
#include "proto.h"
#include "b2ext.h"

uintptr_t vu_call_enc_len(uintptr_t f, uintptr_t p) {
  return (uintptr_t)(intptr_t)((vu_enc_len_fn)f)((const unsigned char *)p);
}

uintptr_t vu_call_callout(uintptr_t f, uintptr_t args, uintptr_t user_data) {
  return (uintptr_t)(intptr_t)((vu_callout_fn)f)((vu_args *)args,
                                                  (void *)user_data);
}

uintptr_t vu_call_apply_all(uintptr_t g, uintptr_t rec) {
  return (uintptr_t)(intptr_t)((vu_apply_all_fn)g)(vu_i_apply, (void *)rec);
}
