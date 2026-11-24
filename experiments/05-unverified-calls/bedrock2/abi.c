/* abi.c: the trusted ABI wrapper of the Bedrock2 prototype.

   Bedrock2 functions take and return machine words (br_word_t, that is
   uintptr_t), so proto.h's functions are defined here as wrappers that
   convert their arguments to words and the result back to int. An int
   argument is sign-extended (the specifications of VU.v take it as a
   word whose signed value is in the int range); an unsigned int is
   zero-extended; a pointer, a function pointer and an int64_t keep
   their bits. The result is truncated to int: VU.v proves that it is in
   the int range. */

#include <stdint.h>
#include "proto.h"
#include "b2ext.h"

int vu_char_len(vu_enc_len_fn f, const unsigned char *p,
                const vu_enc_state *st) {
  return (int)b2_vu_char_len((uintptr_t)f, (uintptr_t)p, (uintptr_t)st);
}

int vu_callout_step(int dir, vu_callout_fn f, vu_args *args,
                    void *user_data) {
  return (int)b2_vu_callout_step((uintptr_t)(intptr_t)dir, (uintptr_t)f,
                                 (uintptr_t)args, (uintptr_t)user_data);
}

int vu_i_apply(unsigned int from, unsigned int *to, int to_len, void *arg) {
  return (int)b2_vu_i_apply((uintptr_t)from, (uintptr_t)to,
                            (uintptr_t)(intptr_t)to_len, (uintptr_t)arg);
}

int vu_fold_all(vu_apply_all_fn g, vu_fold_rec *rec) {
  return (int)b2_vu_fold_all((uintptr_t)g, (uintptr_t)rec);
}

int vu_get_slot(const vu_args *args, int k, int64_t *v) {
  return (int)b2_vu_get_slot((uintptr_t)args, (uintptr_t)(intptr_t)k,
                             (uintptr_t)v);
}

int vu_set_slot(vu_args *args, int k, int64_t v) {
  return (int)b2_vu_set_slot((uintptr_t)args, (uintptr_t)(intptr_t)k,
                             (uintptr_t)v);
}

int vu_get_subject_byte(const vu_args *args, int i) {
  return (int)b2_vu_get_subject_byte((uintptr_t)args,
                                     (uintptr_t)(intptr_t)i);
}
