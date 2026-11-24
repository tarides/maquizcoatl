/* b2ext.h: the C names of the Bedrock2 prototype's external actions
   (shim.c) and of its verified functions (generated vu.c), for the
   generated code (included with -include) and for abi.c. Bedrock2's C
   output passes and returns every value as a br_word_t (uintptr_t). */
#ifndef VU_B2EXT_H
#define VU_B2EXT_H
#include <stdint.h>

/* The external actions, defined in shim.c. */
uintptr_t vu_call_enc_len(uintptr_t f, uintptr_t p);
uintptr_t vu_call_callout(uintptr_t f, uintptr_t args, uintptr_t user_data);
uintptr_t vu_call_apply_all(uintptr_t g, uintptr_t rec);

/* The verified functions, defined in the generated vu.c. */
uintptr_t b2_vu_char_len(uintptr_t f, uintptr_t p, uintptr_t st);
uintptr_t b2_vu_callout_step(uintptr_t dir, uintptr_t f, uintptr_t a,
                             uintptr_t ud);
uintptr_t b2_vu_i_apply(uintptr_t from, uintptr_t to, uintptr_t tl,
                        uintptr_t a);
uintptr_t b2_vu_fold_all(uintptr_t g, uintptr_t rc);
uintptr_t b2_vu_get_slot(uintptr_t a, uintptr_t k, uintptr_t v);
uintptr_t b2_vu_set_slot(uintptr_t a, uintptr_t k, uintptr_t v);
uintptr_t b2_vu_get_subject_byte(uintptr_t a, uintptr_t i);
#endif
