// lib.rs: the Verus prototype of experiment 5 (verified part).
//
// The four verified functions of proto.h, with their specifications:
// vu_char_len (char_len), vu_callout_step (callout_step), vu_i_apply and
// vu_fold_all (i_apply, fold_all), vu_get_slot and vu_set_slot
// (get_slot, set_slot), and the read accessor vu_get_subject_byte
// (get_subject_byte). The client's function pointers are called only
// through the trusted shims of shim.rs, whose specifications say
// nothing about the callee's result or about what the callee does to
// the memory it is lent. The C entry points are in ffi.rs.
//
// Build and check: see build.sh. Two marker comments delimit the clamp
// that the negative control removes, two more the bound test that the
// read control removes.

use vstd::prelude::*;

mod ffi;
mod shim;

use shim::*;

verus! {

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

// ------------------------------------------------------------ 1. vu_char_len

/// Calls the client's encoding function f on p and clamps its result to
/// the bounds in st. The callee is trusted for nothing but returning
/// an i32: call_enc_len has no postcondition. The function is total:
/// when the bounds are well ordered (proto.h requires
/// 1 <= min_enc_len <= max_enc_len), the result is within them.
/// st is a shared reference, so it is unchanged across the call; the
/// callee is not given st.
pub fn char_len(f: &EncLenFn, p: *const u8, st: &VuEncState) -> (r: i32)
    ensures
        st.min_enc_len <= st.max_enc_len ==> st.min_enc_len <= r <= st.max_enc_len,
{
    let ghost st0 = *st;
    let raw = call_enc_len(f, p);
    // A shared reference: Verus knows st is unchanged by the call.
    assert(*st == st0);
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

pub open spec fn valid_dir(dir: i32) -> bool {
    dir == DIR_PROGRESS || dir == DIR_RETRACTION || dir == DIR_EACH_MATCH
}

/// The action for a callee result r in direction dir
/// (lab/results/2026-11-19-exp-05-harness.md):
/// - progress, upstream/src/regexec.c:4616-4631: FAIL backtracks,
///   SUCCESS continues, another positive value is
///   ONIGERR_INVALID_ARGUMENT, a negative value is returned;
/// - retraction, upstream/src/regexec.c:1218-1234: FAIL and SUCCESS
///   continue, otherwise as in progress;
/// - each-match, upstream/src/regexec.c:3387-3400: a negative value is
///   returned, anything else backtracks (the search goes on).
pub open spec fn step_rule(dir: i32, r: i32) -> i32 {
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

/// The verified side's state in a VuArgs: everything but the slots.
pub open spec fn same_engine_state(a: VuArgs, b: VuArgs) -> bool {
    &&& a.subject == b.subject
    &&& a.subject_len == b.subject_len
    &&& a.pos == b.pos
    &&& a.num == b.num
}

/// Calls the client's callout f once (valid dir) or not at all (invalid
/// dir) and returns the action of step_rule. The ghost component is the
/// callee's result, None when f was not called.
///
/// The callee is lent args mutably for the call (it may call
/// vu_get_slot and vu_set_slot by name, re-entrancy shape (b)), and
/// call_callout promises nothing about args afterwards. The verified
/// side does not trust what it finds there: it keeps its own copy of
/// its state and writes it back, so the postcondition holds whatever
/// the callee wrote. Only the slots carry the callee's writes.
pub fn callout_step(dir: i32, f: &CalloutFn, args: &mut VuArgs, ud: &UserData) -> (res: (
    i32,
    Ghost<Option<i32>>,
))
    ensures
        same_engine_state(*final(args), *old(args)),
        match res.1@ {
            Some(r) => valid_dir(dir) && res.0 == step_rule(dir, r),
            None => !valid_dir(dir) && res.0 == ERR_INVALID_ARGUMENT && final(args).slot@ == old(
                args,
            ).slot@,
        },
{
    if !(dir == DIR_PROGRESS || dir == DIR_RETRACTION || dir == DIR_EACH_MATCH) {
        return (ERR_INVALID_ARGUMENT, Ghost(None));
    }
    let subject = args.subject;
    let subject_len = args.subject_len;
    let pos = args.pos;
    let num = args.num;
    let r = call_callout(f, args, ud);
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
    (act, Ghost(Some(r)))
}

// -------------------------------------------- 3. vu_i_apply and vu_fold_all

/// The effect of one vu_i_apply call on the record: calls saturates at
/// i32::MAX, from is appended when 1 <= to_len <= MAX_TO_LEN and the
/// record is not full (a record whose count is out of range, which only
/// a misbehaving client can build, is left as it is).
pub open spec fn i_apply_post(old: VuFoldRec, new: VuFoldRec, from: u32, to_len: i32) -> bool {
    &&& new.calls == (if old.calls < i32::MAX {
        old.calls + 1
    } else {
        old.calls as int
    })
    &&& if 1 <= to_len <= MAX_TO_LEN && 0 <= old.recorded < FOLD_REC_MAX {
        &&& new.recorded == old.recorded + 1
        &&& new.from@ == old.from@.update(old.recorded as int, from)
    } else {
        &&& new.recorded == old.recorded
        &&& new.from@ == old.from@
    }
}

/// The verified function that fold_all hands to the client as a C
/// pointer (re-entrancy shape (a), as i_apply_case_fold,
/// upstream/src/regparse.c:8739). It never reads the client's to array,
/// which ffi.rs does not even pass on.
pub fn i_apply(from: u32, to_len: i32, rec: &mut VuFoldRec) -> (r: i32)
    ensures
        r == 0,
        i_apply_post(*old(rec), *final(rec), from, to_len),
{
    if rec.calls < i32::MAX {
        rec.calls = rec.calls + 1;
    }
    if 1 <= to_len && to_len <= MAX_TO_LEN && 0 <= rec.recorded && rec.recorded < FOLD_REC_MAX {
        rec.from[rec.recorded as usize] = from;
        rec.recorded = rec.recorded + 1;
    }
    0
}

/// Hands vu_i_apply and rec to the client's apply-all function g and
/// returns g's result. Nothing is proven about rec afterwards: the
/// client holds the pointer during the call, and Verus has no way to
/// state that it only reaches rec through vu_i_apply (each of those
/// calls does satisfy i_apply_post).
pub fn fold_all(g: &ApplyAllFn, rec: &mut VuFoldRec) -> (r: i32) {
    call_apply_all(g, rec)
}

// ------------------------------------------- 4. vu_get_slot and vu_set_slot

pub open spec fn slot_index_ok(k: i32) -> bool {
    0 <= k < SLOT_NUM
}

/// Reads slot k into v; out of bounds, returns ERR_INVALID_ARGUMENT and
/// leaves v untouched.
pub fn get_slot(args: &VuArgs, k: i32, v: &mut i64) -> (r: i32)
    ensures
        slot_index_ok(k) ==> r == 0 && *final(v) == args.slot@[k as int],
        !slot_index_ok(k) ==> r == ERR_INVALID_ARGUMENT && *final(v) == *old(v),
{
    if 0 <= k && k < SLOT_NUM {
        *v = args.slot[k as usize];
        0
    } else {
        ERR_INVALID_ARGUMENT
    }
}

/// Writes v into slot k; out of bounds, returns ERR_INVALID_ARGUMENT and
/// writes nothing. Only slot k may change: the verified side's state and
/// the other slots are unchanged.
pub fn set_slot(args: &mut VuArgs, k: i32, v: i64) -> (r: i32)
    ensures
        same_engine_state(*final(args), *old(args)),
        slot_index_ok(k) ==> r == 0 && final(args).slot@ == old(args).slot@.update(k as int, v),
        !slot_index_ok(k) ==> r == ERR_INVALID_ARGUMENT && final(args).slot@ == old(args).slot@,
{
    if 0 <= k && k < SLOT_NUM {
        args.slot[k as usize] = v;
        0
    } else {
        ERR_INVALID_ARGUMENT
    }
}

// ------------------------------------------- 5. vu_get_subject_byte

pub open spec fn subject_index_ok(args: VuArgs, i: i32) -> bool {
    0 <= i < args.subject_len
}

/// Reads byte i of the subject; out of [0, subject_len), returns
/// ERR_INVALID_ARGUMENT and reads nothing. The subject is a shared
/// slice: Verus has no way to read through the raw pointer held in
/// args, so ffi.rs (trusted) makes the slice from args.subject and
/// args.subject_len; the precondition records that agreement. Both
/// args and the subject are shared references, hence unchanged.
pub fn get_subject_byte(args: &VuArgs, subject: &[u8], i: i32) -> (r: i32)
    requires
        subject@.len() == args.subject_len,
    ensures
        subject_index_ok(*args, i) ==> r == subject@[i as int] as i32,
        !subject_index_ok(*args, i) ==> r == ERR_INVALID_ARGUMENT,
{
    // VU-READ-BEGIN
    if 0 <= i && i < args.subject_len {
    // VU-READ-END
        subject[i as usize] as i32
    } else {
        ERR_INVALID_ARGUMENT
    }
}

} // verus!
