module Vu
#set-options "--fuel 0 --ifuel 1 --z3rlimit 15"
open FStar.Mul
open Core_models

let v_CALLOUT_SUCCESS: i32 = mk_i32 0

let v_CALLOUT_FAIL: i32 = mk_i32 1

let v_ERR_INVALID_ARGUMENT: i32 = mk_i32 (-30)

let v_SLOT_NUM: i32 = mk_i32 5

let v_MAX_TO_LEN: i32 = mk_i32 3

let v_FOLD_REC_MAX: i32 = mk_i32 8

let v_DIR_PROGRESS: i32 = mk_i32 0

let v_DIR_RETRACTION: i32 = mk_i32 1

let v_DIR_EACH_MATCH: i32 = mk_i32 2

let v_ACT_CONTINUE: i32 = mk_i32 0

let v_ACT_BACKTRACK: i32 = mk_i32 1

/// struct vu_enc_state of proto.h.
type t_VuEncState = {
  f_min_enc_len:i32;
  f_max_enc_len:i32
}

/// struct vu_args of proto.h. The first four fields are the verified
/// side's state; only the slots may change across a callout. subject is
/// the address of the subject (a const unsigned char * in C): hax has no
/// raw pointer type, and the verified side never dereferences it.
type t_VuArgs = {
  f_subject:usize;
  f_subject_len:i32;
  f_pos:i32;
  f_num:i32;
  f_slot:t_Array i64 (mk_usize 5)
}

/// struct vu_fold_rec of proto.h.
type t_VuFoldRec = {
  f_calls:i32;
  f_recorded:i32;
  f_from:t_Array u32 (mk_usize 8)
}

/// The record invariant that vu_i_apply keeps.
let rec_wf (v_rec: t_VuFoldRec) : bool =
  mk_i32 0 <=. v_rec.f_calls && mk_i32 0 <=. v_rec.f_recorded && v_rec.f_recorded <=. v_FOLD_REC_MAX

/// A client vu_enc_len_fn. p (the address of the byte) is passed
/// through, never read here.
class t_EncLen (v_Self: Type0) = {
  f_enc_len_pre:v_Self -> usize -> Type0;
  f_enc_len_post:v_Self -> usize -> i32 -> Type0;
  f_enc_len:x0: v_Self -> x1: usize
    -> Prims.Pure i32 (f_enc_len_pre x0 x1) (fun result -> f_enc_len_post x0 x1 result)
}

/// A client vu_callout_fn with its user_data. The callee is lent args
/// mutably for the call.
class t_Callout (v_Self: Type0) = {
  f_callout_pre:v_Self -> t_VuArgs -> Type0;
  f_callout_post:v_Self -> t_VuArgs -> (t_VuArgs & i32) -> Type0;
  f_callout:x0: v_Self -> x1: t_VuArgs
    -> Prims.Pure (t_VuArgs & i32) (f_callout_pre x0 x1) (fun result -> f_callout_post x0 x1 result)
}

/// Calls the client\'s encoding function f on p and clamps its result to
/// the bounds in st. Nothing is assumed of the callee\'s result. st is a
/// shared reference that the callee is not given, hence unchanged.
let char_len
      (#v_F: Type0)
      (#[FStar.Tactics.Typeclasses.tcresolve ()] i0: t_EncLen v_F)
      (f: v_F)
      (p: usize)
      (st: t_VuEncState)
    : Prims.Pure i32
      (requires mk_i32 1 <=. st.f_min_enc_len && st.f_min_enc_len <=. st.f_max_enc_len)
      (ensures
        fun r ->
          let r:i32 = r in
          st.f_min_enc_len <=. r && r <=. st.f_max_enc_len) =
  let raw:i32 = f_enc_len #v_F #FStar.Tactics.Typeclasses.solve f p in
  if raw <. st.f_min_enc_len
  then st.f_min_enc_len
  else if raw >. st.f_max_enc_len then st.f_max_enc_len else raw

/// The branch rules (lab/results/2026-11-19-exp-05-harness.md), for a
/// valid dir and the callee's result r:
/// - progress, upstream/src/regexec.c:4616-4631: FAIL backtracks,
///   SUCCESS continues, another positive value is
///   ONIGERR_INVALID_ARGUMENT, a negative value is returned;
/// - retraction, upstream/src/regexec.c:1218-1234: FAIL and SUCCESS
///   continue, otherwise as in progress;
/// - each-match, upstream/src/regexec.c:3387-3400: a negative value is
///   returned, anything else backtracks (the search goes on).
let rule (dir r: i32) : i32 =
  if dir =. v_DIR_PROGRESS
  then
    if r =. v_CALLOUT_FAIL
    then v_ACT_BACKTRACK
    else
      if r =. v_CALLOUT_SUCCESS
      then v_ACT_CONTINUE
      else if r >. mk_i32 0 then v_ERR_INVALID_ARGUMENT else r
  else
    if dir =. v_DIR_RETRACTION
    then
      if r =. v_CALLOUT_FAIL || r =. v_CALLOUT_SUCCESS
      then v_ACT_CONTINUE
      else if r >. mk_i32 0 then v_ERR_INVALID_ARGUMENT else r
    else if r <. mk_i32 0 then r else v_ACT_BACKTRACK

let dir_valid (dir: i32) : bool =
  dir =. v_DIR_PROGRESS || dir =. v_DIR_RETRACTION || dir =. v_DIR_EACH_MATCH

/// Calls the client\'s callout f once (valid dir) or not at all (invalid
/// dir). Returns the action and, as a ghost second component that ffi.rs
/// drops, the callee\'s raw result (0 when it is not called): the
/// postcondition ties the action to that result.
/// The callee may write anything into args. The verified side does not
/// trust what it finds there: it keeps its own copy of its state and
/// writes it back, so only the slots carry the callee\'s writes.
let callout_step
      (#v_F: Type0)
      (#[FStar.Tactics.Typeclasses.tcresolve ()] i0: t_Callout v_F)
      (dir: i32)
      (f: v_F)
      (args: t_VuArgs)
    : Prims.Pure (t_VuArgs & (i32 & i32))
      Prims.l_True
      (ensures
        fun temp_0_ ->
          let (args_future: t_VuArgs), (res: (i32 & i32)) = temp_0_ in
          (if dir_valid dir
            then res._1 =. (rule dir res._2 <: i32)
            else res._1 =. v_ERR_INVALID_ARGUMENT) &&
          args_future.f_subject =. args.f_subject &&
          args_future.f_subject_len =. args.f_subject_len &&
          args_future.f_pos =. args.f_pos &&
          args_future.f_num =. args.f_num) =
  if ~.(dir_valid dir <: bool)
  then args, (v_ERR_INVALID_ARGUMENT, mk_i32 0 <: (i32 & i32)) <: (t_VuArgs & (i32 & i32))
  else
    let subject:usize = args.f_subject in
    let subject_len:i32 = args.f_subject_len in
    let pos:i32 = args.f_pos in
    let num:i32 = args.f_num in
    let (tmp0: t_VuArgs), (out: i32) = f_callout #v_F #FStar.Tactics.Typeclasses.solve f args in
    let args:t_VuArgs = tmp0 in
    let r:i32 = out in
    let args:t_VuArgs = { args with f_subject = subject } <: t_VuArgs in
    let args:t_VuArgs = { args with f_subject_len = subject_len } <: t_VuArgs in
    let args:t_VuArgs = { args with f_pos = pos } <: t_VuArgs in
    let args:t_VuArgs = { args with f_num = num } <: t_VuArgs in
    let hax_temp_output:(i32 & i32) = rule dir r, r <: (i32 & i32) in
    args, hax_temp_output <: (t_VuArgs & (i32 & i32))

/// The verified function handed to the client (re-entrancy shape (a),
/// as i_apply_case_fold, upstream/src/regparse.c:8739): calls saturates
/// at i32::MAX, from is appended when 1 <= to_len <= MAX_TO_LEN and the
/// record is not full. It never reads the client\'s to array, which
/// ffi.rs does not pass on.
let ii_apply (from: u32) (to_len: i32) (v_rec: t_VuFoldRec)
    : Prims.Pure (t_VuFoldRec & i32)
      Prims.l_True
      (ensures
        fun temp_0_ ->
          let (rec_future: t_VuFoldRec), (r: i32) = temp_0_ in
          r =. mk_i32 0 &&
          (if v_rec.f_calls <. Core_models.Num.impl_i32__MAX
            then
              (cast (rec_future.f_calls <: i32) <: i64) =.
              ((cast (v_rec.f_calls <: i32) <: i64) +! mk_i64 1 <: i64)
            else rec_future.f_calls =. v_rec.f_calls) &&
          (if
              mk_i32 1 <=. to_len && to_len <=. v_MAX_TO_LEN && mk_i32 0 <=. v_rec.f_recorded &&
              v_rec.f_recorded <. v_FOLD_REC_MAX
            then
              (cast (rec_future.f_recorded <: i32) <: i64) =.
              ((cast (v_rec.f_recorded <: i32) <: i64) +! mk_i64 1 <: i64) &&
              (rec_future.f_from.[ cast (v_rec.f_recorded <: i32) <: usize ] <: u32) =. from
            else rec_future.f_recorded =. v_rec.f_recorded) &&
          (~.(rec_wf v_rec <: bool) || rec_wf rec_future)) =
  let v_rec:t_VuFoldRec =
    if v_rec.f_calls <. Core_models.Num.impl_i32__MAX
    then
      let v_rec:t_VuFoldRec = { v_rec with f_calls = v_rec.f_calls +! mk_i32 1 } <: t_VuFoldRec in
      v_rec
    else v_rec
  in
  let v_rec:t_VuFoldRec =
    if
      mk_i32 1 <=. to_len && to_len <=. v_MAX_TO_LEN && mk_i32 0 <=. v_rec.f_recorded &&
      v_rec.f_recorded <. v_FOLD_REC_MAX
    then
      let v_rec:t_VuFoldRec =
        {
          v_rec with
          f_from
          =
          Rust_primitives.Hax.Monomorphized_update_at.update_at_usize v_rec.f_from
            (cast (v_rec.f_recorded <: i32) <: usize)
            from
        }
        <:
        t_VuFoldRec
      in
      let v_rec:t_VuFoldRec =
        { v_rec with f_recorded = v_rec.f_recorded +! mk_i32 1 } <: t_VuFoldRec
      in
      v_rec
    else v_rec
  in
  let hax_temp_output:i32 = mk_i32 0 in
  v_rec, hax_temp_output <: (t_VuFoldRec & i32)

/// i_apply as an Apply: F* checks its contract against i_apply's.
type t_IApply = | IApply : t_IApply

/// Reads slot k into v; out of bounds, returns ERR_INVALID_ARGUMENT and
/// leaves v untouched.
let get_slot (args: t_VuArgs) (k: i32) (v: i64)
    : Prims.Pure (i64 & i32)
      Prims.l_True
      (ensures
        fun temp_0_ ->
          let (vv_future: i64), (r: i32) = temp_0_ in
          if mk_i32 0 <=. k && k <. v_SLOT_NUM
          then r =. mk_i32 0 && vv_future =. (args.f_slot.[ cast (k <: i32) <: usize ] <: i64)
          else r =. v_ERR_INVALID_ARGUMENT && vv_future =. v) =
  let (v: i64), (hax_temp_output: i32) =
    if mk_i32 0 <=. k && k <. v_SLOT_NUM
    then
      let v:i64 = args.f_slot.[ cast (k <: i32) <: usize ] in
      v, mk_i32 0 <: (i64 & i32)
    else v, v_ERR_INVALID_ARGUMENT <: (i64 & i32)
  in
  v, hax_temp_output <: (i64 & i32)

/// Writes v into slot k; out of bounds, returns ERR_INVALID_ARGUMENT and
/// writes nothing. The verified side\'s fields are unchanged.
let set_slot (args: t_VuArgs) (k: i32) (v: i64)
    : Prims.Pure (t_VuArgs & i32)
      Prims.l_True
      (ensures
        fun temp_0_ ->
          let (args_future: t_VuArgs), (r: i32) = temp_0_ in
          (if mk_i32 0 <=. k && k <. v_SLOT_NUM
            then r =. mk_i32 0 && (args_future.f_slot.[ cast (k <: i32) <: usize ] <: i64) =. v
            else
              r =. v_ERR_INVALID_ARGUMENT &&
              (args_future.f_slot.[ mk_usize 0 ] <: i64) =. (args.f_slot.[ mk_usize 0 ] <: i64) &&
              (args_future.f_slot.[ mk_usize 1 ] <: i64) =. (args.f_slot.[ mk_usize 1 ] <: i64) &&
              (args_future.f_slot.[ mk_usize 2 ] <: i64) =. (args.f_slot.[ mk_usize 2 ] <: i64) &&
              (args_future.f_slot.[ mk_usize 3 ] <: i64) =. (args.f_slot.[ mk_usize 3 ] <: i64) &&
              (args_future.f_slot.[ mk_usize 4 ] <: i64) =. (args.f_slot.[ mk_usize 4 ] <: i64)) &&
          args_future.f_subject =. args.f_subject &&
          args_future.f_subject_len =. args.f_subject_len &&
          args_future.f_pos =. args.f_pos &&
          args_future.f_num =. args.f_num) =
  let (args: t_VuArgs), (hax_temp_output: i32) =
    if mk_i32 0 <=. k && k <. v_SLOT_NUM
    then
      let args:t_VuArgs =
        {
          args with
          f_slot
          =
          Rust_primitives.Hax.Monomorphized_update_at.update_at_usize args.f_slot
            (cast (k <: i32) <: usize)
            v
        }
        <:
        t_VuArgs
      in
      args, mk_i32 0 <: (t_VuArgs & i32)
    else args, v_ERR_INVALID_ARGUMENT <: (t_VuArgs & i32)
  in
  args, hax_temp_output <: (t_VuArgs & i32)

/// Reads byte i of the subject; out of [0, subject_len), returns
/// ERR_INVALID_ARGUMENT and reads nothing. The subject is a shared
/// slice: hax has no model of the raw pointer held in args, so ffi.rs
/// (trusted) makes the slice from args.subject and args.subject_len; the
/// precondition states their agreement. Both args and the subject are
/// shared references, hence unchanged.
let get_subject_byte (args: t_VuArgs) (subject: t_Slice u8) (i: i32)
    : Prims.Pure i32
      (requires
        mk_i32 0 <=. args.f_subject_len &&
        (Core_models.Slice.impl__len #u8 subject <: usize) =.
        (cast (args.f_subject_len <: i32) <: usize))
      (ensures
        fun r ->
          let r:i32 = r in
          if mk_i32 0 <=. i && i <. args.f_subject_len
          then r =. (cast (subject.[ cast (i <: i32) <: usize ] <: u8) <: i32)
          else r =. v_ERR_INVALID_ARGUMENT) =
  if mk_i32 0 <=. i && i <. args.f_subject_len
  then cast (subject.[ cast (i <: i32) <: usize ] <: u8) <: i32
  else v_ERR_INVALID_ARGUMENT

/// A verified function that can be handed to the client as a
/// vu_apply_fn. Its contract (the record invariant is kept) is checked
/// on every verified implementation.
class t_Apply (v_Self: Type0) = {
  f_apply_pre:from: u32 -> to_len: i32 -> v_rec: t_VuFoldRec -> pred: Type0{rec_wf v_rec ==> pred};
  f_apply_post:from: u32 -> to_len: i32 -> v_rec: t_VuFoldRec -> x: (t_VuFoldRec & i32)
    -> pred:
      Type0
        { pred ==>
          (let (rec_future: t_VuFoldRec), (e_r: i32) = x in
            rec_wf rec_future) };
  f_apply:x0: u32 -> x1: i32 -> x2: t_VuFoldRec
    -> Prims.Pure (t_VuFoldRec & i32)
        (f_apply_pre x0 x1 x2)
        (fun result -> f_apply_post x0 x1 x2 result)
}

[@@ FStar.Tactics.Typeclasses.tcinstance]
let impl: t_Apply t_IApply =
  {
    f_apply_pre = (fun (from: u32) (to_len: i32) (v_rec: t_VuFoldRec) -> rec_wf v_rec);
    f_apply_post
    =
    (fun (from: u32) (to_len: i32) (v_rec: t_VuFoldRec) (rec_future, e_r: (t_VuFoldRec & i32)) ->
        rec_wf rec_future);
    f_apply
    =
    fun (from: u32) (to_len: i32) (v_rec: t_VuFoldRec) ->
      let (tmp0: t_VuFoldRec), (out: i32) = ii_apply from to_len v_rec in
      let v_rec:t_VuFoldRec = tmp0 in
      let hax_temp_output:i32 = out in
      v_rec, hax_temp_output <: (t_VuFoldRec & i32)
  }

/// A client vu_apply_all_fn: it is given the verified function A (as a
/// C pointer, by ffi.rs) and the record. Client contract (trusted, in
/// TRUSTED): the client reaches the record only through A, so it keeps
/// A\'s invariant.
class t_ApplyAll (v_Self: Type0) = {
  f_apply_all_pre:#v_A: Type0 -> {| i1: t_Apply v_A |} -> self_: v_Self -> v_rec: t_VuFoldRec
    -> pred: Type0{rec_wf v_rec ==> pred};
  f_apply_all_post:
      #v_A: Type0 ->
      {| i1: t_Apply v_A |} ->
      self_: v_Self ->
      v_rec: t_VuFoldRec ->
      x: (t_VuFoldRec & i32)
    -> pred:
      Type0
        { pred ==>
          (let (rec_future: t_VuFoldRec), (e_r: i32) = x in
            rec_wf rec_future) };
  f_apply_all:#v_A: Type0 -> {| i1: t_Apply v_A |} -> x0: v_Self -> x1: t_VuFoldRec
    -> Prims.Pure (t_VuFoldRec & i32)
        (f_apply_all_pre #v_A #i1 x0 x1)
        (fun result -> f_apply_all_post #v_A #i1 x0 x1 result)
}

/// Hands i_apply and rec to the client\'s apply-all function g and
/// returns g\'s result. Under the client contract of ApplyAll, the record
/// comes back well formed.
let fold_all
      (#v_G: Type0)
      (#[FStar.Tactics.Typeclasses.tcresolve ()] i0: t_ApplyAll v_G)
      (g: v_G)
      (v_rec: t_VuFoldRec)
    : Prims.Pure (t_VuFoldRec & i32)
      (requires rec_wf v_rec)
      (ensures
        fun temp_0_ ->
          let (rec_future: t_VuFoldRec), (e_r: i32) = temp_0_ in
          rec_wf rec_future) =
  let (tmp0: t_VuFoldRec), (out: i32) =
    f_apply_all #v_G #FStar.Tactics.Typeclasses.solve #t_IApply g v_rec
  in
  let v_rec:t_VuFoldRec = tmp0 in
  let hax_temp_output:i32 = out in
  v_rec, hax_temp_output <: (t_VuFoldRec & i32)
