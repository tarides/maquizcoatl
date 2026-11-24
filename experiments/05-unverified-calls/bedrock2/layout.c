/* layout.c: checks at compile time that proto.h's structs have the
   layout VU.v's memory predicates assume (args_at, rec_at; LP64): the
   offsets below are written by hand from those predicates (trusted). */
#include <stddef.h>
#include <stdint.h>
#include "proto.h"

_Static_assert(sizeof(uintptr_t) == 8, "64-bit words");
_Static_assert(offsetof(vu_args, subject) == 0, "args_at: subject");
_Static_assert(offsetof(vu_args, subject_len) == 8, "args_at: subject_len");
_Static_assert(offsetof(vu_args, pos) == 12, "args_at: pos");
_Static_assert(offsetof(vu_args, num) == 16, "args_at: num");
_Static_assert(offsetof(vu_args, slot) == 24, "args_at: slot");
_Static_assert(sizeof(vu_args) == 64, "args_at: 4 padding bytes at 20");
_Static_assert(offsetof(vu_fold_rec, calls) == 0, "rec_at: calls");
_Static_assert(offsetof(vu_fold_rec, recorded) == 4, "rec_at: recorded");
_Static_assert(offsetof(vu_fold_rec, from) == 8, "rec_at: from");
_Static_assert(sizeof(vu_fold_rec) == 40, "rec_at: size");
_Static_assert(offsetof(vu_enc_state, max_enc_len) == 4, "char_len: st");
