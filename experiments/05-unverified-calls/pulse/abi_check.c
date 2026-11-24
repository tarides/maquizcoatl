/* abi_check.c: compiled with -Werror against the header KaRaMeL
   generates (Custard.h), it fails unless each verified function has the
   arity and parameter types of the mapping below. It guards against an
   extraction that changes a function's arity (see VU.fst, vu_fold_all):
   the C caller includes proto.h only, so the linker would not see it.

   ABI mapping from proto.h to the generated C (trusted, see TRUSTED):
   int -> int32_t, unsigned int -> uint32_t, const unsigned char * ->
   uint8_t *, void *user_data -> uint8_t *, void *arg (vu_apply_fn) ->
   vu_fold_rec *, and the three structs, whose layouts layout.c
   compares. */

#include <limits.h>
#include "Custard.h"

_Static_assert(sizeof(int) == sizeof(int32_t) && INT_MAX == INT32_MAX,
               "int is int32_t");
_Static_assert(sizeof(unsigned int) == sizeof(uint32_t), "unsigned is 32-bit");
_Static_assert(sizeof(void *) == sizeof(uint8_t *), "data pointers");

int32_t (*const abi_char_len)(int32_t (*)(uint8_t *), uint8_t *,
                              vu_enc_state *) = vu_char_len;
int32_t (*const abi_callout_step)(int32_t, int32_t (*)(vu_args *, uint8_t *),
                                  vu_args *, uint8_t *) = vu_callout_step;
int32_t (*const abi_i_apply)(uint32_t, uint32_t *, int32_t,
                             vu_fold_rec *) = vu_i_apply;
int32_t (*const abi_fold_all)(
    int32_t (*)(int32_t (*)(uint32_t, uint32_t *, int32_t, vu_fold_rec *),
                vu_fold_rec *),
    vu_fold_rec *) = vu_fold_all;
int32_t (*const abi_get_slot)(vu_args *, int32_t, int64_t *) = vu_get_slot;
int32_t (*const abi_set_slot)(vu_args *, int32_t, int64_t) = vu_set_slot;
int32_t (*const abi_get_subject_byte)(vu_args *, int32_t) = vu_get_subject_byte;
