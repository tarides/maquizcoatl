/* vu.c: the CN prototype of experiment #5 (run E of the pipeline). The
   interface is ../proto.h. CN checks each function against its
   specification (the comments starting with @); the same file is
   compiled by the C compiler for linking with caller/caller.c.

   CN calls a function pointer only when it is provably equal to a
   defined function ("Function pointer must be provably equal to a
   defined function", found in run E), so a client pointer cannot be
   called from verified code. The three indirect calls are in trusted
   shims (vu_shim_*, marked trusted: CN takes their specification and
   does not check their body), as in the Isabelle-LLVM prototype. The
   shims' specifications are the callee contracts. vu_i_apply's address
   is taken in a shim too (re-entrancy shape (a)).

   CN has no read-only (fractional) ownership: what is lent comes back
   whole, and the specification says it comes back unchanged. */

#include <limits.h>
#include <stdint.h>
#include "proto.h"

/*@
function (boolean) rec_wf (struct vu_fold_rec r) {
  0 <= r.calls && 0 <= r.recorded && r.recorded <= 8
}

function (boolean) dir_valid (integer dir) {
  dir == 0 || dir == 1 || dir == 2
}

function (integer) rule (integer dir, integer r) {
  if (dir == 0) {
    if (r == 1) { 1 } else { if (r == 0) { 0 } else { if (r > 0) { -30 } else { r } } }
  } else { if (dir == 1) {
    if (r == 1 || r == 0) { 0 } else { if (r > 0) { -30 } else { r } }
  } else { if (r < 0) { r } else { 1 } } }
}
@*/

/* ------------------------------------------------------------ trusted shims */

/* The encoding function: nothing assumed of its result; it is lent
   nothing (p is passed through). */
int vu_shim_enc_len(vu_enc_len_fn f, const unsigned char *p)
/*@ trusted; @*/
{
  return f(p);
}

/* The callout: it is lent *args and gives it back; nothing is assumed of
   what it writes there (the verified side restores its own fields) nor
   of its result. */
int vu_shim_callout(vu_callout_fn f, vu_args *args, void *user_data)
/*@ trusted;
    requires take A = RW<struct vu_args>(args);
    ensures take B = RW<struct vu_args>(args); @*/
{
  return f(args, user_data);
}

/* The apply-all function, handed vu_i_apply (its address is taken
   here). Client contract: it reaches the record only through
   vu_i_apply, so the record comes back well formed. */
int vu_shim_apply_all(vu_apply_all_fn g, vu_fold_rec *rec)
/*@ trusted;
    requires take R = RW<struct vu_fold_rec>(rec); rec_wf(R);
    ensures take R2 = RW<struct vu_fold_rec>(rec); rec_wf(R2); @*/
{
  return g(vu_i_apply, rec);
}

/* --------------------------------------------------------- verified part */

int vu_char_len(vu_enc_len_fn f, const unsigned char *p,
                const vu_enc_state *st)
/*@ requires take S = RW<struct vu_enc_state>(st);
             1 <= S.min_enc_len; S.min_enc_len <= S.max_enc_len;
    ensures take S2 = RW<struct vu_enc_state>(st); S2 == S;
            S.min_enc_len <= return; return <= S.max_enc_len; @*/
{
  int r, lo, hi;
  r = vu_shim_enc_len(f, p);
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

/* The branch rules of ../proto.h for a valid dir and the callee's result
   r, exactly rule(dir, r). */
static int vu_rule(int dir, int r)
/*@ ensures return == rule(dir, r); @*/
{
  if (dir == VU_DIR_PROGRESS) {
    if (r == VU_CALLOUT_FAIL)
      return VU_ACT_BACKTRACK;
    if (r == VU_CALLOUT_SUCCESS)
      return VU_ACT_CONTINUE;
    if (r > 0)
      return VU_ERR_INVALID_ARGUMENT;
    return r;
  }
  if (dir == VU_DIR_RETRACTION) {
    if (r == VU_CALLOUT_FAIL || r == VU_CALLOUT_SUCCESS)
      return VU_ACT_CONTINUE;
    if (r > 0)
      return VU_ERR_INVALID_ARGUMENT;
    return r;
  }
  if (r < 0)
    return r;
  return VU_ACT_BACKTRACK;
}

/* Calls the callout once (valid dir) or not at all, keeps its own copy
   of the verified side's fields and writes it back. The postcondition
   cannot name the callee's raw result (CN has no ghost return value
   here): it says the result is an action, the invalid-argument error or
   a negative value; vu_rule's specification gives the exact rule. */
int vu_callout_step(int dir, vu_callout_fn f, vu_args *args,
                    void *user_data)
/*@ requires take A = RW<struct vu_args>(args);
    ensures take B = RW<struct vu_args>(args);
            ptr_eq(B.subject, A.subject); B.subject_len == A.subject_len;
            B.pos == A.pos; B.num == A.num;
            if (dir_valid(dir)) { return == 0 || return == 1 || return < 0 }
            else { return == -30 }; @*/
{
  int r;
  const unsigned char *subject;
  int subject_len, pos, num;
  if (dir < VU_DIR_PROGRESS)
    return VU_ERR_INVALID_ARGUMENT;
  if (dir > VU_DIR_EACH_MATCH)
    return VU_ERR_INVALID_ARGUMENT;
  subject = args->subject;
  subject_len = args->subject_len;
  pos = args->pos;
  num = args->num;
  r = vu_shim_callout(f, args, user_data);
  args->subject = subject;
  args->subject_len = subject_len;
  args->pos = pos;
  args->num = num;
  return vu_rule(dir, r);
}

int vu_i_apply(unsigned int from, unsigned int *to, int to_len, void *arg)
/*@ requires take R = RW<struct vu_fold_rec>(arg);
    ensures take R2 = RW<struct vu_fold_rec>(arg);
            return == 0;
            if (R.calls < 2147483647) { R2.calls == R.calls + 1 } else { R2.calls == R.calls };
            if (1 <= to_len && to_len <= 3 && 0 <= R.recorded && R.recorded < 8)
              { R2.recorded == R.recorded + 1 && R2.from[R.recorded] == from }
            else { R2.recorded == R.recorded };
            rec_wf(R) implies rec_wf(R2); @*/
{
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
  /*@ focus RW<unsigned int>, recorded; @*/
  rec->from[recorded] = from;
  rec->recorded = recorded + 1;
  return 0;
}

int vu_fold_all(vu_apply_all_fn g, vu_fold_rec *rec)
/*@ requires take R = RW<struct vu_fold_rec>(rec); rec_wf(R);
    ensures take R2 = RW<struct vu_fold_rec>(rec); rec_wf(R2); @*/
{
  return vu_shim_apply_all(g, rec);
}

int vu_get_slot(const vu_args *args, int k, int64_t *v)
/*@ requires take A = RW<struct vu_args>(args); take V = RW<int64_t>(v);
    ensures take A2 = RW<struct vu_args>(args); take V2 = RW<int64_t>(v);
            A2 == A;
            if (0 <= k && k < 5) { return == 0 && V2 == A.slot[k] }
            else { return == -30 && V2 == V }; @*/
{
  int64_t x;
  if (k < 0)
    return VU_ERR_INVALID_ARGUMENT;
  if (k >= VU_SLOT_NUM)
    return VU_ERR_INVALID_ARGUMENT;
  /*@ focus RW<int64_t>, k; @*/
  x = args->slot[k];
  *v = x;
  return 0;
}

int vu_set_slot(vu_args *args, int k, int64_t v)
/*@ requires take A = RW<struct vu_args>(args);
    ensures take A2 = RW<struct vu_args>(args);
            ptr_eq(A2.subject, A.subject); A2.subject_len == A.subject_len;
            A2.pos == A.pos; A2.num == A.num;
            if (0 <= k && k < 5) {
              return == 0 && A2.slot[k] == v
              && (k == 0 || A2.slot[0] == A.slot[0])
              && (k == 1 || A2.slot[1] == A.slot[1])
              && (k == 2 || A2.slot[2] == A.slot[2])
              && (k == 3 || A2.slot[3] == A.slot[3])
              && (k == 4 || A2.slot[4] == A.slot[4]) }
            else { return == -30 && A2.slot == A.slot }; @*/
{
  if (k < 0)
    return VU_ERR_INVALID_ARGUMENT;
  if (k >= VU_SLOT_NUM)
    return VU_ERR_INVALID_ARGUMENT;
  /*@ focus RW<int64_t>, k; @*/
  args->slot[k] = v;
  return 0;
}

/* The subject is lent whole (no read-only share in CN) and comes back
   with the same bytes. */
int vu_get_subject_byte(const vu_args *args, int i)
/*@ requires take A = RW<struct vu_args>(args);
             0 <= A.subject_len;
             take S = each (integer j; 0 <= j && j < A.subject_len)
                        { RW<unsigned char>(array_shift<unsigned char>(A.subject, j)) };
    ensures take A2 = RW<struct vu_args>(args); A2 == A;
            take S2 = each (integer j; 0 <= j && j < A.subject_len)
                        { RW<unsigned char>(array_shift<unsigned char>(A.subject, j)) };
            S2 == S;
            if (0 <= i && i < A.subject_len) { return == S[i] }
            else { return == -30 }; @*/
{
  const unsigned char *s;
  unsigned char b;
  int len, c;
  if (i < 0)
    return VU_ERR_INVALID_ARGUMENT;
  len = args->subject_len;
  /* READ-BEGIN */
  if (i >= len)
    return VU_ERR_INVALID_ARGUMENT;
  /* READ-END */
  s = args->subject;
  /*@ focus RW<unsigned char>, i; @*/
  /*@ instantiate i; @*/
  b = s[i];
  c = b;
  return c;
}
