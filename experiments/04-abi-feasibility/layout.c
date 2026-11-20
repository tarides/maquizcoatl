/* layout.c: sizeof/_Alignof of every non-opaque public struct of
   oniguruma.h, and offsetof/sizeof/_Alignof of each of its fields.
   Compiled once against upstream's header, once against a stub's
   shipped header; the two outputs are diffed (criterion 2).
   OnigCalloutArgs and struct re_pattern_buffer are opaque in the
   installed headers (oniguruma.h:712,768-769), so not listed. */
#include <stdio.h>
#include <stddef.h>
#include "oniguruma.h"

#define S(T)   printf("%s - %zu %zu %zu\n", #T, (size_t)0, sizeof(T), _Alignof(T))
#define F(T,f) printf("%s %s %zu %zu %zu\n", #T, #f, offsetof(T,f), \
                      sizeof(((T*)0)->f), _Alignof(__typeof__(((T*)0)->f)))

int main(void) {
  S(OnigCaseFoldCodeItem);
  F(OnigCaseFoldCodeItem, byte_len); F(OnigCaseFoldCodeItem, code_len);
  F(OnigCaseFoldCodeItem, code);
  S(OnigMetaCharTableType);
  F(OnigMetaCharTableType, esc); F(OnigMetaCharTableType, anychar);
  F(OnigMetaCharTableType, anytime); F(OnigMetaCharTableType, zero_or_one_time);
  F(OnigMetaCharTableType, one_or_more_time); F(OnigMetaCharTableType, anychar_anytime);
  S(OnigEncodingType);
  F(OnigEncodingType, mbc_enc_len); F(OnigEncodingType, name);
  F(OnigEncodingType, max_enc_len); F(OnigEncodingType, min_enc_len);
  F(OnigEncodingType, is_mbc_newline); F(OnigEncodingType, mbc_to_code);
  F(OnigEncodingType, code_to_mbclen); F(OnigEncodingType, code_to_mbc);
  F(OnigEncodingType, mbc_case_fold); F(OnigEncodingType, apply_all_case_fold);
  F(OnigEncodingType, get_case_fold_codes_by_str);
  F(OnigEncodingType, property_name_to_ctype); F(OnigEncodingType, is_code_ctype);
  F(OnigEncodingType, get_ctype_code_range); F(OnigEncodingType, left_adjust_char_head);
  F(OnigEncodingType, is_allowed_reverse_match); F(OnigEncodingType, init);
  F(OnigEncodingType, is_initialized); F(OnigEncodingType, is_valid_mbc_string);
  F(OnigEncodingType, flag); F(OnigEncodingType, sb_range); F(OnigEncodingType, index);
  S(OnigSyntaxType);
  F(OnigSyntaxType, op); F(OnigSyntaxType, op2); F(OnigSyntaxType, behavior);
  F(OnigSyntaxType, options); F(OnigSyntaxType, meta_char_table);
  S(OnigCaptureTreeNode);
  F(OnigCaptureTreeNode, group); F(OnigCaptureTreeNode, beg); F(OnigCaptureTreeNode, end);
  F(OnigCaptureTreeNode, allocated); F(OnigCaptureTreeNode, num_childs);
  F(OnigCaptureTreeNode, childs);
  S(OnigRegion);
  F(OnigRegion, allocated); F(OnigRegion, num_regs); F(OnigRegion, beg);
  F(OnigRegion, end); F(OnigRegion, history_root);
  S(OnigErrorInfo);
  F(OnigErrorInfo, enc); F(OnigErrorInfo, par); F(OnigErrorInfo, par_end);
  S(OnigRepeatRange);
  F(OnigRepeatRange, lower); F(OnigRepeatRange, upper);
  S(OnigCompileInfo);
  F(OnigCompileInfo, num_of_elements); F(OnigCompileInfo, pattern_enc);
  F(OnigCompileInfo, target_enc); F(OnigCompileInfo, syntax);
  F(OnigCompileInfo, option); F(OnigCompileInfo, case_fold_flag);
  S(OnigValue);
  F(OnigValue, l); F(OnigValue, c); F(OnigValue, s.start); F(OnigValue, s.end);
  F(OnigValue, p); F(OnigValue, tag);
  return 0;
}
