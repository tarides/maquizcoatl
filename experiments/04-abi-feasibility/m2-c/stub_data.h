/* stub_data.h: callbacks and initialisers for the stub's data symbols.
   Every OnigEncodingType field is set: a file-scope initialised struct
   holding function pointers, exported under the exact upstream name
   (the construct the verifier's front end must accept, criterion 5). */
#ifndef STUB_DATA_H
#define STUB_DATA_H
#include "oniguruma.h"

static int s_mbc_enc_len(const OnigUChar* p) { (void)p; return 1; }
static int s_is_mbc_newline(const OnigUChar* p, const OnigUChar* end)
{ return p < end && *p == 0x0a; }
static OnigCodePoint s_mbc_to_code(const OnigUChar* p, const OnigUChar* end)
{ (void)end; return *p; }
static int s_code_to_mbclen(OnigCodePoint c) { (void)c; return 1; }
static int s_code_to_mbc(OnigCodePoint c, OnigUChar* buf)
{ *buf = (OnigUChar)c; return 1; }
static int s_mbc_case_fold(OnigCaseFoldType f, const OnigUChar** pp,
                           const OnigUChar* end, OnigUChar* to)
{ (void)f; (void)end; *to = **pp; (*pp)++; return 1; }
static int s_apply_all_case_fold(OnigCaseFoldType f, OnigApplyAllCaseFoldFunc fn, void* arg)
{ (void)f; (void)fn; (void)arg; return 0; }
static int s_get_case_fold_codes_by_str(OnigCaseFoldType f, const OnigUChar* p,
                                        const OnigUChar* end, OnigCaseFoldCodeItem acs[])
{ (void)f; (void)p; (void)end; (void)acs; return 0; }
static int s_property_name_to_ctype(struct OnigEncodingTypeST* enc, OnigUChar* p, OnigUChar* end)
{ (void)enc; (void)p; (void)end; return ONIGERR_INVALID_CHAR_PROPERTY_NAME; }
static int s_is_code_ctype(OnigCodePoint c, OnigCtype t) { (void)c; (void)t; return 0; }
static int s_get_ctype_code_range(OnigCtype t, OnigCodePoint* sb, const OnigCodePoint* r[])
{ (void)t; (void)sb; (void)r; return ONIG_NO_SUPPORT_CONFIG; }
static OnigUChar* s_left_adjust_char_head(const OnigUChar* s, const OnigUChar* p)
{ (void)s; return (OnigUChar*)p; }
static int s_is_allowed_reverse_match(const OnigUChar* p, const OnigUChar* end)
{ (void)p; (void)end; return 1; }
static int s_init(void) { return 0; }
static int s_is_initialized(void) { return 1; }
static int s_is_valid_mbc_string(const OnigUChar* s, const OnigUChar* end)
{ (void)s; (void)end; return 1; }

#define STUB_ENCODING(NAME) { \
  s_mbc_enc_len, NAME, 1, 1, s_is_mbc_newline, s_mbc_to_code, \
  s_code_to_mbclen, s_code_to_mbc, s_mbc_case_fold, s_apply_all_case_fold, \
  s_get_case_fold_codes_by_str, s_property_name_to_ctype, s_is_code_ctype, \
  s_get_ctype_code_range, s_left_adjust_char_head, s_is_allowed_reverse_match, \
  s_init, s_is_initialized, s_is_valid_mbc_string, 0, 0, 0 }

#define STUB_SYNTAX { 0, 0, 0, 0, { 0, 0, 0, 0, 0, 0 } }
#endif
