/* vu.c: the verified C functions of experiment #5 for VST. The interface
   is ../proto.h. clightgen translates this file to Clight (vu.v),
   verif_vu.v proves each function against its VST funspec, and CompCert
   (ccomp) compiles it for linking with caller/caller.c.

   The client's function pointers are called directly from the verified
   C: VST gives each one a funspec (the client contract) through
   func_ptr' in the precondition. There is no shim.

   The code is written for VST's Clight subset: one function call or one
   memory access per expression, and early returns instead of switch,
   && and ||. The upstream rules modelled here are cited in
   ../proto.h. */

#include <limits.h>
#include "proto.h"

int vu_char_len(vu_enc_len_fn f, const unsigned char *p,
                const vu_enc_state *st) {
  int r, lo, hi;
  r = f(p);
  lo = st->min_enc_len;
  hi = st->max_enc_len;
  /* CLAMP-BEGIN */
  if (r < lo)
    return lo;
  if (r > hi)
    return hi;
  /* CLAMP-END */
  return r;
}

int vu_callout_step(int dir, vu_callout_fn f, vu_args *args,
                    void *user_data) {
  int r;
  if (dir < VU_DIR_PROGRESS)
    return VU_ERR_INVALID_ARGUMENT;
  if (dir > VU_DIR_EACH_MATCH)
    return VU_ERR_INVALID_ARGUMENT;
  r = f(args, user_data);
  if (r < 0)
    return r;
  if (dir == VU_DIR_EACH_MATCH)
    return VU_ACT_BACKTRACK;
  if (r == VU_CALLOUT_SUCCESS)
    return VU_ACT_CONTINUE;
  if (r == VU_CALLOUT_FAIL) {
    if (dir == VU_DIR_PROGRESS)
      return VU_ACT_BACKTRACK;
    return VU_ACT_CONTINUE;
  }
  return VU_ERR_INVALID_ARGUMENT;
}

int vu_i_apply(unsigned int from, unsigned int *to, int to_len, void *arg) {
  vu_fold_rec *rec = arg;
  int calls, recorded;
  (void)to;
  calls = rec->calls;
  if (calls < INT_MAX)
    rec->calls = calls + 1;
  recorded = rec->recorded;
  if (to_len < 1)
    return 0;
  if (to_len > VU_MAX_TO_LEN)
    return 0;
  if (recorded < 0)
    return 0;
  if (recorded >= VU_FOLD_REC_MAX)
    return 0;
  rec->from[recorded] = from;
  rec->recorded = recorded + 1;
  return 0;
}

int vu_fold_all(vu_apply_all_fn g, vu_fold_rec *rec) {
  int r;
  r = g(vu_i_apply, rec);
  return r;
}

int vu_get_slot(const vu_args *args, int k, int64_t *v) {
  int64_t x;
  if (k < 0)
    return VU_ERR_INVALID_ARGUMENT;
  if (k >= VU_SLOT_NUM)
    return VU_ERR_INVALID_ARGUMENT;
  x = args->slot[k];
  *v = x;
  return 0;
}

int vu_set_slot(vu_args *args, int k, int64_t v) {
  if (k < 0)
    return VU_ERR_INVALID_ARGUMENT;
  if (k >= VU_SLOT_NUM)
    return VU_ERR_INVALID_ARGUMENT;
  args->slot[k] = v;
  return 0;
}
