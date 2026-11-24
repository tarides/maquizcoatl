// lib.rs: the Creusot prototype of experiment 5 (verified part; run E of
// the pipeline).
//
// The verified functions of proto.h, in safe Rust with Creusot
// contracts (Pearlite): char_len (vu_char_len), callout_step
// (vu_callout_step), i_apply and fold_all (vu_i_apply, vu_fold_all),
// get_slot and set_slot (vu_get_slot, vu_set_slot), get_subject_byte
// (vu_get_subject_byte). Creusot translates this file to Coma and
// Why3find proves its verification conditions. The same file is
// compiled by rustc into the C library; the C entry points are in
// ffi.rs, which Creusot does not see (cfg(not(creusot))).
//
// The design is the Aeneas and hax prototypes' (../aeneas/src/lib.rs):
// Creusot gives Rust's own function pointer types no contract and cannot
// call an unsafe extern "C" pointer from verified code, so each client
// C function is a trait, the verified functions are generic over it, and
// their proofs hold for every implementation that meets the trait's
// contract. Creusot checks that every implementation in the crate
// refines the trait's contract; the only implementations of the client
// traits are in ffi.rs, which Creusot does not see: each one does the
// indirect call and nothing else.
//
// Two marker comments delimit the clamp that the negative control
// removes, two more the bound test that the read control removes.

use creusot_std::prelude::*;

#[cfg(not(creusot))]
mod ffi;

// Constants of proto.h (upstream values, see proto.h for the citations).
pub const CALLOUT_SUCCESS: i32 = 0;
pub const CALLOUT_FAIL: i32 = 1;
pub const ERR_INVALID_ARGUMENT: i32 = -30;
pub const SLOT_NUM: i32 = 5;
pub const MAX_TO_LEN: i32 = 3;
pub const FOLD_REC_MAX: i32 = 8;
pub const DIR_PROGRESS: i32 = 0;
pub const DIR_RETRACTION: i32 = 1;
pub const DIR_EACH_MATCH: i32 = 2;
pub const ACT_CONTINUE: i32 = 0;
pub const ACT_BACKTRACK: i32 = 1;

/// struct vu_enc_state of proto.h.
#[repr(C)]
pub struct VuEncState {
    pub min_enc_len: i32,
    pub max_enc_len: i32,
}

/// struct vu_args of proto.h. The first four fields are the verified
/// side's state; only the slots may change across a callout. subject is
/// a raw pointer, an opaque value for Creusot: the verified side never
/// dereferences it.
#[repr(C)]
pub struct VuArgs {
    pub subject: *const u8,
    pub subject_len: i32,
    pub pos: i32,
    pub num: i32,
    pub slot: [i64; 5],
}

/// struct vu_fold_rec of proto.h.
#[repr(C)]
pub struct VuFoldRec {
    pub calls: i32,
    pub recorded: i32,
    pub from: [u32; 8],
}

/// The record invariant that vu_i_apply keeps.
#[logic(open)]
pub fn rec_wf(rec: VuFoldRec) -> bool {
    pearlite! { 0 <= rec.calls@ && 0 <= rec.recorded@ && rec.recorded@ <= 8 }
}

// ---------------------------------------------------------- client traits

/// A client vu_enc_len_fn. p is passed through, never read here. No
/// contract: nothing is assumed of the callee's result.
pub trait EncLen {
    fn enc_len(&self, p: *const u8) -> i32;
}

/// A client vu_callout_fn with its user_data. The callee is lent args
/// mutably for the call. No contract: it may write anything into args.
pub trait Callout {
    fn callout(&self, args: &mut VuArgs) -> i32;
}

/// A verified function that can be handed to the client as a
/// vu_apply_fn (no receiver, so that ffi.rs can make a C function
/// pointer of it). Its contract (the record invariant is kept) is
/// checked on every implementation in the crate (IApply below).
pub trait Apply {
    #[requires(rec_wf(*rec))]
    #[ensures(rec_wf(^rec))]
    fn apply(from: u32, to_len: i32, rec: &mut VuFoldRec) -> i32;
}

/// A client vu_apply_all_fn: it is given the verified function A (as a
/// C pointer, by ffi.rs) and the record. Client contract (trusted, in
/// TRUSTED): the client reaches the record only through A, so it keeps
/// A's invariant.
pub trait ApplyAll {
    #[requires(rec_wf(*rec))]
    #[ensures(rec_wf(^rec))]
    fn apply_all<A: Apply>(&self, rec: &mut VuFoldRec) -> i32;
}

// ------------------------------------------------------------ 1. vu_char_len

/// Calls the client's encoding function f on p and clamps its result to
/// the bounds in st. Nothing is assumed of the callee's result. st is a
/// shared reference that the callee is not given, hence unchanged.
#[requires(1 <= st.min_enc_len@ && st.min_enc_len@ <= st.max_enc_len@)]
#[ensures(st.min_enc_len@ <= result@ && result@ <= st.max_enc_len@)]
pub fn char_len<F: EncLen>(f: &F, p: *const u8, st: &VuEncState) -> i32 {
    let raw = f.enc_len(p);
    // VU-CLAMP-BEGIN
    if raw < st.min_enc_len {
        st.min_enc_len
    } else if raw > st.max_enc_len {
        st.max_enc_len
    } else {
        raw
    }
    // VU-CLAMP-END
}

// -------------------------------------------------------- 2. vu_callout_step

/// The branch rules (lab/results/2026-11-19-exp-05-harness.md), for a
/// valid dir and the callee's result r:
/// - progress, upstream/src/regexec.c:4616-4631: FAIL backtracks,
///   SUCCESS continues, another positive value is
///   ONIGERR_INVALID_ARGUMENT, a negative value is returned;
/// - retraction, upstream/src/regexec.c:1218-1234: FAIL and SUCCESS
///   continue, otherwise as in progress;
/// - each-match, upstream/src/regexec.c:3387-3400: a negative value is
///   returned, anything else backtracks (the search goes on).
#[logic(open)]
pub fn rule(dir: i32, r: i32) -> i32 {
    pearlite! {
        if dir@ == 0 {
            if r@ == 1 { 1i32 } else if r@ == 0 { 0i32 } else if r@ > 0 { -30i32 } else { r }
        } else if dir@ == 1 {
            if r@ == 1 || r@ == 0 { 0i32 } else if r@ > 0 { -30i32 } else { r }
        } else if r@ < 0 { r } else { 1i32 }
    }
}

#[logic(open)]
pub fn dir_valid(dir: i32) -> bool {
    pearlite! { dir@ == 0 || dir@ == 1 || dir@ == 2 }
}

/// Calls the client's callout f once (valid dir) or not at all (invalid
/// dir). Returns the action and, as a second component that ffi.rs
/// drops, the callee's raw result (0 when it is not called): the
/// postcondition ties the action to that result.
///
/// The callee may write anything into args. The verified side does not
/// trust what it finds there: it keeps its own copy of its state and
/// writes it back, so only the slots carry the callee's writes.
#[ensures(if dir_valid(dir) { result.0 == rule(dir, result.1) } else { result.0@ == -30 })]
#[ensures((^args).subject == (*args).subject)]
#[ensures((^args).subject_len == (*args).subject_len)]
#[ensures((^args).pos == (*args).pos)]
#[ensures((^args).num == (*args).num)]
pub fn callout_step<F: Callout>(dir: i32, f: &F, args: &mut VuArgs) -> (i32, i32) {
    if !(dir == DIR_PROGRESS || dir == DIR_RETRACTION || dir == DIR_EACH_MATCH) {
        return (ERR_INVALID_ARGUMENT, 0);
    }
    let subject = args.subject;
    let subject_len = args.subject_len;
    let pos = args.pos;
    let num = args.num;
    let r = f.callout(args);
    args.subject = subject;
    args.subject_len = subject_len;
    args.pos = pos;
    args.num = num;
    let act = if dir == DIR_PROGRESS {
        if r == CALLOUT_FAIL {
            ACT_BACKTRACK
        } else if r == CALLOUT_SUCCESS {
            ACT_CONTINUE
        } else if r > 0 {
            ERR_INVALID_ARGUMENT
        } else {
            r
        }
    } else if dir == DIR_RETRACTION {
        if r == CALLOUT_FAIL || r == CALLOUT_SUCCESS {
            ACT_CONTINUE
        } else if r > 0 {
            ERR_INVALID_ARGUMENT
        } else {
            r
        }
    } else if r < 0 {
        r
    } else {
        ACT_BACKTRACK
    };
    (act, r)
}

// -------------------------------------------- 3. vu_i_apply and vu_fold_all

/// The verified function handed to the client (re-entrancy shape (a),
/// as i_apply_case_fold, upstream/src/regparse.c:8739): calls saturates
/// at i32::MAX, from is appended when 1 <= to_len <= MAX_TO_LEN and the
/// record is not full. It never reads the client's to array, which
/// ffi.rs does not pass on.
#[ensures(result@ == 0)]
#[ensures(if (*rec).calls@ < i32::MAX@ { (^rec).calls@ == (*rec).calls@ + 1 } else { (^rec).calls == (*rec).calls })]
#[ensures(if 1 <= to_len@ && to_len@ <= 3 && 0 <= (*rec).recorded@ && (*rec).recorded@ < 8 {
        (^rec).recorded@ == (*rec).recorded@ + 1 && (^rec).from@[(*rec).recorded@] == from
    } else {
        (^rec).recorded == (*rec).recorded
    })]
#[ensures(rec_wf(*rec) ==> rec_wf(^rec))]
pub fn i_apply(from: u32, to_len: i32, rec: &mut VuFoldRec) -> i32 {
    if rec.calls < i32::MAX {
        rec.calls = rec.calls + 1;
    }
    if 1 <= to_len && to_len <= MAX_TO_LEN && 0 <= rec.recorded && rec.recorded < FOLD_REC_MAX {
        rec.from[rec.recorded as usize] = from;
        rec.recorded = rec.recorded + 1;
    }
    0
}

/// i_apply as an Apply: Creusot checks that this implementation refines
/// the trait's contract.
pub struct IApply;

impl Apply for IApply {
    #[requires(rec_wf(*rec))]
    #[ensures(rec_wf(^rec))]
    fn apply(from: u32, to_len: i32, rec: &mut VuFoldRec) -> i32 {
        i_apply(from, to_len, rec)
    }
}

/// Hands i_apply and rec to the client's apply-all function g and
/// returns g's result. Under the client contract of ApplyAll, the record
/// comes back well formed.
#[requires(rec_wf(*rec))]
#[ensures(rec_wf(^rec))]
pub fn fold_all<G: ApplyAll>(g: &G, rec: &mut VuFoldRec) -> i32 {
    g.apply_all::<IApply>(rec)
}

// ------------------------------------------- 4. vu_get_slot and vu_set_slot

/// Reads slot k into v; out of bounds, returns ERR_INVALID_ARGUMENT and
/// leaves v untouched.
#[ensures(if 0 <= k@ && k@ < 5 {
        result@ == 0 && ^v == args.slot@[k@]
    } else {
        result@ == -30 && ^v == *v
    })]
pub fn get_slot(args: &VuArgs, k: i32, v: &mut i64) -> i32 {
    if 0 <= k && k < SLOT_NUM {
        *v = args.slot[k as usize];
        0
    } else {
        ERR_INVALID_ARGUMENT
    }
}

/// Writes v into slot k; out of bounds, returns ERR_INVALID_ARGUMENT and
/// writes nothing. The verified side's fields are unchanged.
#[ensures(if 0 <= k@ && k@ < 5 {
        result@ == 0 && (^args).slot@[k@] == v
            && forall<j> 0 <= j && j < 5 && j != k@ ==> (^args).slot@[j] == (*args).slot@[j]
    } else {
        result@ == -30 && (^args).slot == (*args).slot
    })]
#[ensures((^args).subject == (*args).subject)]
#[ensures((^args).subject_len == (*args).subject_len)]
#[ensures((^args).pos == (*args).pos)]
#[ensures((^args).num == (*args).num)]
pub fn set_slot(args: &mut VuArgs, k: i32, v: i64) -> i32 {
    if 0 <= k && k < SLOT_NUM {
        args.slot[k as usize] = v;
        0
    } else {
        ERR_INVALID_ARGUMENT
    }
}

// ------------------------------------------- 5. vu_get_subject_byte

/// Reads byte i of the subject; out of [0, subject_len), returns
/// ERR_INVALID_ARGUMENT and reads nothing. The subject is a shared
/// slice: the verified side does not dereference the raw pointer held in
/// args, so ffi.rs (trusted) makes the slice from args.subject and
/// args.subject_len; the precondition states their agreement. Both args
/// and the subject are shared references, hence unchanged.
#[requires(0 <= args.subject_len@ && subject@.len() == args.subject_len@)]
#[ensures(if 0 <= i@ && i@ < args.subject_len@ {
        result@ == subject@[i@]@
    } else {
        result@ == -30
    })]
pub fn get_subject_byte(args: &VuArgs, subject: &[u8], i: i32) -> i32 {
    // VU-READ-BEGIN
    if 0 <= i && i < args.subject_len {
    // VU-READ-END
        subject[i as usize] as i32
    } else {
        ERR_INVALID_ARGUMENT
    }
}
