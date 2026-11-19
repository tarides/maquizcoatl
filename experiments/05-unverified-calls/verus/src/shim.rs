// shim.rs: trusted shims of the Verus prototype. Verus cannot type or
// call a C function pointer, so each client pointer is an opaque type
// (external_body struct) and each indirect call is an external_body
// function that does only that call and returns the raw result. Their
// specifications are empty: no range for the result, and a mutable
// argument may hold anything afterwards.

use core::ffi::c_void;
use vstd::prelude::*;

use crate::{VuArgs, VuFoldRec};

verus! {

/// A client vu_enc_len_fn, never NULL (ffi.rs checks).
#[verifier::external_body]
pub struct EncLenFn(pub(crate) unsafe extern "C" fn(*const u8) -> i32);

/// A client vu_callout_fn, never NULL (ffi.rs checks).
#[verifier::external_body]
pub struct CalloutFn(pub(crate) unsafe extern "C" fn(*mut VuArgs, *mut c_void) -> i32);

/// A client vu_apply_all_fn, never NULL (ffi.rs checks).
#[verifier::external_body]
pub struct ApplyAllFn(pub(crate) unsafe extern "C" fn(crate::ffi::VuApplyFn, *mut c_void) -> i32);

/// The client's user_data, passed through untouched.
#[verifier::external_body]
pub struct UserData(pub(crate) *mut c_void);

/// f(p). Promises nothing about the result.
#[verifier::external_body]
pub fn call_enc_len(f: &EncLenFn, p: *const u8) -> (r: i32) {
    unsafe { (f.0)(p) }
}

/// f(args, ud). Promises nothing about the result nor about args
/// afterwards.
#[verifier::external_body]
pub fn call_callout(f: &CalloutFn, args: &mut VuArgs, ud: &UserData) -> (r: i32) {
    unsafe { (f.0)(args as *mut VuArgs, ud.0) }
}

/// g(vu_i_apply, rec). Promises nothing about the result nor about rec
/// afterwards.
#[verifier::external_body]
pub fn call_apply_all(g: &ApplyAllFn, rec: &mut VuFoldRec) -> (r: i32) {
    unsafe { (g.0)(Some(crate::ffi::vu_i_apply), rec as *mut VuFoldRec as *mut c_void) }
}

} // verus!
