(* VU.fst: the four verified functions of experiment #5 in F* + Pulse,
   extracted to C with KaRaMeL. The C interface is ../proto.h; the C
   names come from krml's -no-prefix VU.

   A client C function pointer is a Pulse function-typed argument
   (x:t -> stt r pre post): its type is the client's contract, assumed
   by the verified code and checked nowhere, since the client is C.
   KaRaMeL extracts such an argument to a C function pointer.

   The upstream rules modelled here are cited in ../proto.h and in
   lab/results/2026-11-19-exp-05-harness.md. *)
module VU
#lang-pulse
open Pulse.Lib.Pervasives
module U8 = FStar.UInt8
module U32 = FStar.UInt32
module I32 = FStar.Int32
module I64 = FStar.Int64

(* ------------------------------------------------------------------
   Constants of proto.h *)

inline_for_extraction noextract let callout_success : I32.t = 0l
inline_for_extraction noextract let callout_fail : I32.t = 1l
inline_for_extraction noextract let err_invalid_argument : I32.t = -30l
inline_for_extraction noextract let dir_progress : I32.t = 0l
inline_for_extraction noextract let dir_retraction : I32.t = 1l
inline_for_extraction noextract let dir_each_match : I32.t = 2l
inline_for_extraction noextract let act_continue : I32.t = 0l
inline_for_extraction noextract let act_backtrack : I32.t = 1l
noextract let slot_num : nat = 5
noextract let max_to_len : nat = 3
noextract let fold_rec_max : nat = 8

(* ------------------------------------------------------------------
   Data types. Their C layout must equal proto.h's; layout.sh checks it.
   F* records cannot hold an inline C array, so the arrays of proto.h
   (int64_t slot[5], unsigned int from[8]) are written as consecutive
   scalar fields of the same type, which have the same layout. *)

(* vu_enc_state *)
type vu_enc_state = {
  min_enc_len : I32.t;
  max_enc_len : I32.t;
}

(* struct vu_args. subject is a const unsigned char * on the C side. *)
noeq
type vu_args = {
  subject : ref U8.t;
  subject_len : I32.t;
  pos : I32.t;
  num : I32.t;
  slot0 : I64.t;
  slot1 : I64.t;
  slot2 : I64.t;
  slot3 : I64.t;
  slot4 : I64.t;
}

(* vu_fold_rec *)
type vu_fold_rec = {
  calls : I32.t;
  recorded : I32.t;
  from0 : U32.t;
  from1 : U32.t;
  from2 : U32.t;
  from3 : U32.t;
  from4 : U32.t;
  from5 : U32.t;
  from6 : U32.t;
  from7 : U32.t;
}

(* ------------------------------------------------------------------
   Pure views of the records, used by both specifications and code. *)

noextract let slot (a: vu_args) (k: nat{k < slot_num}) : I64.t =
  match k with
  | 0 -> a.slot0 | 1 -> a.slot1 | 2 -> a.slot2 | 3 -> a.slot3 | 4 -> a.slot4

noextract let set_slot (a: vu_args) (k: nat{k < slot_num}) (x: I64.t) : vu_args =
  match k with
  | 0 -> { a with slot0 = x }
  | 1 -> { a with slot1 = x }
  | 2 -> { a with slot2 = x }
  | 3 -> { a with slot3 = x }
  | 4 -> { a with slot4 = x }

(* The verified-side state of vu_args: everything but the slots. *)
let same_state (a b: vu_args) : prop =
  a.subject == b.subject /\ a.subject_len == b.subject_len /\
  a.pos == b.pos /\ a.num == b.num

noextract let from_at (r: vu_fold_rec) (i: nat{i < fold_rec_max}) : U32.t =
  match i with
  | 0 -> r.from0 | 1 -> r.from1 | 2 -> r.from2 | 3 -> r.from3
  | 4 -> r.from4 | 5 -> r.from5 | 6 -> r.from6 | 7 -> r.from7

noextract let set_from (r: vu_fold_rec) (i: nat{i < fold_rec_max}) (x: U32.t)
  : vu_fold_rec =
  match i with
  | 0 -> { r with from0 = x } | 1 -> { r with from1 = x }
  | 2 -> { r with from2 = x } | 3 -> { r with from3 = x }
  | 4 -> { r with from4 = x } | 5 -> { r with from5 = x }
  | 6 -> { r with from6 = x } | 7 -> { r with from7 = x }

let rec_wf (r: vu_fold_rec) : prop =
  0 <= I32.v r.recorded /\ I32.v r.recorded <= fold_rec_max

(* Machine-integer versions for the code (mathematical integers do not
   extract), each proven equal to its view above. *)

let in_slots (k: I32.t) : prop = 0 <= I32.v k /\ I32.v k < slot_num

inline_for_extraction noextract
let slot_at (a: vu_args) (k: I32.t{in_slots k})
  : x: I64.t{x == slot a (I32.v k)} =
  if k = 0l then a.slot0
  else if k = 1l then a.slot1
  else if k = 2l then a.slot2
  else if k = 3l then a.slot3
  else a.slot4

inline_for_extraction noextract
let set_slot_at (a: vu_args) (k: I32.t{in_slots k}) (x: I64.t)
  : b: vu_args{b == set_slot a (I32.v k) x} =
  if k = 0l then { a with slot0 = x }
  else if k = 1l then { a with slot1 = x }
  else if k = 2l then { a with slot2 = x }
  else if k = 3l then { a with slot3 = x }
  else { a with slot4 = x }

inline_for_extraction noextract
let set_from_at (r: vu_fold_rec)
  (i: I32.t{0 <= I32.v i /\ I32.v i < fold_rec_max}) (x: U32.t)
  : s: vu_fold_rec{s == set_from r (I32.v i) x} =
  if i = 0l then { r with from0 = x }
  else if i = 1l then { r with from1 = x }
  else if i = 2l then { r with from2 = x }
  else if i = 3l then { r with from3 = x }
  else if i = 4l then { r with from4 = x }
  else if i = 5l then { r with from5 = x }
  else if i = 6l then { r with from6 = x }
  else { r with from7 = x }

(* calls + 1, saturating at INT_MAX. *)
inline_for_extraction noextract
let incr_sat (c: I32.t) : I32.t =
  if I32.lt c 2147483647l then I32.add c 1l else c

(* ------------------------------------------------------------------
   Specifications, written as relations independent of the code. *)

(* Branch rules on the callee's result r and the returned value res. *)
let progress_rule (r res: int) : prop =
  (r == 1 ==> res == 1) /\ (r == 0 ==> res == 0) /\
  (r > 1 ==> res == -30) /\ (r < 0 ==> res == r)

let retraction_rule (r res: int) : prop =
  ((r == 0 \/ r == 1) ==> res == 0) /\
  (r > 1 ==> res == -30) /\ (r < 0 ==> res == r)

let each_match_rule (r res: int) : prop =
  (r >= 0 ==> res == 1) /\ (r < 0 ==> res == r)

noextract let valid_dir (dir: int) : bool = 0 <= dir && dir <= 2

let step_rule (dir r res: int) : prop =
  (dir == 0 ==> progress_rule r res) /\
  (dir == 1 ==> retraction_rule r res) /\
  (dir == 2 ==> each_match_rule r res)

(* What vu_i_apply does to the record. *)
let i_apply_rule (r r': vu_fold_rec) (from: U32.t) (to_len: int) : prop =
  I32.v r'.calls ==
    (if I32.v r.calls < Int.max_int 32 then I32.v r.calls + 1
     else I32.v r.calls) /\
  (if 1 <= to_len && to_len <= max_to_len &&
      0 <= I32.v r.recorded && I32.v r.recorded < fold_rec_max
   then I32.v r'.recorded == I32.v r.recorded + 1 /\
        from_at r' (I32.v r.recorded) == from /\
        (forall (i: nat{i < fold_rec_max}).
           i <> I32.v r.recorded ==> from_at r' i == from_at r i)
   else r'.recorded == r.recorded /\
        (forall (i: nat{i < fold_rec_max}). from_at r' i == from_at r i))

(* ------------------------------------------------------------------
   1. vu_char_len: the encoding callee. Its contract (type of f): it
   may read the byte p points to (a fraction pm of it, given back), it
   returns some int32_t, nothing else is promised. In particular, no
   range on the result: only the clamp gives the postcondition. *)

fn vu_char_len
  (#pm: perm) (#c: erased U8.t) (#ps: perm) (#s: erased vu_enc_state)
  (f: ((q: ref U8.t) -> stt I32.t (q |-> Frac pm c) (fun _ -> q |-> Frac pm c)))
  (p: ref U8.t)
  (st: ref vu_enc_state)
  preserves p |-> Frac pm c
  preserves st |-> Frac ps s
  requires pure (1 <= I32.v s.min_enc_len /\
                 I32.v s.min_enc_len <= I32.v s.max_enc_len)
  returns res: I32.t
  ensures pure (I32.v s.min_enc_len <= I32.v res /\
                I32.v res <= I32.v s.max_enc_len)
{
  let r = f p;
  let b = !st;
  (* CLAMP-BEGIN *)
  if (I32.lt r b.min_enc_len) { b.min_enc_len }
  else if (I32.gt r b.max_enc_len) { b.max_enc_len }
  else { r }
  (* CLAMP-END *)
}

(* ------------------------------------------------------------------
   2. vu_callout_step: the callout callee. Its contract: it gets the
   whole args record (so that it can call vu_get_slot and vu_set_slot)
   and must give it back with the verified-side state unchanged; only
   the slots may differ. user_data is opaque: the verified side holds
   no permission on it and passes it through. *)

fn vu_callout_step
  (#v: erased vu_args)
  (dir: I32.t)
  (f: ((a: ref vu_args) -> (ud: ref U8.t) ->
       stt I32.t (a |-> reveal v)
                 (fun _ -> exists* v'. (a |-> v') ** pure (same_state v v'))))
  (args: ref vu_args)
  (ud: ref U8.t)
  requires args |-> reveal v
  returns res: I32.t
  ensures exists* v'. (args |-> v') **
    pure (same_state v v' /\
          (valid_dir (I32.v dir) ==>
             (exists (r: I32.t). step_rule (I32.v dir) (I32.v r) (I32.v res))) /\
          (not (valid_dir (I32.v dir)) ==>
             (v' == reveal v /\ res == err_invalid_argument)))
{
  if (dir = dir_progress) {
    let r = f args ud;
    if (r = callout_fail) { act_backtrack }
    else if (r = callout_success) { act_continue }
    else if (I32.gt r 0l) { err_invalid_argument }
    else { r }
  } else if (dir = dir_retraction) {
    let r = f args ud;
    if (r = callout_fail || r = callout_success) { act_continue }
    else if (I32.gt r 0l) { err_invalid_argument }
    else { r }
  } else if (dir = dir_each_match) {
    let r = f args ud;
    if (I32.lt r 0l) { r } else { act_backtrack }
  } else {
    err_invalid_argument
  }
}

(* ------------------------------------------------------------------
   3. Re-entrancy (a): vu_i_apply is handed to the client as a C
   pointer by vu_fold_all. *)

fn vu_i_apply
  (from: U32.t) (to: ref U32.t) (to_len: I32.t) (arg: ref vu_fold_rec)
  (#r: erased vu_fold_rec)
  requires arg |-> reveal r
  returns res: I32.t
  ensures exists* r'. (arg |-> r') **
    pure (res == 0l /\ i_apply_rule r r' from (I32.v to_len) /\
          (rec_wf r ==> rec_wf r'))
{
  let x = !arg;
  let calls' = incr_sat x.calls;
  if (I32.lte 1l to_len && I32.lte to_len 3l &&
      I32.lte 0l x.recorded && I32.lt x.recorded 8l) {
    let y = set_from_at x x.recorded from;
    arg := { y with calls = calls'; recorded = I32.add x.recorded 1l };
    0l
  } else {
    arg := { x with calls = calls' };
    0l
  }
}

(* The type of vu_i_apply, as the client sees it through the pointer. *)
let apply_fn =
  from: U32.t -> to: ref U32.t -> to_len: I32.t -> arg: ref vu_fold_rec ->
  (#r: erased vu_fold_rec) ->
  stt I32.t (arg |-> reveal r)
    (fun res -> exists* r'. (arg |-> r') **
       pure (res == 0l /\ i_apply_rule r r' from (I32.v to_len) /\
             (rec_wf r ==> rec_wf r')))

(* The client's apply_all_case_fold contract: given the verified
   function and the record (well formed), it gives the record back well
   formed. A client that touches the record only through f meets it. *)
fn vu_fold_all
  (g: ((f: apply_fn) -> (arg: ref vu_fold_rec) ->
       stt I32.t (exists* r. (arg |-> r) ** pure (rec_wf r))
                 (fun _ -> exists* r. (arg |-> r) ** pure (rec_wf r))))
  (fr: ref vu_fold_rec)
  (#r: erased vu_fold_rec)
  requires fr |-> reveal r
  requires pure (rec_wf r)
  returns res: I32.t
  ensures exists* r'. (fr |-> r') ** pure (rec_wf r')
{
  let res = g vu_i_apply fr;
  (* Not "g vu_i_apply fr" alone: F* extraction eta-reduces a body that
     is a tail call ending with the function's last parameter, so the C
     function would lose its parameter fr and return g partially
     applied (see probes/eta.sh); abi_check.c catches it. The test
     below is the identity and keeps the call saturated. *)
  if (res = 0l) { 0l } else { res }
}

(* ------------------------------------------------------------------
   4. Re-entrancy (b): accessors called by name from a client callout.
   Out-of-range k: VU_ERR_INVALID_ARGUMENT, nothing read or written. *)

fn vu_get_slot
  (args: ref vu_args) (k: I32.t) (out: ref I64.t)
  (#pa: perm) (#a: erased vu_args) (#w: erased I64.t)
  preserves args |-> Frac pa a
  requires out |-> w
  returns res: I32.t
  ensures exists* w'. (out |-> w') **
    pure (if 0 <= I32.v k && I32.v k < slot_num
          then res == 0l /\ w' == slot a (I32.v k)
          else res == err_invalid_argument /\ w' == reveal w)
{
  if (I32.lte 0l k && I32.lt k 5l) {
    let x = !args;
    out := slot_at x k;
    0l
  } else {
    err_invalid_argument
  }
}

fn vu_set_slot
  (args: ref vu_args) (k: I32.t) (x: I64.t)
  (#a: erased vu_args)
  requires args |-> reveal a
  returns res: I32.t
  ensures exists* a'. (args |-> a') ** pure (same_state a a') **
    pure (if 0 <= I32.v k && I32.v k < slot_num
          then res == 0l /\ a' == set_slot a (I32.v k) x
          else res == err_invalid_argument /\ a' == reveal a)
{
  if (I32.lte 0l k && I32.lt k 5l) {
    let y = !args;
    args := set_slot_at y k x;
    0l
  } else {
    err_invalid_argument
  }
}
