// ffi.rs: the C entry points of the Verus prototype (trusted glue,
// outside verus!, not verified). Each one turns the C arguments into the
// references and opaque values the verified functions of lib.rs take,
// and calls them. The checks here are the system boundary: a NULL
// pointer aborts (proto.h requires non-NULL pointers; C would crash on
// them anyway). Non-NULL pointers are trusted to be valid, aligned, and
// not written by anyone else while the verified function holds the
// reference made from them.

use core::ffi::{c_int, c_uint, c_void};
use core::mem::{align_of, offset_of, size_of};

use crate::shim::{ApplyAllFn, CalloutFn, EncLenFn, UserData};
use crate::{VuArgs, VuEncState, VuFoldRec};

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
// field (an array member is checked at its start).
const _: () = assert!(
    offset_of!(VuEncState, min_enc_len) == 0 && offset_of!(VuEncState, max_enc_len) == 4
);
const _: () = assert!(
    offset_of!(VuArgs, subject) == 0
        && offset_of!(VuArgs, subject_len) == 8
        && offset_of!(VuArgs, pos) == 12
        && offset_of!(VuArgs, num) == 16
        && offset_of!(VuArgs, slot) == 24
);
const _: () = assert!(
    offset_of!(VuFoldRec, calls) == 0
        && offset_of!(VuFoldRec, recorded) == 4
        && offset_of!(VuFoldRec, from) == 8
);

fn some<T>(x: Option<T>) -> T {
    match x {
        Some(x) => x,
        None => std::process::abort(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn vu_char_len(
    f: VuEncLenFn,
    p: *const u8,
    st: *const VuEncState,
) -> c_int {
    let st = some(unsafe { st.as_ref() });
    crate::char_len(&EncLenFn(some(f)), p, st)
}

#[no_mangle]
pub unsafe extern "C" fn vu_callout_step(
    dir: c_int,
    f: VuCalloutFn,
    args: *mut VuArgs,
    user_data: *mut c_void,
) -> c_int {
    let args = some(unsafe { args.as_mut() });
    crate::callout_step(dir, &CalloutFn(some(f)), args, &UserData(user_data)).0
}

#[no_mangle]
pub unsafe extern "C" fn vu_i_apply(
    from: c_uint,
    _to: *mut c_uint,
    to_len: c_int,
    arg: *mut c_void,
) -> c_int {
    let rec = some(unsafe { (arg as *mut VuFoldRec).as_mut() });
    crate::i_apply(from, to_len, rec)
}

#[no_mangle]
pub unsafe extern "C" fn vu_fold_all(g: VuApplyAllFn, rec: *mut VuFoldRec) -> c_int {
    let rec = some(unsafe { rec.as_mut() });
    crate::fold_all(&ApplyAllFn(some(g)), rec)
}

#[no_mangle]
pub unsafe extern "C" fn vu_get_slot(args: *const VuArgs, k: c_int, v: *mut i64) -> c_int {
    let args = some(unsafe { args.as_ref() });
    let v = some(unsafe { v.as_mut() });
    crate::get_slot(args, k, v)
}

#[no_mangle]
pub unsafe extern "C" fn vu_set_slot(args: *mut VuArgs, k: c_int, v: i64) -> c_int {
    let args = some(unsafe { args.as_mut() });
    crate::set_slot(args, k, v)
}
