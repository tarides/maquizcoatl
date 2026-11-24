/* vu.c: the RefinedC prototype of experiment #5 (run E of the
   pipeline). The interface is ../proto.h (vu_rc.h is its annotated
   copy, see there). RefinedC checks each function against its
   specification (the [[rc::...]] attributes); the same file is compiled
   by the C compiler for linking with caller/caller.c.

   The client's function pointers are called directly from the verified
   C: each pointer argument has a function_ptr type, which carries the
   callee's specification (the client contract), as VST's func_ptr'.
   There is no shim, and vu_fold_all hands vu_i_apply, with its proven
   specification, to the client in verified code (re-entrancy shape
   (a)). */

#include <limits.h>
#include <stdint.h>
#include <refinedc.h>
#include "vu_rc.h"

//@rc::inlined_prelude
//@Definition rule (dir r : Z) : Z :=
//@  if bool_decide (dir = 0) then
//@    (if bool_decide (r = 1) then 1 else if bool_decide (r = 0) then 0
//@     else if bool_decide (0 < r) then -30 else r)
//@  else if bool_decide (dir = 1) then
//@    (if bool_decide (r = 1 ∨ r = 0) then 0 else if bool_decide (0 < r) then -30 else r)
//@  else (if bool_decide (r < 0) then r else 1).
//@Definition rec_wf (calls recd : Z) : Prop := 0 ≤ calls ∧ 0 ≤ recd ≤ 8.
//@(* Arithmetic side conditions. The C tests are written "y <= x", not
//@   "x >= y", whose failed branch reaches the automation as
//@   "(x ?= y) = Lt", which lia does not read. *)
//@Ltac vu_lia := unfold rec_wf in *; lia.
//@(* Witness of "∃ r, res = rule dir r": the result itself (a negative
//@   value passed through) or one of 0, 1 and 2, which cover every action
//@   and the invalid-argument error. *)
//@Ltac solve_rule :=
//@  match goal with |- ∃ r, ?a = rule _ r =>
//@    first [ exists a | exists 0 | exists 1 | exists 2 ];
//@    unfold rule; repeat case_bool_decide; lia end.
//@rc::end

/* ------------------------------------------------------------ vu_char_len */

/* The callee contract: it is given p, which it may only pass on (no
   ownership is lent), and returns any int. */
[[rc::parameters("lo : Z", "hi : Z", "p : loc", "st : loc", "q : own_state")]]
[[rc::args("function_ptr<{fn(∀ pp : loc;"
           "   pp @ &own (place pp); True)"
           " → ∃ r : Z, r @ int i32; True}>",
           "p @ &own<place<p>>", "st @ &frac<q, {(lo, hi)} @ vu_enc_state>")]]
[[rc::requires("{1 ≤ lo}", "{lo ≤ hi}")]]
[[rc::exists("r : Z")]]
[[rc::returns("r @ int<i32>")]]
[[rc::ensures("{lo ≤ r ≤ hi}", "frac q st : {(lo, hi)} @ vu_enc_state")]]
int vu_char_len(vu_enc_len_fn f, const unsigned char *p,
                const vu_enc_state *st) {
  int r = f(p);
  /* CLAMP-BEGIN */
  if (r < st->min_enc_len)
    return st->min_enc_len;
  if (r > st->max_enc_len)
    return st->max_enc_len;
  /* CLAMP-END */
  return r;
}

/* -------------------------------------------------------- vu_callout_step */

/* The callee contract: it is lent *args (owned) and gives back some
   vu_args, and user_data, which it may only pass on; it returns any int.
   Nothing is assumed of what it writes into args: the verified side
   keeps its own copy of its fields and writes them back. The result is
   rule(dir, r) for the callee's result r. */
[[rc::parameters("a : loc", "ud : loc", "s : loc", "bs : {list Z}", "pos : Z", "num : Z", "sl : {list Z}", "dir : Z")]]
[[rc::args("dir @ int<i32>",
           "function_ptr<{fn(∀ (pa, pu, av) : loc * loc * (loc * list Z * Z * Z * list Z);"
           "   pa @ &own (av @ vu_args), pu @ &own (place pu); True)"
           " → ∃ (r, av') : Z * (loc * list Z * Z * Z * list Z), r @ int i32;"
           "   pa ◁ₗ av' @ vu_args}>",
           "a @ &own<{(s, bs, pos, num, sl)} @ vu_args>", "ud @ &own<place<ud>>")]]
[[rc::exists("res : Z", "sl2 : {list Z}")]]
[[rc::returns("res @ int<i32>")]]
[[rc::ensures("own a : {(s, bs, pos, num, sl2)} @ vu_args")]]
[[rc::ensures("{0 ≤ dir ≤ 2 → ∃ r, res = rule dir r}", "{¬ (0 ≤ dir ≤ 2) → res = -30}")]]
[[rc::tactics("all: try by solve_rule.")]]
int vu_callout_step(int dir, vu_callout_fn f, vu_args *args,
                    void *user_data) {
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
  r = f(args, user_data);
  args->subject = subject;
  args->subject_len = subject_len;
  args->pos = pos;
  args->num = num;
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

/* --------------------------------------------- vu_i_apply and vu_fold_all */

/* The verified function handed to the client (re-entrancy shape (a)):
   calls saturates at INT_MAX, from is appended when 1 <= to_len <=
   VU_MAX_TO_LEN and the record is not full. to is never read: the
   client may only pass a pointer, no ownership is lent. */
[[rc::parameters("from : Z", "tl : Z", "to : loc", "a : loc", "calls : Z", "recd : Z", "fr : {list Z}")]]
[[rc::args("from @ int<u32>", "to @ &own<place<to>>", "tl @ int<i32>",
           "a @ &own<{(calls, recd, fr)} @ vu_fold_rec>")]]
[[rc::exists("calls2 : Z", "recd2 : Z", "fr2 : {list Z}")]]
[[rc::returns("{0} @ int<i32>")]]
[[rc::ensures("own a : {(calls2, recd2, fr2)} @ vu_fold_rec")]]
[[rc::ensures("{calls < max_int i32 → calls2 = (calls + 1)%Z}", "{max_int i32 ≤ calls → calls2 = calls}")]]
[[rc::ensures("{1 ≤ tl ≤ 3 ∧ 0 ≤ recd < 8 → recd2 = (recd + 1)%Z ∧ fr2 = <[Z.to_nat recd := from]> fr}")]]
[[rc::ensures("{¬ (1 ≤ tl ≤ 3 ∧ 0 ≤ recd < 8) → recd2 = recd ∧ fr2 = fr}")]]
[[rc::ensures("{rec_wf calls recd → rec_wf calls2 recd2}")]]
[[rc::tactics("all: try by vu_lia.")]]
int vu_i_apply(unsigned int from, unsigned int *to, int to_len, void *arg) {
  vu_fold_rec *rec = arg;
  int calls, recorded;
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
  if (VU_FOLD_REC_MAX <= recorded)
    return 0;
  rec->from[recorded] = from;
  rec->recorded = recorded + 1;
  return 0;
}

/* The client contract of the apply-all function: it is given vu_i_apply
   with its proven specification and the record, well formed, and gives
   the record back well formed (it reaches the record only through
   vu_i_apply). */
[[rc::parameters("a : loc", "calls : Z", "recd : Z", "fr : {list Z}")]]
[[rc::args("function_ptr<{fn(∀ (fp, pa, c, d, l) : loc * loc * Z * Z * list Z;"
           "   fp @ function_ptr type_of_vu_i_apply, pa @ &own ((c, d, l) @ vu_fold_rec);"
           "   ⌜rec_wf c d⌝)"
           " → ∃ (r, c', d', l') : Z * Z * Z * list Z, r @ int i32;"
           "   pa ◁ₗ (c', d', l') @ vu_fold_rec ∗ ⌜rec_wf c' d'⌝}>",
           "a @ &own<{(calls, recd, fr)} @ vu_fold_rec>")]]
[[rc::requires("{rec_wf calls recd}")]]
[[rc::exists("r : Z", "calls2 : Z", "recd2 : Z", "fr2 : {list Z}")]]
[[rc::returns("r @ int<i32>")]]
[[rc::ensures("own a : {(calls2, recd2, fr2)} @ vu_fold_rec", "{rec_wf calls2 recd2}")]]
int vu_fold_all(vu_apply_all_fn g, vu_fold_rec *rec) {
  return g(vu_i_apply, rec);
}

/* -------------------------------------------- vu_get_slot and vu_set_slot */

[[rc::parameters("a : loc", "q : own_state", "s : loc", "bs : {list Z}", "pos : Z", "num : Z", "sl : {list Z}",
                 "k : Z", "v : loc", "x : Z")]]
[[rc::args("a @ &frac<q, {(s, bs, pos, num, sl)} @ vu_args>", "k @ int<i32>", "v @ &own<x @ int<i64>>")]]
[[rc::exists("res : Z", "y : Z")]]
[[rc::returns("res @ int<i32>")]]
[[rc::ensures("frac q a : {(s, bs, pos, num, sl)} @ vu_args", "own v : y @ int<i64>")]]
[[rc::ensures("{0 ≤ k < 5 → res = 0 ∧ sl !! Z.to_nat k = Some y}", "{¬ (0 ≤ k < 5) → res = -30 ∧ y = x}")]]
int vu_get_slot(const vu_args *args, int k, int64_t *v) {
  int64_t x;
  if (k < 0)
    return VU_ERR_INVALID_ARGUMENT;
  if (VU_SLOT_NUM <= k)
    return VU_ERR_INVALID_ARGUMENT;
  x = args->slot[k];
  *v = x;
  return 0;
}

[[rc::parameters("a : loc", "s : loc", "bs : {list Z}", "pos : Z", "num : Z", "sl : {list Z}", "k : Z", "v : Z")]]
[[rc::args("a @ &own<{(s, bs, pos, num, sl)} @ vu_args>", "k @ int<i32>", "v @ int<i64>")]]
[[rc::exists("res : Z", "sl2 : {list Z}")]]
[[rc::returns("res @ int<i32>")]]
[[rc::ensures("own a : {(s, bs, pos, num, sl2)} @ vu_args")]]
[[rc::ensures("{0 ≤ k < 5 → res = 0 ∧ sl2 = <[Z.to_nat k := v]> sl}", "{¬ (0 ≤ k < 5) → res = -30 ∧ sl2 = sl}")]]
int vu_set_slot(vu_args *args, int k, int64_t v) {
  if (k < 0)
    return VU_ERR_INVALID_ARGUMENT;
  if (VU_SLOT_NUM <= k)
    return VU_ERR_INVALID_ARGUMENT;
  args->slot[k] = v;
  return 0;
}

/* ----------------------------------------------------- vu_get_subject_byte */

/* The subject is a shared (read-only, persistent) array: vu_args holds
   it as a &shr pointer (vu_rc.h), so the read accessor neither owns nor
   writes it, and nor does the callout it is lent with args. */
[[rc::parameters("a : loc", "q : own_state", "s : loc", "bs : {list Z}", "pos : Z", "num : Z", "sl : {list Z}",
                 "i : Z")]]
[[rc::args("a @ &frac<q, {(s, bs, pos, num, sl)} @ vu_args>", "i @ int<i32>")]]
[[rc::exists("res : Z")]]
[[rc::returns("res @ int<i32>")]]
[[rc::ensures("frac q a : {(s, bs, pos, num, sl)} @ vu_args")]]
[[rc::ensures("{0 ≤ i < length bs → bs !! Z.to_nat i = Some res}", "{¬ (0 ≤ i < length bs) → res = -30}")]]
int vu_get_subject_byte(const vu_args *args, int i) {
  const unsigned char *s;
  int len, c;
  if (i < 0)
    return VU_ERR_INVALID_ARGUMENT;
  len = args->subject_len;
  /* READ-BEGIN */
  if (len <= i)
    return VU_ERR_INVALID_ARGUMENT;
  /* READ-END */
  s = args->subject;
  c = s[i];
  return c;
}
