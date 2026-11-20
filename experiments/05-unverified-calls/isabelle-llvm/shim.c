/* shim.c: the trusted C shim of the Isabelle-LLVM prototype.

   Isabelle-LLVM has no function-pointer type, so each indirect call to
   a client function is made here; VU.thy declares these three
   functions as external constants and states their contracts as
   hypotheses of its theorems. The shim does the call and nothing else:
   it returns the callee's raw result, and the clamping and branching
   stay in the verified code. vu_call_apply_all also takes the address
   of the verified vu_i_apply, which VU.thy cannot express (re-entrancy
   shape (a)). */

#include "proto.h"

int vu_call_enc_len(vu_enc_len_fn f, const unsigned char *p) { return f(p); }

int vu_call_callout(vu_callout_fn f, vu_args *args, void *user_data) {
  return f(args, user_data);
}

int vu_call_apply_all(vu_apply_all_fn g, vu_fold_rec *rec) {
  return g(vu_i_apply, rec);
}
