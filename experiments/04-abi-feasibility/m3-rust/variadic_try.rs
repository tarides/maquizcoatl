// variadic_try.rs: the direct Rust definition of the variadic
// onig_error_code_to_str. Compiled alone with stable rustc to record
// whether C-variadic definitions are accepted (criterion 5 evidence).
use core::ffi::{c_int, c_uchar};

#[unsafe(no_mangle)]
pub unsafe extern "C" fn onig_error_code_to_str(s: *mut c_uchar, code: c_int, mut args: ...) -> c_int {
    let _einfo: *mut core::ffi::c_void = unsafe { args.arg() };
    let _ = (s, code);
    0
}
