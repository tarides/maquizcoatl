// ffi.rs: the C entry points of the RefinedRust prototype (trusted
// glue, every item #[rr::skip]: not translated, not verified). Adapted
// from the hax prototype's ffi.rs (the raw result of callout_step is
// dropped here; the subject is a raw pointer in VuArgs, read by the
// verified get_subject_byte), with the #[rr::skip] attributes added. It
// holds:
// - the C function pointer types of proto.h;
// - one implementation of each client trait of lib.rs, which does the
//   indirect call and nothing else (the trusted shims);
// - c_apply, the C entry point of a verified Apply, which is what the
//   client of vu_fold_all is handed;
// - the exported functions of proto.h, which turn C arguments into the
//   references and trait values the verified functions take.
// The checks here are the system boundary: a NULL pointer aborts
// (proto.h requires non-NULL pointers; C would crash on them anyway).
// Non-NULL pointers are trusted to be valid, aligned, and not written
// by anyone else while the verified function holds the reference made
// from them, except by the callee it calls, which is given that very
// reference as a raw pointer.

use core::ffi::{c_int, c_uint, c_void};
use core::mem::{align_of, offset_of, size_of};

use crate::{Apply, ApplyAll, Callout, EncLen, IApply, VuArgs, VuEncState, VuFoldRec};

// The function pointer types of proto.h. NULL is None.
pub type VuEncLenFn = Option<unsafe extern "C" fn(*const u8) -> c_int>;
pub type VuCalloutFn = Option<unsafe extern "C" fn(*mut VuArgs, *mut c_void) -> c_int>;
pub type VuApplyFn = Option<unsafe extern "C" fn(c_uint, *mut c_uint, c_int, *mut c_void) -> c_int>;
pub type VuApplyAllFn = Option<unsafe extern "C" fn(VuApplyFn, *mut c_void) -> c_int>;

// The layouts of proto.h on LP64 targets (Linux and macOS, x86_64 and
// aarch64).
const _: () = assert!(size_of::<VuEncState>() == 8 && align_of::<VuEncState>() == 4);
const _: () = assert!(size_of::<VuArgs>() == 64 && align_of::<VuArgs>() == 8);
const _: () = assert!(size_of::<VuFoldRec>() == 40 && align_of::<VuFoldRec>() == 4);
// The member offsets, so that the mirrors of lib.rs are checked field by
// field. lib.rs spells the arrays slot[5] and from[8] of proto.h as one
// field per element: each element field must sit where the C array puts
// that element (start + index * element size).
const _: () = assert!(
    offset_of!(VuEncState, min_enc_len) == 0 && offset_of!(VuEncState, max_enc_len) == 4
);
const _: () = assert!(
    offset_of!(VuArgs, subject) == 0
        && offset_of!(VuArgs, subject_len) == 8
        && offset_of!(VuArgs, pos) == 12
        && offset_of!(VuArgs, num) == 16
        && offset_of!(VuArgs, slot0) == 24
        && offset_of!(VuArgs, slot1) == 32
        && offset_of!(VuArgs, slot2) == 40
        && offset_of!(VuArgs, slot3) == 48
        && offset_of!(VuArgs, slot4) == 56
);
const _: () = assert!(
    offset_of!(VuFoldRec, calls) == 0
        && offset_of!(VuFoldRec, recorded) == 4
        && offset_of!(VuFoldRec, from0) == 8
        && offset_of!(VuFoldRec, from1) == 12
        && offset_of!(VuFoldRec, from2) == 16
        && offset_of!(VuFoldRec, from3) == 20
        && offset_of!(VuFoldRec, from4) == 24
        && offset_of!(VuFoldRec, from5) == 28
        && offset_of!(VuFoldRec, from6) == 32
        && offset_of!(VuFoldRec, from7) == 36
);

#[rr::skip]
fn some<T>(x: Option<T>) -> T {
    match x {
        Some(x) => x,
        None => std::process::abort(),
    }
}

// ------------------------------------------------------------ the shims

#[rr::skip]
struct CEncLen(unsafe extern "C" fn(*const u8) -> c_int);

// p is the address that vu_char_len exposed (expose_provenance), so the
// pointer rebuilt from it is the caller's pointer.
#[rr::skip]
impl EncLen for CEncLen {
    fn enc_len(&self, p: usize) -> i32 {
        unsafe { (self.0)(core::ptr::with_exposed_provenance(p)) }
    }
}

#[rr::skip]
struct CCallout {
    f: unsafe extern "C" fn(*mut VuArgs, *mut c_void) -> c_int,
    user_data: *mut c_void,
}

#[rr::skip]
impl Callout for CCallout {
    fn callout(&self, args: &mut VuArgs) -> i32 {
        unsafe { (self.f)(args as *mut VuArgs, self.user_data) }
    }
}

#[rr::skip]
struct CApplyAll(unsafe extern "C" fn(VuApplyFn, *mut c_void) -> c_int);

#[rr::skip]
impl ApplyAll for CApplyAll {
    fn apply_all<A: Apply>(&self, rec: &mut VuFoldRec) -> i32 {
        unsafe { (self.0)(Some(c_apply::<A>), rec as *mut VuFoldRec as *mut c_void) }
    }
}

/// The C entry point of the verified function A, as a vu_apply_fn:
/// arg must point to a vu_fold_rec; to is not read.
#[rr::skip]
unsafe extern "C" fn c_apply<A: Apply>(
    from: c_uint,
    _to: *mut c_uint,
    to_len: c_int,
    arg: *mut c_void,
) -> c_int {
    let rec = some(unsafe { (arg as *mut VuFoldRec).as_mut() });
    A::apply(from, to_len, rec)
}

// ---------------------------------------------------- exported functions

#[rr::skip]
#[no_mangle]
pub unsafe extern "C" fn vu_char_len(
    f: VuEncLenFn,
    p: *const u8,
    st: *const VuEncState,
) -> c_int {
    let st = some(unsafe { st.as_ref() });
    // The precondition of char_len (proto.h's precondition of
    // vu_char_len) is the C caller's to meet; it is not checked here.
    crate::char_len(&CEncLen(some(f)), p.expose_provenance(), st)
}

#[rr::skip]
#[no_mangle]
pub unsafe extern "C" fn vu_callout_step(
    dir: c_int,
    f: VuCalloutFn,
    args: *mut VuArgs,
    user_data: *mut c_void,
) -> c_int {
    let args = some(unsafe { args.as_mut() });
    crate::callout_step(dir, &CCallout { f: some(f), user_data }, args).0
}

#[rr::skip]
#[no_mangle]
pub unsafe extern "C" fn vu_i_apply(
    from: c_uint,
    to: *mut c_uint,
    to_len: c_int,
    arg: *mut c_void,
) -> c_int {
    unsafe { c_apply::<IApply>(from, to, to_len, arg) }
}

#[rr::skip]
#[no_mangle]
pub unsafe extern "C" fn vu_fold_all(g: VuApplyAllFn, rec: *mut VuFoldRec) -> c_int {
    let rec = some(unsafe { rec.as_mut() });
    crate::fold_all(&CApplyAll(some(g)), rec)
}

#[rr::skip]
#[no_mangle]
pub unsafe extern "C" fn vu_get_slot(args: *const VuArgs, k: c_int, v: *mut i64) -> c_int {
    let args = some(unsafe { args.as_ref() });
    let v = some(unsafe { v.as_mut() });
    crate::get_slot(args, k, v)
}

#[rr::skip]
#[no_mangle]
pub unsafe extern "C" fn vu_set_slot(args: *mut VuArgs, k: c_int, v: i64) -> c_int {
    let args = some(unsafe { args.as_mut() });
    crate::set_slot(args, k, v)
}

#[rr::skip]
#[no_mangle]
pub unsafe extern "C" fn vu_get_subject_byte(args: *const VuArgs, i: c_int) -> c_int {
    let args = some(unsafe { args.as_ref() });
    // proto.h's invariant of vu_args (subject points to subject_len
    // readable bytes that nobody writes during the call) is the
    // precondition of get_subject_byte; it is the C caller's to meet.
    crate::get_subject_byte(args, i)
}
