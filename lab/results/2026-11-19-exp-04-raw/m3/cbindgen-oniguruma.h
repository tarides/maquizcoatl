#ifndef ONIG_CBINDGEN_H
#define ONIG_CBINDGEN_H

#include <stdint.h>
#include <stddef.h>

typedef uint8_t OnigUChar;

typedef unsigned int OnigOptionType;

typedef unsigned int OnigCodePoint;

typedef struct OnigMetaCharTableType {
  OnigCodePoint esc;
  OnigCodePoint anychar;
  OnigCodePoint anytime;
  OnigCodePoint zero_or_one_time;
  OnigCodePoint one_or_more_time;
  OnigCodePoint anychar_anytime;
} OnigMetaCharTableType;

typedef struct OnigSyntaxType {
  unsigned int op;
  unsigned int op2;
  unsigned int behavior;
  OnigOptionType options;
  struct OnigMetaCharTableType meta_char_table;
} OnigSyntaxType;

typedef unsigned int OnigCaseFoldType;

typedef struct OnigCaseFoldCodeItem {
  int byte_len;
  int code_len;
  OnigCodePoint code[3];
} OnigCaseFoldCodeItem;

typedef int (*OnigApplyAllCaseFoldFunc)(OnigCodePoint, OnigCodePoint*, int, void*);

typedef unsigned int OnigCtype;

typedef struct OnigEncodingType {
  int (*mbc_enc_len)(const OnigUChar*);
  const char *name;
  int max_enc_len;
  int min_enc_len;
  int (*is_mbc_newline)(const OnigUChar*, const OnigUChar*);
  OnigCodePoint (*mbc_to_code)(const OnigUChar*, const OnigUChar*);
  int (*code_to_mbclen)(OnigCodePoint);
  int (*code_to_mbc)(OnigCodePoint, OnigUChar*);
  int (*mbc_case_fold)(OnigCaseFoldType, const OnigUChar**, const OnigUChar*, OnigUChar*);
  int (*apply_all_case_fold)(OnigCaseFoldType, OnigApplyAllCaseFoldFunc, void*);
  int (*get_case_fold_codes_by_str)(OnigCaseFoldType,
                                    const OnigUChar*,
                                    const OnigUChar*,
                                    struct OnigCaseFoldCodeItem*);
  int (*property_name_to_ctype)(struct OnigEncodingType*, OnigUChar*, OnigUChar*);
  int (*is_code_ctype)(OnigCodePoint, OnigCtype);
  int (*get_ctype_code_range)(OnigCtype, OnigCodePoint*, const OnigCodePoint**);
  OnigUChar *(*left_adjust_char_head)(const OnigUChar*, const OnigUChar*);
  int (*is_allowed_reverse_match)(const OnigUChar*, const OnigUChar*);
  int (*init)(void);
  int (*is_initialized)(void);
  int (*is_valid_mbc_string)(const OnigUChar*, const OnigUChar*);
  unsigned int flag;
  OnigCodePoint sb_range;
  int index;
} OnigEncodingType;

typedef struct OnigCaptureTreeNode {
  int group;
  int beg;
  int end;
  int allocated;
  int num_childs;
  struct OnigCaptureTreeNode **childs;
} OnigCaptureTreeNode;

typedef struct OnigRegion {
  int allocated;
  int num_regs;
  int *beg;
  int *end;
  struct OnigCaptureTreeNode *history_root;
} OnigRegion;

typedef struct OnigErrorInfo {
  struct OnigEncodingType *enc;
  OnigUChar *par;
  OnigUChar *par_end;
} OnigErrorInfo;

typedef struct OnigRepeatRange {
  int lower;
  int upper;
} OnigRepeatRange;

typedef struct OnigCompileInfo {
  int num_of_elements;
  struct OnigEncodingType *pattern_enc;
  struct OnigEncodingType *target_enc;
  struct OnigSyntaxType *syntax;
  OnigOptionType option;
  OnigCaseFoldType case_fold_flag;
} OnigCompileInfo;

typedef struct OnigValue_s {
  OnigUChar *start;
  OnigUChar *end;
} OnigValue_s;

typedef union OnigValue {
  long l;
  OnigCodePoint c;
  struct OnigValue_s s;
  void *p;
  int tag;
} OnigValue;

typedef struct onig_posix_regmatch_t {
  int rm_so;
  int rm_eo;
} onig_posix_regmatch_t;

typedef struct onig_posix_regex_t {
  void *onig;
  uintptr_t re_nsub;
  int comp_options;
} onig_posix_regex_t;

extern struct OnigSyntaxType *OnigDefaultSyntax;

extern OnigCaseFoldType OnigDefaultCaseFoldFlag;

extern int onig_stub_error_code_to_str_c(OnigUChar *s, int code, ...);

void onig_error_code_to_str(void);

#endif  /* ONIG_CBINDGEN_H */
