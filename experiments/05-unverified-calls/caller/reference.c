/* reference.c: unverified pure-C implementation of the functions of
   proto.h. It fixes the expected behaviour before any tool runs: linked
   with caller.c, it must print caller/expected.txt exactly. */

#include <limits.h>
#include "proto.h"

int vu_char_len(vu_enc_len_fn f, const unsigned char *p,
                const vu_enc_state *st) {
  int r = f(p);
  if (r < st->min_enc_len)
    return st->min_enc_len;
  if (r > st->max_enc_len)
    return st->max_enc_len;
  return r;
}

int vu_callout_step(int dir, vu_callout_fn f, vu_args *args,
                    void *user_data) {
  int r;
  switch (dir) {
  case VU_DIR_PROGRESS:
    r = f(args, user_data);
    if (r == VU_CALLOUT_FAIL)
      return VU_ACT_BACKTRACK;
    if (r == VU_CALLOUT_SUCCESS)
      return VU_ACT_CONTINUE;
    return r > 0 ? VU_ERR_INVALID_ARGUMENT : r;
  case VU_DIR_RETRACTION:
    r = f(args, user_data);
    if (r == VU_CALLOUT_FAIL || r == VU_CALLOUT_SUCCESS)
      return VU_ACT_CONTINUE;
    return r > 0 ? VU_ERR_INVALID_ARGUMENT : r;
  case VU_DIR_EACH_MATCH:
    r = f(args, user_data);
    return r < 0 ? r : VU_ACT_BACKTRACK;
  default:
    return VU_ERR_INVALID_ARGUMENT;
  }
}

int vu_i_apply(unsigned int from, unsigned int *to, int to_len, void *arg) {
  vu_fold_rec *rec = arg;
  (void)to;
  if (rec->calls < INT_MAX)
    rec->calls++;
  if (1 <= to_len && to_len <= VU_MAX_TO_LEN && 0 <= rec->recorded &&
      rec->recorded < VU_FOLD_REC_MAX) {
    rec->from[rec->recorded] = from;
    rec->recorded++;
  }
  return 0;
}

int vu_fold_all(vu_apply_all_fn g, vu_fold_rec *rec) {
  return g(vu_i_apply, rec);
}

int vu_get_slot(const vu_args *args, int k, int64_t *v) {
  if (k < 0 || k >= VU_SLOT_NUM)
    return VU_ERR_INVALID_ARGUMENT;
  *v = args->slot[k];
  return 0;
}

int vu_set_slot(vu_args *args, int k, int64_t v) {
  if (k < 0 || k >= VU_SLOT_NUM)
    return VU_ERR_INVALID_ARGUMENT;
  args->slot[k] = v;
  return 0;
}
