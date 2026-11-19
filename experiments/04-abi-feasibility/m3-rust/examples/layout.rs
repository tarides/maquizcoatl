// layout.rs: prints size/offset/align of the Rust #[repr(C)] types in
// the same format as layout.c / layout_posix.c, for a direct diff
// against the output compiled from upstream's headers.
use core::mem::{align_of, offset_of, size_of};
use onig::*;

macro_rules! s {
    ($t:ty, $n:literal) => {
        println!("{} - 0 {} {}", $n, size_of::<$t>(), align_of::<$t>())
    };
}
fn fa<T, F>(_: fn(&T) -> &F) -> (usize, usize) { (size_of::<F>(), align_of::<F>()) }
macro_rules! f {
    ($t:ty, $n:literal, $($f:tt).+) => {{
        let (sz, al) = fa::<$t, _>(|x: &$t| unsafe { &*core::ptr::addr_of!(x.$($f).+) });
        println!("{} {} {} {} {}", $n, stringify!($($f).+).replace(' ', ""), offset_of!($t, $($f).+), sz, al)
    }};
}

fn main() {
    let posix = std::env::args().nth(1).as_deref() == Some("posix");
    if posix {
        s!(onig_posix_regmatch_t, "onig_posix_regmatch_t");
        f!(onig_posix_regmatch_t, "onig_posix_regmatch_t", rm_so);
        f!(onig_posix_regmatch_t, "onig_posix_regmatch_t", rm_eo);
        s!(onig_posix_regex_t, "onig_posix_regex_t");
        f!(onig_posix_regex_t, "onig_posix_regex_t", onig);
        f!(onig_posix_regex_t, "onig_posix_regex_t", re_nsub);
        f!(onig_posix_regex_t, "onig_posix_regex_t", comp_options);
        return;
    }
    s!(OnigCaseFoldCodeItem, "OnigCaseFoldCodeItem");
    f!(OnigCaseFoldCodeItem, "OnigCaseFoldCodeItem", byte_len);
    f!(OnigCaseFoldCodeItem, "OnigCaseFoldCodeItem", code_len);
    f!(OnigCaseFoldCodeItem, "OnigCaseFoldCodeItem", code);
    s!(OnigMetaCharTableType, "OnigMetaCharTableType");
    f!(OnigMetaCharTableType, "OnigMetaCharTableType", esc);
    f!(OnigMetaCharTableType, "OnigMetaCharTableType", anychar);
    f!(OnigMetaCharTableType, "OnigMetaCharTableType", anytime);
    f!(OnigMetaCharTableType, "OnigMetaCharTableType", zero_or_one_time);
    f!(OnigMetaCharTableType, "OnigMetaCharTableType", one_or_more_time);
    f!(OnigMetaCharTableType, "OnigMetaCharTableType", anychar_anytime);
    s!(OnigEncodingType, "OnigEncodingType");
    f!(OnigEncodingType, "OnigEncodingType", mbc_enc_len);
    f!(OnigEncodingType, "OnigEncodingType", name);
    f!(OnigEncodingType, "OnigEncodingType", max_enc_len);
    f!(OnigEncodingType, "OnigEncodingType", min_enc_len);
    f!(OnigEncodingType, "OnigEncodingType", is_mbc_newline);
    f!(OnigEncodingType, "OnigEncodingType", mbc_to_code);
    f!(OnigEncodingType, "OnigEncodingType", code_to_mbclen);
    f!(OnigEncodingType, "OnigEncodingType", code_to_mbc);
    f!(OnigEncodingType, "OnigEncodingType", mbc_case_fold);
    f!(OnigEncodingType, "OnigEncodingType", apply_all_case_fold);
    f!(OnigEncodingType, "OnigEncodingType", get_case_fold_codes_by_str);
    f!(OnigEncodingType, "OnigEncodingType", property_name_to_ctype);
    f!(OnigEncodingType, "OnigEncodingType", is_code_ctype);
    f!(OnigEncodingType, "OnigEncodingType", get_ctype_code_range);
    f!(OnigEncodingType, "OnigEncodingType", left_adjust_char_head);
    f!(OnigEncodingType, "OnigEncodingType", is_allowed_reverse_match);
    f!(OnigEncodingType, "OnigEncodingType", init);
    f!(OnigEncodingType, "OnigEncodingType", is_initialized);
    f!(OnigEncodingType, "OnigEncodingType", is_valid_mbc_string);
    f!(OnigEncodingType, "OnigEncodingType", flag);
    f!(OnigEncodingType, "OnigEncodingType", sb_range);
    f!(OnigEncodingType, "OnigEncodingType", index);
    s!(OnigSyntaxType, "OnigSyntaxType");
    f!(OnigSyntaxType, "OnigSyntaxType", op);
    f!(OnigSyntaxType, "OnigSyntaxType", op2);
    f!(OnigSyntaxType, "OnigSyntaxType", behavior);
    f!(OnigSyntaxType, "OnigSyntaxType", options);
    f!(OnigSyntaxType, "OnigSyntaxType", meta_char_table);
    s!(OnigCaptureTreeNode, "OnigCaptureTreeNode");
    f!(OnigCaptureTreeNode, "OnigCaptureTreeNode", group);
    f!(OnigCaptureTreeNode, "OnigCaptureTreeNode", beg);
    f!(OnigCaptureTreeNode, "OnigCaptureTreeNode", end);
    f!(OnigCaptureTreeNode, "OnigCaptureTreeNode", allocated);
    f!(OnigCaptureTreeNode, "OnigCaptureTreeNode", num_childs);
    f!(OnigCaptureTreeNode, "OnigCaptureTreeNode", childs);
    s!(OnigRegion, "OnigRegion");
    f!(OnigRegion, "OnigRegion", allocated);
    f!(OnigRegion, "OnigRegion", num_regs);
    f!(OnigRegion, "OnigRegion", beg);
    f!(OnigRegion, "OnigRegion", end);
    f!(OnigRegion, "OnigRegion", history_root);
    s!(OnigErrorInfo, "OnigErrorInfo");
    f!(OnigErrorInfo, "OnigErrorInfo", enc);
    f!(OnigErrorInfo, "OnigErrorInfo", par);
    f!(OnigErrorInfo, "OnigErrorInfo", par_end);
    s!(OnigRepeatRange, "OnigRepeatRange");
    f!(OnigRepeatRange, "OnigRepeatRange", lower);
    f!(OnigRepeatRange, "OnigRepeatRange", upper);
    s!(OnigCompileInfo, "OnigCompileInfo");
    f!(OnigCompileInfo, "OnigCompileInfo", num_of_elements);
    f!(OnigCompileInfo, "OnigCompileInfo", pattern_enc);
    f!(OnigCompileInfo, "OnigCompileInfo", target_enc);
    f!(OnigCompileInfo, "OnigCompileInfo", syntax);
    f!(OnigCompileInfo, "OnigCompileInfo", option);
    f!(OnigCompileInfo, "OnigCompileInfo", case_fold_flag);
    s!(OnigValue, "OnigValue");
    f!(OnigValue, "OnigValue", l);
    f!(OnigValue, "OnigValue", c);
    f!(OnigValue, "OnigValue", s.start);
    f!(OnigValue, "OnigValue", s.end);
    f!(OnigValue, "OnigValue", p);
    f!(OnigValue, "OnigValue", tag);
}
