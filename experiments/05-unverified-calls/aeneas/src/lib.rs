// lib.rs: the Charon + Aeneas prototype of experiment 5 (verified part).
//
// The four verified functions of proto.h, in safe Rust: char_len
// (vu_char_len), callout_step (vu_callout_step), i_apply and fold_all
// (vu_i_apply, vu_fold_all), get_slot and set_slot (vu_get_slot,
// vu_set_slot), get_subject_byte (vu_get_subject_byte). Charon and Aeneas translate this file to Lean, where
// proofs/Proofs.lean proves their specifications. The same file is
// compiled by rustc into the C library; the C entry points are in
// ffi.rs, which Charon does not translate (build.sh: --exclude).
//
// Aeneas has no type for function pointers ("Arrow types are not
// supported yet"), so each client C function is a trait: the verified
// functions are generic over it, and the Lean model quantifies over
// every implementation (the callee is a parameter, not an axiom). The
// only implementations are in ffi.rs; each one does the indirect call
// and nothing else.
//
// Two marker comments delimit the clamp that the negative control
// removes, two more the bound test that the read control removes.

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
/// side's state; only the slots may change across a callout.
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

// ---------------------------------------------------------- client traits

/// A client vu_enc_len_fn. p is passed through, never read here.
pub trait EncLen {
    fn enc_len(&self, p: *const u8) -> i32;
}

/// A client vu_callout_fn with its user_data. The callee is lent args
/// mutably for the call.
pub trait Callout {
    fn callout(&self, args: &mut VuArgs) -> i32;
}

/// A verified function that can be handed to the client as a
/// vu_apply_fn. The method has no receiver, so that ffi.rs can turn the
/// type into a C function pointer without a value of it.
pub trait Apply {
    fn apply(from: u32, to_len: i32, rec: &mut VuFoldRec) -> i32;
}

/// A client vu_apply_all_fn: it is given the verified function A (as a
/// C pointer, by ffi.rs) and the record.
pub trait ApplyAll {
    fn apply_all<A: Apply>(&self, rec: &mut VuFoldRec) -> i32;
}

// ------------------------------------------------------------ 1. vu_char_len

/// Calls the client's encoding function f on p and clamps its result to
/// the bounds in st. Nothing is assumed of the callee's result. st is a
/// shared reference that the callee is not given.
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

/// Calls the client's callout f once (valid dir) or not at all (invalid
/// dir) and returns the action of the branch rules
/// (lab/results/2026-11-19-exp-05-harness.md):
/// - progress, upstream/src/regexec.c:4616-4631: FAIL backtracks,
///   SUCCESS continues, another positive value is
///   ONIGERR_INVALID_ARGUMENT, a negative value is returned;
/// - retraction, upstream/src/regexec.c:1218-1234: FAIL and SUCCESS
///   continue, otherwise as in progress;
/// - each-match, upstream/src/regexec.c:3387-3400: a negative value is
///   returned, anything else backtracks (the search goes on).
///
/// The callee may write anything into args. The verified side does not
/// trust what it finds there: it keeps its own copy of its state and
/// writes it back, so only the slots carry the callee's writes.
pub fn callout_step<F: Callout>(dir: i32, f: &F, args: &mut VuArgs) -> i32 {
    if !(dir == DIR_PROGRESS || dir == DIR_RETRACTION || dir == DIR_EACH_MATCH) {
        return ERR_INVALID_ARGUMENT;
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
    if dir == DIR_PROGRESS {
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
    }
}

// -------------------------------------------- 3. vu_i_apply and vu_fold_all

/// The verified function handed to the client (re-entrancy shape (a),
/// as i_apply_case_fold, upstream/src/regparse.c:8739): calls saturates
/// at i32::MAX, from is appended when 1 <= to_len <= MAX_TO_LEN and the
/// record is not full. It never reads the client's to array, which
/// ffi.rs does not pass on.
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

/// i_apply as an Apply.
pub struct IApply;

impl Apply for IApply {
    fn apply(from: u32, to_len: i32, rec: &mut VuFoldRec) -> i32 {
        i_apply(from, to_len, rec)
    }
}

/// Hands i_apply and rec to the client's apply-all function g and
/// returns g's result.
pub fn fold_all<G: ApplyAll>(g: &G, rec: &mut VuFoldRec) -> i32 {
    g.apply_all::<IApply>(rec)
}

// ------------------------------------------- 4. vu_get_slot and vu_set_slot

/// Reads slot k into v; out of bounds, returns ERR_INVALID_ARGUMENT and
/// leaves v untouched.
pub fn get_slot(args: &VuArgs, k: i32, v: &mut i64) -> i32 {
    if 0 <= k && k < SLOT_NUM {
        *v = args.slot[k as usize];
        0
    } else {
        ERR_INVALID_ARGUMENT
    }
}

/// Writes v into slot k; out of bounds, returns ERR_INVALID_ARGUMENT and
/// writes nothing.
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
/// slice: the raw pointer held in args has no model in Aeneas (a
/// ConstRawPtr is opaque), so ffi.rs (trusted) makes the slice from
/// args.subject and args.subject_len; the theorem takes their agreement
/// as a hypothesis. Both args and the subject are shared references,
/// hence unchanged.
pub fn get_subject_byte(args: &VuArgs, subject: &[u8], i: i32) -> i32 {
    // VU-READ-BEGIN
    if 0 <= i && i < args.subject_len {
    // VU-READ-END
        subject[i as usize] as i32
    } else {
        ERR_INVALID_ARGUMENT
    }
}
