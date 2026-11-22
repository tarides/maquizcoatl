// lib.rs: the RefinedRust prototype of experiment 5 (verified part;
// run E drafted it, run F of the pipeline completed it).
//
// The verified functions of proto.h in Rust with RefinedRust
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
// refine; the only implementations are in ffi.rs. The structs of
// proto.h are refined by tuples of their fields (#[rr::refined_by]).
// The subject is a raw pointer in VuArgs: get_subject_byte reads it with
// ptr::add and a dereference (RefinedRust at 2862b1d8 rejects slice
// indexing, "PtrMetadata unop not supported"), under a precondition
// that owns the subject's bytes and a postcondition that gives them back
// unchanged.
//
// Two marker comments delimit the clamp that the negative control
// removes, two more the bound test that the read control removes.

#![feature(register_tool)]
#![register_tool(rr)]
#![feature(custom_inner_attributes)]
#![rr::include("ptr")]
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

/// struct vu_args of proto.h. The array slot[5] of proto.h is spelt as
/// five fields of the same type, which have the array's layout (checked
/// field by field in ffi.rs): RefinedRust at 2862b1d8 checks an array
/// element write behind a &mut only with constant indices, and then
/// fails to fold the array back (see the run F entry).
#[repr(C)]
pub struct VuArgs {
    pub subject: *const u8,
    pub subject_len: i32,
    pub pos: i32,
    pub num: i32,
    pub slot0: i64,
    pub slot1: i64,
    pub slot2: i64,
    pub slot3: i64,
    pub slot4: i64,
}

/// struct vu_fold_rec of proto.h, from[8] spelt as eight fields (as
/// slot in VuArgs).
#[repr(C)]
pub struct VuFoldRec {
    pub calls: i32,
    pub recorded: i32,
    pub from0: u32,
    pub from1: u32,
    pub from2: u32,
    pub from3: u32,
    pub from4: u32,
    pub from5: u32,
    pub from6: u32,
    pub from7: u32,
}

// ---------------------------------------------------------- client traits

/// A client vu_enc_len_fn: any result.
pub trait EncLen {
    #[rr::params("s", "p")]
    #[rr::args("s", "p")]
    #[rr::exists("r" : "Z")]
    #[rr::returns("r")]
    fn enc_len(&self, p: usize) -> i32;
}

/// A client vu_callout_fn with its user_data: it is lent args mutably
/// and may leave anything there; any result.
pub trait Callout {
    #[rr::params("me", "s", "len", "pos", "num", "x0", "x1", "x2", "x3", "x4", "γ")]
    #[rr::args("me", "( *[s; len; pos; num; x0; x1; x2; x3; x4], γ)")]
    #[rr::exists("r" : "Z", "s2" : "loc", "len2" : "Z", "pos2" : "Z", "num2" : "Z", "y0" : "Z", "y1" : "Z", "y2" : "Z", "y3" : "Z", "y4" : "Z")]
    #[rr::observe("γ": "(-[#s2; #len2; #pos2; #num2; #y0; #y1; #y2; #y3; #y4] : plist place_rfnRT [loc : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT])")]
    #[rr::returns("r")]
    fn callout(&self, args: &mut VuArgs) -> i32;
}

/// A verified function that can be handed to the client as a
/// vu_apply_fn: it keeps the record invariant rec_wf (0 <= calls,
/// 0 <= recorded <= 8).
pub trait Apply {
    #[rr::params("from", "to_len", "c", "d", "f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7", "γ")]
    #[rr::args("from", "to_len", "( *[c; d; f0; f1; f2; f3; f4; f5; f6; f7], γ)")]
    #[rr::requires("0 ≤ c ∧ 0 ≤ d ≤ 8")]
    #[rr::exists("r" : "Z", "c2" : "Z", "d2" : "Z", "g0" : "Z", "g1" : "Z", "g2" : "Z", "g3" : "Z", "g4" : "Z", "g5" : "Z", "g6" : "Z", "g7" : "Z")]
    #[rr::observe("γ": "(-[#c2; #d2; #g0; #g1; #g2; #g3; #g4; #g5; #g6; #g7] : plist place_rfnRT [Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT])")]
    #[rr::ensures("0 ≤ c2 ∧ 0 ≤ d2 ≤ 8")]
    #[rr::returns("r")]
    fn apply(from: u32, to_len: i32, rec: &mut VuFoldRec) -> i32;
}

/// A client vu_apply_all_fn, given the verified function A (as a C
/// pointer, by ffi.rs) and the record. Client contract (trusted, in
/// TRUSTED): it keeps the record invariant rec_wf.
pub trait ApplyAll {
    #[rr::params("me", "c", "d", "f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7", "γ")]
    #[rr::args("me", "( *[c; d; f0; f1; f2; f3; f4; f5; f6; f7], γ)")]
    #[rr::requires("0 ≤ c ∧ 0 ≤ d ≤ 8")]
    #[rr::exists("r" : "Z", "c2" : "Z", "d2" : "Z", "g0" : "Z", "g1" : "Z", "g2" : "Z", "g3" : "Z", "g4" : "Z", "g5" : "Z", "g6" : "Z", "g7" : "Z")]
    #[rr::observe("γ": "(-[#c2; #d2; #g0; #g1; #g2; #g3; #g4; #g5; #g6; #g7] : plist place_rfnRT [Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT])")]
    #[rr::ensures("0 ≤ c2 ∧ 0 ≤ d2 ≤ 8")]
    #[rr::returns("r")]
    fn apply_all<A: Apply>(&self, rec: &mut VuFoldRec) -> i32;
}

// ------------------------------------------------------------ 1. vu_char_len

#[rr::params("f", "p", "lo", "hi")]
#[rr::args("f", "p", " *[lo; hi]")]
#[rr::requires("1 ≤ lo ≤ hi")]
#[rr::exists("r" : "Z")]
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

/// The branch rules of upstream (see the harness entry): the action for
/// a valid dir and the callee's result r. A separate function, so that
/// RefinedRust checks the rules once and callout_step only composes.
#[rr::params("dir", "r")]
#[rr::args("dir", "r")]
#[rr::requires("0 ≤ dir ≤ 2")]
#[rr::exists("act" : "Z")]
#[rr::returns("act")]
#[rr::ensures("dir = 0 → (r = 1 → act = 1) ∧ (r = 0 → act = 0) ∧ (1 < r → act = -30) ∧ (r < 0 → act = r)")]
#[rr::ensures("dir = 1 → (0 ≤ r ≤ 1 → act = 0) ∧ (1 < r → act = -30) ∧ (r < 0 → act = r)")]
#[rr::ensures("dir = 2 → (r < 0 → act = r) ∧ (0 ≤ r → act = 1)")]
pub fn action(dir: i32, r: i32) -> i32 {
    if r < 0 {
        r
    } else if dir == DIR_EACH_MATCH {
        ACT_BACKTRACK
    } else if r > CALLOUT_FAIL {
        ERR_INVALID_ARGUMENT
    } else if dir == DIR_PROGRESS && r == CALLOUT_FAIL {
        ACT_BACKTRACK
    } else {
        ACT_CONTINUE
    }
}

/// Calls the client's callout once (valid dir) or not at all and
/// returns the action of the branch rules and, as a second component
/// that ffi.rs drops, the callee's raw result. The verified side keeps
/// its own copy of its fields and writes it back.
#[rr::params("dir", "f", "s", "len", "pos", "num", "x0", "x1", "x2", "x3", "x4", "γ")]
#[rr::args("dir", "f", "( *[s; len; pos; num; x0; x1; x2; x3; x4], γ)")]
#[rr::exists("act" : "Z", "raw" : "Z", "y0" : "Z", "y1" : "Z", "y2" : "Z", "y3" : "Z", "y4" : "Z")]
#[rr::observe("γ": "(-[#s; #len; #pos; #num; #y0; #y1; #y2; #y3; #y4] : plist place_rfnRT [loc : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT])")]
#[rr::returns(" *[act; raw]")]
#[rr::ensures("dir = 0 → (raw = 1 → act = 1) ∧ (raw = 0 → act = 0) ∧ (1 < raw → act = -30) ∧ (raw < 0 → act = raw)")]
#[rr::ensures("dir = 1 → (0 ≤ raw ≤ 1 → act = 0) ∧ (1 < raw → act = -30) ∧ (raw < 0 → act = raw)")]
#[rr::ensures("dir = 2 → (raw < 0 → act = raw) ∧ (0 ≤ raw → act = 1)")]
#[rr::ensures("¬ (0 ≤ dir ≤ 2) → act = -30 ∧ [y0; y1; y2; y3; y4] = [x0; x1; x2; x3; x4]")]
pub fn callout_step<F: Callout>(dir: i32, f: &F, args: &mut VuArgs) -> (i32, i32) {
    if dir < DIR_PROGRESS || dir > DIR_EACH_MATCH {
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
    (action(dir, r), r)
}

// -------------------------------------------- 3. vu_i_apply and vu_fold_all

/// Writes from into entry d of the record (one field per entry, see
/// VuFoldRec).
#[rr::params("c", "d", "f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7", "γ", "k", "from")]
#[rr::args("( *[c; d; f0; f1; f2; f3; f4; f5; f6; f7], γ)", "k", "from")]
#[rr::requires("0 ≤ k < 8")]
#[rr::exists("g0" : "Z", "g1" : "Z", "g2" : "Z", "g3" : "Z", "g4" : "Z", "g5" : "Z", "g6" : "Z", "g7" : "Z")]
#[rr::observe("γ": "(-[#c; #d; #g0; #g1; #g2; #g3; #g4; #g5; #g6; #g7] : plist place_rfnRT [Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT])")]
#[rr::ensures("[g0; g1; g2; g3; g4; g5; g6; g7] = <[Z.to_nat k := from]> [f0; f1; f2; f3; f4; f5; f6; f7]")]
pub fn record_at(rec: &mut VuFoldRec, k: i32, from: u32) {
    if k == 0 {
        rec.from0 = from;
    } else if k == 1 {
        rec.from1 = from;
    } else if k == 2 {
        rec.from2 = from;
    } else if k == 3 {
        rec.from3 = from;
    } else if k == 4 {
        rec.from4 = from;
    } else if k == 5 {
        rec.from5 = from;
    } else if k == 6 {
        rec.from6 = from;
    } else {
        rec.from7 = from;
    }
}

/// Whether vu_i_apply records an entry: a valid to_len and room left.
/// A separate function, so that RefinedRust checks the four tests once.
#[rr::params("to_len", "d")]
#[rr::args("to_len", "d")]
#[rr::returns("bool_decide (1 ≤ to_len ≤ 3 ∧ 0 ≤ d < 8)")]
pub fn can_record(to_len: i32, d: i32) -> bool {
    1 <= to_len && to_len <= MAX_TO_LEN && 0 <= d && d < FOLD_REC_MAX
}

/// The verified function handed to the client (re-entrancy shape (a)).
#[rr::params("from", "to_len", "c", "d", "f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7", "γ")]
#[rr::args("from", "to_len", "( *[c; d; f0; f1; f2; f3; f4; f5; f6; f7], γ)")]
#[rr::exists("c2" : "Z", "d2" : "Z", "g0" : "Z", "g1" : "Z", "g2" : "Z", "g3" : "Z", "g4" : "Z", "g5" : "Z", "g6" : "Z", "g7" : "Z")]
#[rr::observe("γ": "(-[#c2; #d2; #g0; #g1; #g2; #g3; #g4; #g5; #g6; #g7] : plist place_rfnRT [Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT])")]
#[rr::ensures("c < 2147483647 → c2 = c + 1")]
#[rr::ensures("2147483647 ≤ c → c2 = c")]
#[rr::ensures("1 ≤ to_len ≤ 3 ∧ 0 ≤ d < 8 → d2 = d + 1 ∧ [g0; g1; g2; g3; g4; g5; g6; g7] = <[Z.to_nat d := from]> [f0; f1; f2; f3; f4; f5; f6; f7]")]
#[rr::ensures("¬ (1 ≤ to_len ≤ 3 ∧ 0 ≤ d < 8) → d2 = d ∧ [g0; g1; g2; g3; g4; g5; g6; g7] = [f0; f1; f2; f3; f4; f5; f6; f7]")]
#[rr::returns("0")]
pub fn i_apply(from: u32, to_len: i32, rec: &mut VuFoldRec) -> i32 {
    let c = rec.calls;
    if c < 2147483647 {
        rec.calls = c + 1;
    }
    let d = rec.recorded;
    if can_record(to_len, d) {
        record_at(rec, d, from);
        rec.recorded = d + 1;
    }
    0
}

pub struct IApply;

impl Apply for IApply {
    #[rr::default_spec]
    fn apply(from: u32, to_len: i32, rec: &mut VuFoldRec) -> i32 {
        i_apply(from, to_len, rec)
    }
}

/// Shape (a): the client is handed IApply, the verified function; the
/// record comes back with the invariant (the client contract of
/// ApplyAll).
#[rr::params("g", "c", "d", "f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7", "γ")]
#[rr::args("g", "( *[c; d; f0; f1; f2; f3; f4; f5; f6; f7], γ)")]
#[rr::requires("0 ≤ c ∧ 0 ≤ d ≤ 8")]
#[rr::exists("r" : "Z", "c2" : "Z", "d2" : "Z", "g0" : "Z", "g1" : "Z", "g2" : "Z", "g3" : "Z", "g4" : "Z", "g5" : "Z", "g6" : "Z", "g7" : "Z")]
#[rr::observe("γ": "(-[#c2; #d2; #g0; #g1; #g2; #g3; #g4; #g5; #g6; #g7] : plist place_rfnRT [Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT])")]
#[rr::ensures("0 ≤ c2 ∧ 0 ≤ d2 ≤ 8")]
#[rr::returns("r")]
pub fn fold_all<G: ApplyAll>(g: &G, rec: &mut VuFoldRec) -> i32 {
    g.apply_all::<IApply>(rec)
}

// ------------------------------------------- 4. vu_get_slot and vu_set_slot

#[rr::params("s", "len", "pos", "num", "x0", "x1", "x2", "x3", "x4", "k", "x", "γ")]
#[rr::args(" *[s; len; pos; num; x0; x1; x2; x3; x4]", "k", "(x, γ)")]
#[rr::exists("res" : "Z", "y" : "Z")]
#[rr::observe("γ": "y")]
#[rr::returns("res")]
#[rr::ensures("0 ≤ k < 5 → res = 0 ∧ [x0; x1; x2; x3; x4] !! Z.to_nat k = Some y")]
#[rr::ensures("¬ (0 ≤ k < 5) → res = -30 ∧ y = x")]
pub fn get_slot(args: &VuArgs, k: i32, v: &mut i64) -> i32 {
    if k == 0 {
        *v = args.slot0;
    } else if k == 1 {
        *v = args.slot1;
    } else if k == 2 {
        *v = args.slot2;
    } else if k == 3 {
        *v = args.slot3;
    } else if k == 4 {
        *v = args.slot4;
    } else {
        return ERR_INVALID_ARGUMENT;
    }
    0
}

#[rr::params("s", "len", "pos", "num", "x0", "x1", "x2", "x3", "x4", "γ", "k", "v")]
#[rr::args("( *[s; len; pos; num; x0; x1; x2; x3; x4], γ)", "k", "v")]
#[rr::exists("res" : "Z", "y0" : "Z", "y1" : "Z", "y2" : "Z", "y3" : "Z", "y4" : "Z")]
#[rr::observe("γ": "(-[#s; #len; #pos; #num; #y0; #y1; #y2; #y3; #y4] : plist place_rfnRT [loc : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT; Z : RT])")]
#[rr::returns("res")]
#[rr::ensures("0 ≤ k < 5 → res = 0 ∧ [y0; y1; y2; y3; y4] = <[Z.to_nat k := v]> [x0; x1; x2; x3; x4]")]
#[rr::ensures("¬ (0 ≤ k < 5) → res = -30 ∧ [y0; y1; y2; y3; y4] = [x0; x1; x2; x3; x4]")]
pub fn set_slot(args: &mut VuArgs, k: i32, v: i64) -> i32 {
    if k == 0 {
        args.slot0 = v;
    } else if k == 1 {
        args.slot1 = v;
    } else if k == 2 {
        args.slot2 = v;
    } else if k == 3 {
        args.slot3 = v;
    } else if k == 4 {
        args.slot4 = v;
    } else {
        return ERR_INVALID_ARGUMENT;
    }
    0
}

// ------------------------------------------- 5. vu_get_subject_byte

/// The read accessor: a raw-pointer read (ptr::add, then ptr::read) of
/// byte i of the subject. The precondition owns the subject's len bytes
/// at s (an array of u8), and states that s's allocation is alive and
/// that the len bytes are in its bounds: proto.h's invariant of vu_args,
/// met by the C caller through ffi.rs (trusted). The postcondition gives
/// the bytes and the liveness back unchanged. RefinedRust has no
/// read-only share of a raw pointer's target here, so the subject is
/// lent whole, as in CN and Isabelle-LLVM. The proof is manual
/// (proofs/proof_get_subject_byte.v): RefinedRust's automation does not
/// pick the array element out of the owned array by itself.
#[rr::params("s", "len", "pos", "num", "x0", "x1", "x2", "x3", "x4", "bs", "q", "i")]
#[rr::args(" *[s; len; pos; num; x0; x1; x2; x3; x4]", "i")]
#[rr::requires("len = length bs")]
#[rr::requires(#type "s" : "<#> bs" @ "array_t (length bs) (int u8)")]
#[rr::requires(#iris "alloc_alive_witness AliveAlloc s q")]
#[rr::requires(#iris "loc_in_bounds s 0 (length bs)")]
#[rr::exists("res" : "Z")]
#[rr::ensures(#type "s" : "<#> bs" @ "array_t (length bs) (int u8)")]
#[rr::ensures(#iris "alloc_alive_witness AliveAlloc s q")]
#[rr::returns("res")]
#[rr::ensures("0 ≤ i < len → bs !! Z.to_nat i = Some res")]
#[rr::ensures("¬ (0 ≤ i < len) → res = -30")]
pub fn get_subject_byte(args: &VuArgs, i: i32) -> i32 {
    // VU-READ-BEGIN
    if 0 <= i && i < args.subject_len {
    // VU-READ-END
        unsafe { args.subject.add(i as usize).read() as i32 }
    } else {
        ERR_INVALID_ARGUMENT
    }
}
