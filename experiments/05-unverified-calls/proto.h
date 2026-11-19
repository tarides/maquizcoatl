/* proto.h: the C interface every experiment #5 prototype implements.

   Each tool exports the six verified functions declared at the end of
   this file with C linkage, and caller/caller.c is linked against the
   result. The shapes follow the libonig API at f95747b:

   - vu_enc_len_fn: mbc_enc_len, upstream/src/oniguruma.h:131;
   - vu_callout_fn: OnigCalloutFunc, upstream/src/oniguruma.h:771 (the
     each-match callback, upstream/src/oniguruma.h:738, is modelled with
     the same type and its own branch rule);
   - vu_apply_fn, vu_apply_all_fn: OnigApplyAllCaseFoldFunc and the
     apply_all_case_fold member, upstream/src/oniguruma.h:128 and :140,
     with the case fold flag dropped;
   - vu_get_slot, vu_set_slot: onig_get_callout_data_by_callout_args and
     onig_set_callout_data_by_callout_args,
     upstream/src/oniguruma.h:1063 and :1069, reduced to one callout and
     one value type.

   The constants keep upstream's values so that a prototype's results can
   be compared with upstream's behaviour directly. */

#ifndef VU_PROTO_H
#define VU_PROTO_H

#include <stdint.h>

/* ONIG_CALLOUT_SUCCESS and ONIG_CALLOUT_FAIL,
   upstream/src/oniguruma.h:774-777. */
#define VU_CALLOUT_SUCCESS 0
#define VU_CALLOUT_FAIL 1

/* ONIG_MISMATCH and ONIGERR_INVALID_ARGUMENT,
   upstream/src/oniguruma.h:566 and :588. */
#define VU_MISMATCH (-1)
#define VU_ERR_INVALID_ARGUMENT (-30)

/* ONIG_CALLOUT_DATA_SLOT_NUM, upstream/src/oniguruma.h:766. */
#define VU_SLOT_NUM 5

/* ONIGENC_MAX_COMP_CASE_FOLD_CODE_LEN, upstream/src/oniguruma.h:104:
   the largest to_len an apply-all-case-fold callback is given. */
#define VU_MAX_TO_LEN 3

/* Capacity of the record kept by vu_i_apply. */
#define VU_FOLD_REC_MAX 8

/* Direction argument of vu_callout_step. */
#define VU_DIR_PROGRESS 0   /* upstream/src/regexec.c:4615-4632 */
#define VU_DIR_RETRACTION 1 /* upstream/src/regexec.c:1218-1234 */
#define VU_DIR_EACH_MATCH 2 /* upstream/src/regexec.c:3387-3400 */

/* Result of vu_callout_step: an action, or a negative value. */
#define VU_ACT_CONTINUE 0
#define VU_ACT_BACKTRACK 1

/* Client function types. */
typedef int (*vu_enc_len_fn)(const unsigned char *p);

typedef struct vu_args vu_args;
typedef int (*vu_callout_fn)(vu_args *args, void *user_data);

typedef int (*vu_apply_fn)(unsigned int from, unsigned int *to, int to_len,
                           void *arg);
typedef int (*vu_apply_all_fn)(vu_apply_fn f, void *arg);

/* Encoding bounds, the min_enc_len and max_enc_len members of
   OnigEncodingType (upstream/src/oniguruma.h:133-134). Precondition of
   vu_char_len: 1 <= min_enc_len <= max_enc_len. */
typedef struct vu_enc_state {
  int min_enc_len;
  int max_enc_len;
} vu_enc_state;

/* Stand-in for OnigCalloutArgs (upstream/src/regexec.c:1337). The layout is
   fixed here so that every tool produces the same ABI, but the client's
   callouts treat it as opaque: they read and write it only through
   vu_get_slot and vu_set_slot. The first four members are the verified
   side's state (a read-only view of the subject and the matcher's
   position and callout number); only the slots may change across a
   callout. */
struct vu_args {
  const unsigned char *subject;
  int subject_len;
  int pos;
  int num;
  int64_t slot[VU_SLOT_NUM];
};

/* Record kept by vu_i_apply. */
typedef struct vu_fold_rec {
  int calls;                         /* calls seen, saturating */
  int recorded;                      /* entries used in from[] */
  unsigned int from[VU_FOLD_REC_MAX];
} vu_fold_rec;

/* Verified functions. */

/* f(p), clamped to [st->min_enc_len, st->max_enc_len]. */
int vu_char_len(vu_enc_len_fn f, const unsigned char *p,
                const vu_enc_state *st);

/* Calls f(args, user_data) and returns VU_ACT_CONTINUE,
   VU_ACT_BACKTRACK or a negative value according to dir and f's result
   (see lab/results/2026-11-19-exp-05-harness.md for the rules). An
   unknown dir returns VU_ERR_INVALID_ARGUMENT without calling f.
   Negative results of f are passed through unchanged. VU_MISMATCH (-1)
   among them is not an error: upstream's search loop takes it as "no
   match at this start position" and moves on
   (upstream/src/regexec.c:5720-5727); -2 and below end the search. */
int vu_callout_step(int dir, vu_callout_fn f, vu_args *args,
                    void *user_data);

/* Re-entrancy shape (a). vu_i_apply is the verified function handed to
   the client: arg must point to a vu_fold_rec. It increments calls
   (saturating at INT_MAX) and, when 1 <= to_len <= VU_MAX_TO_LEN and the
   record is not full, appends from. It never reads to and returns 0.
   vu_fold_all(g, rec) returns g(vu_i_apply, rec). */
int vu_i_apply(unsigned int from, unsigned int *to, int to_len, void *arg);
int vu_fold_all(vu_apply_all_fn g, vu_fold_rec *rec);

/* Re-entrancy shape (b), called by name from a client callout. Both
   return 0, or VU_ERR_INVALID_ARGUMENT when k is outside
   [0, VU_SLOT_NUM), in which case nothing is read or written. */
int vu_get_slot(const vu_args *args, int k, int64_t *v);
int vu_set_slot(vu_args *args, int k, int64_t v);

#endif /* VU_PROTO_H */
