// lib.rs: the RefinedRust prototype of experiment 5 (verified part; run
// E of the pipeline). DRAFT, NOT CHECKED: run E stopped here at its
// 3-hour cap (RefinedRust stays pending). State at the stop:
// - char_len (with EncLen's trait specification) is translated and
//   checked by RefinedRust (in a one-function crate);
// - the specifications of the &mut functions do not type-check yet in
//   the generated Rocq (the refinement of a &mut VuFoldRec argument);
// - get_subject_byte is #[rr::skip]: RefinedRust at 2862b1d8 rejects
//   the slice index ("Unsupported feature: PtrMetadata unop not
//   supported"); the next try is a raw pointer read with an ownership
//   specification of the subject array, which needs RefinedRust's
//   stdlib (ptr::add).
//
// The verified functions of proto.h in safe Rust with RefinedRust
// specifications (#[rr::...]): char_len (vu_char_len), callout_step
// (vu_callout_step), i_apply and fold_all (vu_i_apply, vu_fold_all),
// get_slot and set_slot (vu_get_slot, vu_set_slot), get_subject_byte
// (vu_get_subject_byte). cargo refinedrust translates this file to Rocq
// (Radium code, specifications and proof scripts), which dune checks;
// rustc compiles the same file into the C library. The C entry points
// are in ffi.rs, whose items are #[rr::skip] (not translated).
//
// The design is the hax prototype's (../hax/src/lib.rs): each client C
// function is a trait the verified functions are generic over, with a
// RefinedRust trait specification that every implementation must
// refine; the only implementations are in ffi.rs. Pointers the verified
// side only passes through are usize addresses, which ffi.rs converts.
//
// Two marker comments delimit the clamp that the negative control
// removes, two more the bound test that the read control removes.

#![feature(register_tool)]
#![register_tool(rr)]
#![feature(custom_inner_attributes)]
#![allow(unused)]
#![allow(clippy::needless_return)]

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

/// struct vu_args of proto.h. subject is the address of the subject.
#[repr(C)]
pub struct VuArgs {
    pub subject: usize,
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

// ---------------------------------------------------------- client traits

/// A client vu_enc_len_fn: any result.
pub trait EncLen {
    #[rr::exists("r")]
    #[rr::returns("r")]
    fn enc_len(&self, p: usize) -> i32;
}

/// A client vu_callout_fn with its user_data: it is lent args mutably
/// and may leave anything there; any result.
pub trait Callout {
    #[rr::exists("r", "a2")]
    #[rr::observe("args.ghost": "a2")]
    #[rr::returns("r")]
    fn callout(&self, args: &mut VuArgs) -> i32;
}

/// A verified function that can be handed to the client as a
/// vu_apply_fn: it keeps the record invariant.
pub trait Apply {
    #[rr::params("from", "to_len", "c" : "Z", "d" : "Z", "fr" : "list (place_rfnRT Z)", "γ")]
    #[rr::args("from", "to_len", "(#(-[#c; #d; #fr] : plist place_rfnRT [Z : RT; Z : RT; list (place_rfnRT Z) : RT]), γ)")]
    #[rr::requires("0 ≤ c ∧ 0 ≤ d ≤ 8")]
    #[rr::exists("r" : "Z", "c2" : "Z", "d2" : "Z", "fr2" : "list (place_rfnRT Z)")]
    #[rr::observe("γ": "(-[#c2; #d2; #fr2] : plist place_rfnRT [Z : RT; Z : RT; list (place_rfnRT Z) : RT])")]
    #[rr::ensures("0 ≤ c2 ∧ 0 ≤ d2 ≤ 8")]
    #[rr::returns("r")]
    fn apply(from: u32, to_len: i32, rec: &mut VuFoldRec) -> i32;
}

/// A client vu_apply_all_fn, given the verified function A (as a C
/// pointer, by ffi.rs) and the record. Client contract (trusted, in
/// TRUSTED): it keeps the record invariant.
pub trait ApplyAll {
    #[rr::params("c" : "Z", "d" : "Z", "fr" : "list (place_rfnRT Z)", "γ")]
    #[rr::args("_", "(#(-[#c; #d; #fr] : plist place_rfnRT [Z : RT; Z : RT; list (place_rfnRT Z) : RT]), γ)")]
    #[rr::requires("0 ≤ c ∧ 0 ≤ d ≤ 8")]
    #[rr::exists("r" : "Z", "c2" : "Z", "d2" : "Z", "fr2" : "list (place_rfnRT Z)")]
    #[rr::observe("γ": "(-[#c2; #d2; #fr2] : plist place_rfnRT [Z : RT; Z : RT; list (place_rfnRT Z) : RT])")]
    #[rr::ensures("0 ≤ c2 ∧ 0 ≤ d2 ≤ 8")]
    #[rr::returns("r")]
    fn apply_all<A: Apply>(&self, rec: &mut VuFoldRec) -> i32;
}

// ------------------------------------------------------------ 1. vu_char_len

#[rr::params("lo", "hi")]
#[rr::args("_", "_", "-[#lo; #hi]")]
#[rr::requires("1 ≤ lo ≤ hi")]
#[rr::exists("r")]
#[rr::returns("r")]
#[rr::ensures("lo ≤ r ≤ hi")]
pub fn char_len<F: EncLen>(f: &F, p: usize, st: &VuEncState) -> i32 {
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

/// Calls the client's callout once (valid dir) or not at all and
/// returns the action of the branch rules and, as a second component
/// that ffi.rs drops, the callee's raw result. The verified side keeps
/// its own copy of its fields and writes it back.
#[rr::params("dir", "s" : "Z", "len" : "Z", "pos" : "Z", "num" : "Z", "sl" : "list (place_rfnRT Z)", "γ")]
#[rr::args("dir", "_", "(#(-[#s; #len; #pos; #num; #sl] : plist place_rfnRT [Z : RT; Z : RT; Z : RT; Z : RT; list (place_rfnRT Z) : RT]), γ)")]
#[rr::exists("act", "raw", "sl2" : "list (place_rfnRT Z)")]
#[rr::observe("γ": "(-[#s; #len; #pos; #num; #sl2] : plist place_rfnRT [Z : RT; Z : RT; Z : RT; Z : RT; list (place_rfnRT Z) : RT])")]
#[rr::returns("-[#act; #raw]")]
#[rr::ensures("dir = 0 → act = (if bool_decide (raw = 1) then 1 else if bool_decide (raw = 0) then 0 else if bool_decide (0 < raw) then -30 else raw)")]
#[rr::ensures("dir = 1 → act = (if bool_decide (raw = 1 ∨ raw = 0) then 0 else if bool_decide (0 < raw) then -30 else raw)")]
#[rr::ensures("dir = 2 → act = (if bool_decide (raw < 0) then raw else 1)")]
#[rr::ensures("¬ (0 ≤ dir ≤ 2) → act = -30")]
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

/// The verified function handed to the client (re-entrancy shape (a)).
#[rr::params("from", "to_len", "c" : "Z", "d" : "Z", "fr" : "list (place_rfnRT Z)", "γ")]
#[rr::args("from", "to_len", "(#(-[#c; #d; #fr] : plist place_rfnRT [Z : RT; Z : RT; list (place_rfnRT Z) : RT]), γ)")]
#[rr::requires("length fr = 8%nat")]
#[rr::exists("c2" : "Z", "d2" : "Z", "fr2" : "list (place_rfnRT Z)")]
#[rr::observe("γ": "(-[#c2; #d2; #fr2] : plist place_rfnRT [Z : RT; Z : RT; list (place_rfnRT Z) : RT])")]
#[rr::ensures("c < MaxInt i32 → c2 = c + 1")]
#[rr::ensures("MaxInt i32 ≤ c → c2 = c")]
#[rr::ensures("1 ≤ to_len ≤ 3 ∧ 0 ≤ d < 8 → d2 = d + 1 ∧ fr2 = <[Z.to_nat d := #from]> fr")]
#[rr::ensures("¬ (1 ≤ to_len ≤ 3 ∧ 0 ≤ d < 8) → d2 = d ∧ fr2 = fr")]
#[rr::returns("0")]
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

pub struct IApply;

impl Apply for IApply {
    #[rr::params("from", "to_len", "c" : "Z", "d" : "Z", "fr" : "list (place_rfnRT Z)", "γ")]
    #[rr::args("from", "to_len", "(#(-[#c; #d; #fr] : plist place_rfnRT [Z : RT; Z : RT; list (place_rfnRT Z) : RT]), γ)")]
    #[rr::requires("0 ≤ c ∧ 0 ≤ d ≤ 8")]
    #[rr::exists("r" : "Z", "c2" : "Z", "d2" : "Z", "fr2" : "list (place_rfnRT Z)")]
    #[rr::observe("γ": "(-[#c2; #d2; #fr2] : plist place_rfnRT [Z : RT; Z : RT; list (place_rfnRT Z) : RT])")]
    #[rr::ensures("0 ≤ c2 ∧ 0 ≤ d2 ≤ 8")]
    #[rr::returns("r")]
    fn apply(from: u32, to_len: i32, rec: &mut VuFoldRec) -> i32 {
        i_apply(from, to_len, rec)
    }
}

#[rr::params("c" : "Z", "d" : "Z", "fr" : "list (place_rfnRT Z)", "γ")]
#[rr::args("_", "(#(-[#c; #d; #fr] : plist place_rfnRT [Z : RT; Z : RT; list (place_rfnRT Z) : RT]), γ)")]
#[rr::requires("0 ≤ c ∧ 0 ≤ d ≤ 8")]
#[rr::exists("r" : "Z", "c2" : "Z", "d2" : "Z", "fr2" : "list (place_rfnRT Z)")]
#[rr::observe("γ": "(-[#c2; #d2; #fr2] : plist place_rfnRT [Z : RT; Z : RT; list (place_rfnRT Z) : RT])")]
#[rr::ensures("0 ≤ c2 ∧ 0 ≤ d2 ≤ 8")]
#[rr::returns("r")]
pub fn fold_all<G: ApplyAll>(g: &G, rec: &mut VuFoldRec) -> i32 {
    g.apply_all::<IApply>(rec)
}

// ------------------------------------------- 4. vu_get_slot and vu_set_slot

#[rr::params("s" : "Z", "len" : "Z", "pos" : "Z", "num" : "Z", "sl" : "list (place_rfnRT Z)", "k", "x", "γ")]
#[rr::args("(-[#s; #len; #pos; #num; #sl] : plist place_rfnRT [Z : RT; Z : RT; Z : RT; Z : RT; list (place_rfnRT Z) : RT])", "k", "(x, γ)")]
#[rr::requires("length sl = 5%nat")]
#[rr::exists("res", "y")]
#[rr::observe("γ": "y")]
#[rr::returns("res")]
#[rr::ensures("0 ≤ k < 5 → res = 0 ∧ sl !! Z.to_nat k = Some (#y)")]
#[rr::ensures("¬ (0 ≤ k < 5) → res = -30 ∧ y = x")]
pub fn get_slot(args: &VuArgs, k: i32, v: &mut i64) -> i32 {
    if 0 <= k && k < SLOT_NUM {
        *v = args.slot[k as usize];
        0
    } else {
        ERR_INVALID_ARGUMENT
    }
}

#[rr::params("s" : "Z", "len" : "Z", "pos" : "Z", "num" : "Z", "sl" : "list (place_rfnRT Z)", "γ", "k", "v")]
#[rr::args("(#(-[#s; #len; #pos; #num; #sl] : plist place_rfnRT [Z : RT; Z : RT; Z : RT; Z : RT; list (place_rfnRT Z) : RT]), γ)", "k", "v")]
#[rr::requires("length sl = 5%nat")]
#[rr::exists("res", "sl2" : "list (place_rfnRT Z)")]
#[rr::observe("γ": "(-[#s; #len; #pos; #num; #sl2] : plist place_rfnRT [Z : RT; Z : RT; Z : RT; Z : RT; list (place_rfnRT Z) : RT])")]
#[rr::returns("res")]
#[rr::ensures("0 ≤ k < 5 → res = 0 ∧ sl2 = <[Z.to_nat k := #v]> sl")]
#[rr::ensures("¬ (0 ≤ k < 5) → res = -30 ∧ sl2 = sl")]
pub fn set_slot(args: &mut VuArgs, k: i32, v: i64) -> i32 {
    if 0 <= k && k < SLOT_NUM {
        args.slot[k as usize] = v;
        0
    } else {
        ERR_INVALID_ARGUMENT
    }
}

// ------------------------------------------- 5. vu_get_subject_byte

/// The subject is a shared slice made by ffi.rs (trusted) from the
/// address and length held in args; the precondition states their
/// agreement.
#[rr::params("s" : "Z", "len" : "Z", "pos" : "Z", "num" : "Z", "sl" : "list (place_rfnRT Z)", "bs", "i")]
#[rr::args("(-[#s; #len; #pos; #num; #sl] : plist place_rfnRT [Z : RT; Z : RT; Z : RT; Z : RT; list (place_rfnRT Z) : RT])", "bs", "i")]
#[rr::requires("len = length bs")]
#[rr::exists("res")]
#[rr::returns("res")]
#[rr::ensures("0 ≤ i < len → bs !! Z.to_nat i = Some res")]
#[rr::ensures("¬ (0 ≤ i < len) → res = -30")]
#[rr::skip]
pub fn get_subject_byte(args: &VuArgs, subject: &[u8], i: i32) -> i32 {
    // VU-READ-BEGIN
    if 0 <= i && i < args.subject_len {
    // VU-READ-END
        subject[i as usize] as i32
    } else {
        ERR_INVALID_ARGUMENT
    }
}
