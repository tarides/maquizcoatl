/* client_encoding.c: a caller-filled OnigEncodingType (no upstream
   test or sample defines one). Seeded at run time from the value of
   OnigEncodingASCII (initialiser at upstream/src/ascii.c:103), then
   every function pointer and data field is set by the client: the
   simple single-byte callbacks are the client's own, the case-fold
   and ctype ones keep ASCII's pointers. Used with onig_new and
   onig_search. Shared with experiment #5. */
#include <stdio.h>
#include <string.h>
#include "oniguruma.h"

static OnigEncodingType ascii;   /* copy of OnigEncodingASCII */
static int calls;

static int c_mbc_enc_len(const OnigUChar* p) { (void)p; calls++; return 1; }
static int c_is_mbc_newline(const OnigUChar* p, const OnigUChar* end)
{ return p < end && *p == 0x0a; }
static OnigCodePoint c_mbc_to_code(const OnigUChar* p, const OnigUChar* end)
{ (void)end; return *p; }
static int c_code_to_mbclen(OnigCodePoint c) { return c < 0x100 ? 1 : ONIGERR_INVALID_CODE_POINT_VALUE; }
static int c_code_to_mbc(OnigCodePoint c, OnigUChar* buf) { *buf = (OnigUChar)c; return 1; }
static OnigUChar* c_left_adjust_char_head(const OnigUChar* s, const OnigUChar* p)
{ (void)s; return (OnigUChar*)p; }
static int c_is_allowed_reverse_match(const OnigUChar* p, const OnigUChar* end)
{ (void)p; (void)end; return 1; }
static int c_init(void) { return 0; }
static int c_is_initialized(void) { return 1; }
static int c_is_valid_mbc_string(const OnigUChar* s, const OnigUChar* end)
{ for (; s < end; s++) if (*s > 0x7f) return 0; return 1; }

int main(void) {
  OnigEncodingType enc;
  OnigEncoding use[1];
  OnigRegex reg; OnigErrorInfo einfo; OnigRegion* region;
  const OnigUChar* pat = (const OnigUChar*)"a+(b|c)";
  const OnigUChar* str = (const OnigUChar*)"xxaaac\nab";
  int r;

  ascii = OnigEncodingASCII;
  enc.mbc_enc_len = c_mbc_enc_len;
  enc.name = "CLIENT-ASCII";
  enc.max_enc_len = 1;
  enc.min_enc_len = 1;
  enc.is_mbc_newline = c_is_mbc_newline;
  enc.mbc_to_code = c_mbc_to_code;
  enc.code_to_mbclen = c_code_to_mbclen;
  enc.code_to_mbc = c_code_to_mbc;
  enc.mbc_case_fold = ascii.mbc_case_fold;
  enc.apply_all_case_fold = ascii.apply_all_case_fold;
  enc.get_case_fold_codes_by_str = ascii.get_case_fold_codes_by_str;
  enc.property_name_to_ctype = ascii.property_name_to_ctype;
  enc.is_code_ctype = ascii.is_code_ctype;
  enc.get_ctype_code_range = ascii.get_ctype_code_range;
  enc.left_adjust_char_head = c_left_adjust_char_head;
  enc.is_allowed_reverse_match = c_is_allowed_reverse_match;
  enc.init = c_init;
  enc.is_initialized = c_is_initialized;
  enc.is_valid_mbc_string = c_is_valid_mbc_string;
  enc.flag = ascii.flag;
  enc.sb_range = 0;
  enc.index = 0;

  use[0] = &enc;
  r = onig_initialize(use, 1);
  printf("onig_initialize: %d\n", r);
  r = onig_new(&reg, pat, pat + strlen((const char*)pat), ONIG_OPTION_DEFAULT,
               &enc, ONIG_SYNTAX_DEFAULT, &einfo);
  printf("onig_new: %d\n", r);
  if (r != ONIG_NORMAL) {
    OnigUChar s[ONIG_MAX_ERROR_MESSAGE_LEN];
    onig_error_code_to_str(s, r, &einfo);
    printf("error: %s\n", s);
    return 1;
  }
  region = onig_region_new();
  r = onig_search(reg, str, str + strlen((const char*)str), str,
                  str + strlen((const char*)str), region, ONIG_OPTION_NONE);
  printf("onig_search: %d\n", r);
  if (r >= 0)
    for (int i = 0; i < region->num_regs; i++)
      printf("  %d: (%d-%d)\n", i, region->beg[i], region->end[i]);
  printf("client callbacks used: %s\n", calls > 0 ? "yes" : "no");
  printf("encoding name via reg: %s\n", onig_get_encoding(reg)->name);
  onig_region_free(region, 1);
  onig_free(reg);
  onig_end();
  return 0;
}
