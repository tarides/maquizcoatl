//! Mechanism 3: libonig stub as a Rust `cdylib`.
//! `#[repr(C)]` mirrors of the public structs of oniguruma.h and
//! onigposix.h, the 44 public data symbols as `#[unsafe(no_mangle)]`
//! statics (encoding structs hold function pointers), and the
//! generated `extern "C"` functions (see gen_rust_stub.py).
#![allow(non_upper_case_globals, non_camel_case_types, non_snake_case)]
#![allow(static_mut_refs)]

use core::ffi::{c_char, c_int, c_long, c_uint, c_void};

pub type OnigUChar = u8;
pub type OnigCodePoint = c_uint;
pub type OnigCtype = c_uint;
pub type OnigCaseFoldType = c_uint;
pub type OnigOptionType = c_uint;
pub type OnigApplyAllCaseFoldFunc =
    Option<unsafe extern "C" fn(OnigCodePoint, *mut OnigCodePoint, c_int, *mut c_void) -> c_int>;

#[repr(C)]
#[derive(Clone, Copy)]
pub struct OnigCaseFoldCodeItem {
    pub byte_len: c_int,
    pub code_len: c_int,
    pub code: [OnigCodePoint; 3],
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct OnigMetaCharTableType {
    pub esc: OnigCodePoint,
    pub anychar: OnigCodePoint,
    pub anytime: OnigCodePoint,
    pub zero_or_one_time: OnigCodePoint,
    pub one_or_more_time: OnigCodePoint,
    pub anychar_anytime: OnigCodePoint,
}

#[repr(C)]
pub struct OnigEncodingType {
    pub mbc_enc_len: Option<unsafe extern "C" fn(*const OnigUChar) -> c_int>,
    pub name: *const c_char,
    pub max_enc_len: c_int,
    pub min_enc_len: c_int,
    pub is_mbc_newline: Option<unsafe extern "C" fn(*const OnigUChar, *const OnigUChar) -> c_int>,
    pub mbc_to_code: Option<unsafe extern "C" fn(*const OnigUChar, *const OnigUChar) -> OnigCodePoint>,
    pub code_to_mbclen: Option<unsafe extern "C" fn(OnigCodePoint) -> c_int>,
    pub code_to_mbc: Option<unsafe extern "C" fn(OnigCodePoint, *mut OnigUChar) -> c_int>,
    pub mbc_case_fold: Option<
        unsafe extern "C" fn(OnigCaseFoldType, *mut *const OnigUChar, *const OnigUChar, *mut OnigUChar) -> c_int,
    >,
    pub apply_all_case_fold:
        Option<unsafe extern "C" fn(OnigCaseFoldType, OnigApplyAllCaseFoldFunc, *mut c_void) -> c_int>,
    pub get_case_fold_codes_by_str: Option<
        unsafe extern "C" fn(OnigCaseFoldType, *const OnigUChar, *const OnigUChar, *mut OnigCaseFoldCodeItem) -> c_int,
    >,
    pub property_name_to_ctype:
        Option<unsafe extern "C" fn(*mut OnigEncodingType, *mut OnigUChar, *mut OnigUChar) -> c_int>,
    pub is_code_ctype: Option<unsafe extern "C" fn(OnigCodePoint, OnigCtype) -> c_int>,
    pub get_ctype_code_range:
        Option<unsafe extern "C" fn(OnigCtype, *mut OnigCodePoint, *mut *const OnigCodePoint) -> c_int>,
    pub left_adjust_char_head:
        Option<unsafe extern "C" fn(*const OnigUChar, *const OnigUChar) -> *mut OnigUChar>,
    pub is_allowed_reverse_match: Option<unsafe extern "C" fn(*const OnigUChar, *const OnigUChar) -> c_int>,
    pub init: Option<unsafe extern "C" fn() -> c_int>,
    pub is_initialized: Option<unsafe extern "C" fn() -> c_int>,
    pub is_valid_mbc_string: Option<unsafe extern "C" fn(*const OnigUChar, *const OnigUChar) -> c_int>,
    pub flag: c_uint,
    pub sb_range: OnigCodePoint,
    pub index: c_int,
}

#[repr(C)]
pub struct OnigSyntaxType {
    pub op: c_uint,
    pub op2: c_uint,
    pub behavior: c_uint,
    pub options: OnigOptionType,
    pub meta_char_table: OnigMetaCharTableType,
}

#[repr(C)]
pub struct OnigCaptureTreeNode {
    pub group: c_int,
    pub beg: c_int,
    pub end: c_int,
    pub allocated: c_int,
    pub num_childs: c_int,
    pub childs: *mut *mut OnigCaptureTreeNode,
}

#[repr(C)]
pub struct OnigRegion {
    pub allocated: c_int,
    pub num_regs: c_int,
    pub beg: *mut c_int,
    pub end: *mut c_int,
    pub history_root: *mut OnigCaptureTreeNode,
}

#[repr(C)]
pub struct OnigErrorInfo {
    pub enc: *mut OnigEncodingType,
    pub par: *mut OnigUChar,
    pub par_end: *mut OnigUChar,
}

#[repr(C)]
pub struct OnigRepeatRange {
    pub lower: c_int,
    pub upper: c_int,
}

#[repr(C)]
pub struct OnigCompileInfo {
    pub num_of_elements: c_int,
    pub pattern_enc: *mut OnigEncodingType,
    pub target_enc: *mut OnigEncodingType,
    pub syntax: *mut OnigSyntaxType,
    pub option: OnigOptionType,
    pub case_fold_flag: OnigCaseFoldType,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct OnigValue_s {
    pub start: *mut OnigUChar,
    pub end: *mut OnigUChar,
}

#[repr(C)]
pub union OnigValue {
    pub l: c_long,
    pub c: OnigCodePoint,
    pub s: OnigValue_s,
    pub p: *mut c_void,
    pub tag: c_int,
}

#[repr(C)]
pub struct onig_posix_regmatch_t {
    pub rm_so: c_int,
    pub rm_eo: c_int,
}

#[repr(C)]
pub struct onig_posix_regex_t {
    pub onig: *mut c_void,
    pub re_nsub: usize,
    pub comp_options: c_int,
}

// ---- encoding callbacks shared by the 30 stub encodings
unsafe extern "C" fn s_mbc_enc_len(_p: *const OnigUChar) -> c_int { 1 }
unsafe extern "C" fn s_is_mbc_newline(p: *const OnigUChar, end: *const OnigUChar) -> c_int {
    (p < end && unsafe { *p } == 0x0a) as c_int
}
unsafe extern "C" fn s_mbc_to_code(p: *const OnigUChar, _e: *const OnigUChar) -> OnigCodePoint {
    unsafe { *p as OnigCodePoint }
}
unsafe extern "C" fn s_code_to_mbclen(_c: OnigCodePoint) -> c_int { 1 }
unsafe extern "C" fn s_code_to_mbc(c: OnigCodePoint, buf: *mut OnigUChar) -> c_int {
    unsafe { *buf = c as OnigUChar };
    1
}
unsafe extern "C" fn s_mbc_case_fold(
    _f: OnigCaseFoldType, pp: *mut *const OnigUChar, _e: *const OnigUChar, to: *mut OnigUChar,
) -> c_int {
    unsafe {
        *to = **pp;
        *pp = (*pp).add(1);
    }
    1
}
unsafe extern "C" fn s_apply_all_case_fold(_f: OnigCaseFoldType, _fn: OnigApplyAllCaseFoldFunc, _a: *mut c_void) -> c_int { 0 }
unsafe extern "C" fn s_get_case_fold_codes_by_str(
    _f: OnigCaseFoldType, _p: *const OnigUChar, _e: *const OnigUChar, _a: *mut OnigCaseFoldCodeItem,
) -> c_int { 0 }
unsafe extern "C" fn s_property_name_to_ctype(_n: *mut OnigEncodingType, _p: *mut OnigUChar, _e: *mut OnigUChar) -> c_int {
    -223 // ONIGERR_INVALID_CHAR_PROPERTY_NAME
}
unsafe extern "C" fn s_is_code_ctype(_c: OnigCodePoint, _t: OnigCtype) -> c_int { 0 }
unsafe extern "C" fn s_get_ctype_code_range(_t: OnigCtype, _sb: *mut OnigCodePoint, _r: *mut *const OnigCodePoint) -> c_int {
    -2 // ONIG_NO_SUPPORT_CONFIG
}
unsafe extern "C" fn s_left_adjust_char_head(_s: *const OnigUChar, p: *const OnigUChar) -> *mut OnigUChar { p as *mut _ }
unsafe extern "C" fn s_is_allowed_reverse_match(_p: *const OnigUChar, _e: *const OnigUChar) -> c_int { 1 }
unsafe extern "C" fn s_init() -> c_int { 0 }
unsafe extern "C" fn s_is_initialized() -> c_int { 1 }
unsafe extern "C" fn s_is_valid_mbc_string(_s: *const OnigUChar, _e: *const OnigUChar) -> c_int { 1 }

const fn enc(name: &'static core::ffi::CStr) -> OnigEncodingType {
    OnigEncodingType {
        mbc_enc_len: Some(s_mbc_enc_len),
        name: name.as_ptr(),
        max_enc_len: 1,
        min_enc_len: 1,
        is_mbc_newline: Some(s_is_mbc_newline),
        mbc_to_code: Some(s_mbc_to_code),
        code_to_mbclen: Some(s_code_to_mbclen),
        code_to_mbc: Some(s_code_to_mbc),
        mbc_case_fold: Some(s_mbc_case_fold),
        apply_all_case_fold: Some(s_apply_all_case_fold),
        get_case_fold_codes_by_str: Some(s_get_case_fold_codes_by_str),
        property_name_to_ctype: Some(s_property_name_to_ctype),
        is_code_ctype: Some(s_is_code_ctype),
        get_ctype_code_range: Some(s_get_ctype_code_range),
        left_adjust_char_head: Some(s_left_adjust_char_head),
        is_allowed_reverse_match: Some(s_is_allowed_reverse_match),
        init: Some(s_init),
        is_initialized: Some(s_is_initialized),
        is_valid_mbc_string: Some(s_is_valid_mbc_string),
        flag: 0,
        sb_range: 0,
        index: 0,
    }
}

macro_rules! encodings {
    ($($n:ident = $s:literal;)*) => { $(
        #[unsafe(no_mangle)]
        pub static mut $n: OnigEncodingType = enc($s);
    )* };
}
encodings! {
    OnigEncodingASCII = c"ASCII"; OnigEncodingISO_8859_1 = c"ISO_8859_1";
    OnigEncodingISO_8859_2 = c"ISO_8859_2"; OnigEncodingISO_8859_3 = c"ISO_8859_3";
    OnigEncodingISO_8859_4 = c"ISO_8859_4"; OnigEncodingISO_8859_5 = c"ISO_8859_5";
    OnigEncodingISO_8859_6 = c"ISO_8859_6"; OnigEncodingISO_8859_7 = c"ISO_8859_7";
    OnigEncodingISO_8859_8 = c"ISO_8859_8"; OnigEncodingISO_8859_9 = c"ISO_8859_9";
    OnigEncodingISO_8859_10 = c"ISO_8859_10"; OnigEncodingISO_8859_11 = c"ISO_8859_11";
    OnigEncodingISO_8859_13 = c"ISO_8859_13"; OnigEncodingISO_8859_14 = c"ISO_8859_14";
    OnigEncodingISO_8859_15 = c"ISO_8859_15"; OnigEncodingISO_8859_16 = c"ISO_8859_16";
    OnigEncodingUTF8 = c"UTF8"; OnigEncodingUTF16_BE = c"UTF16_BE";
    OnigEncodingUTF16_LE = c"UTF16_LE"; OnigEncodingUTF32_BE = c"UTF32_BE";
    OnigEncodingUTF32_LE = c"UTF32_LE"; OnigEncodingEUC_JP = c"EUC_JP";
    OnigEncodingEUC_TW = c"EUC_TW"; OnigEncodingEUC_KR = c"EUC_KR";
    OnigEncodingEUC_CN = c"EUC_CN"; OnigEncodingSJIS = c"SJIS";
    OnigEncodingKOI8_R = c"KOI8_R"; OnigEncodingCP1251 = c"CP1251";
    OnigEncodingBIG5 = c"BIG5"; OnigEncodingGB18030 = c"GB18030";
}

const SYN: OnigSyntaxType = OnigSyntaxType {
    op: 0, op2: 0, behavior: 0, options: 0,
    meta_char_table: OnigMetaCharTableType {
        esc: 0, anychar: 0, anytime: 0, zero_or_one_time: 0, one_or_more_time: 0, anychar_anytime: 0,
    },
};
macro_rules! syntaxes {
    ($($n:ident)*) => { $(
        #[unsafe(no_mangle)]
        pub static mut $n: OnigSyntaxType = SYN;
    )* };
}
syntaxes! {
    OnigSyntaxASIS OnigSyntaxPosixBasic OnigSyntaxPosixExtended OnigSyntaxEmacs
    OnigSyntaxGrep OnigSyntaxGnuRegex OnigSyntaxJava OnigSyntaxPerl OnigSyntaxPerl_NG
    OnigSyntaxRuby OnigSyntaxPython OnigSyntaxOniguruma
}

#[unsafe(no_mangle)]
pub static mut OnigDefaultSyntax: *mut OnigSyntaxType = &raw mut OnigSyntaxOniguruma;

#[unsafe(no_mangle)]
pub static mut OnigDefaultCaseFoldFlag: OnigCaseFoldType = 1 << 30; // ONIGENC_CASE_FOLD_MIN

// The variadic onig_error_code_to_str: stable Rust cannot define a
// C-variadic function (E0658, rust-lang/rust#44930), and a plain C
// shim linked into the cdylib is not exported (rustc's version script
// makes it local). Route used: a Rust naked function exports the
// symbol and tail-jumps to the C body, leaving the variadic argument
// registers (and %al) untouched. The C body is outside any proof.
#[cfg(trampoline)]
unsafe extern "C" {
    fn onig_stub_error_code_to_str_c(s: *mut OnigUChar, code: c_int, ...) -> c_int;
}
#[cfg(trampoline)]
#[unsafe(naked)]
#[unsafe(no_mangle)]
pub extern "C" fn onig_error_code_to_str() {
    core::arch::naked_asm!("jmp {f}", f = sym onig_stub_error_code_to_str_c)
}

include!(env!("ONIG_STUB_GEN"));
