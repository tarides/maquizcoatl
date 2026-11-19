/* Experiment #12: hand-written OCaml stubs for libonig (Oniguruma f95747b).
   The compiled regex_t*, a preallocated OnigRegion* and an OnigMatchParam*
   are held in one custom block (freed by its finaliser).  The search,
   match and region accessors are [@@noalloc] with untagged ints: they do
   not allocate, raise or release the runtime lock. */
#include <string.h>
#include <stdint.h>
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include "oniguruma.h"

typedef struct { regex_t *reg; OnigRegion *region; OnigMatchParam *mp; } h12;
#define H(v) ((h12 *) Data_custom_val(v))

static void h12_finalize(value v) {
  h12 *h = H(v);
  if (h->reg) onig_free(h->reg);
  if (h->region) onig_region_free(h->region, 1);
  if (h->mp) onig_free_match_param(h->mp);
}

static struct custom_operations h12_ops = {
  "maquizcoatl.e12.onig", h12_finalize, custom_compare_default,
  custom_hash_default, custom_serialize_default, custom_deserialize_default,
  custom_compare_ext_default, custom_fixed_length_default
};

static OnigSyntaxType *syntax_of(int s) {
  switch (s) {
  case 0: return ONIG_SYNTAX_ONIGURUMA;
  case 1: return ONIG_SYNTAX_RUBY;
  case 2: return ONIG_SYNTAX_PERL_NG;
  default: return ONIG_SYNTAX_ONIGURUMA;
  }
}

value e12_init(value unit) {
  OnigEncoding enc[1] = { ONIG_ENCODING_UTF8 };
  onig_initialize(enc, 1);
  return Val_unit;
}

/* compile : int -> int -> string -> int -> int -> h  (raises Failure "onig:<code>") */
value e12_compile(value syn, value opt, value pat, value limit, value stack_limit) {
  CAMLparam5(syn, opt, pat, limit, stack_limit);
  CAMLlocal1(v);
  regex_t *reg; OnigErrorInfo einfo;
  const UChar *p = (const UChar *) String_val(pat);
  int r = onig_new(&reg, p, p + caml_string_length(pat), (OnigOptionType) Long_val(opt),
                   ONIG_ENCODING_UTF8, syntax_of(Int_val(syn)), &einfo);
  if (r != ONIG_NORMAL) {
    char buf[32]; snprintf(buf, sizeof buf, "onig:%d", r); caml_failwith(buf);
  }
  v = caml_alloc_custom(&h12_ops, sizeof(h12), 0, 1);
  H(v)->reg = reg;
  H(v)->region = onig_region_new();
  H(v)->mp = onig_new_match_param();
  onig_initialize_match_param(H(v)->mp);
  onig_set_retry_limit_in_match_of_match_param(H(v)->mp, (unsigned long) Long_val(limit));
  onig_set_retry_limit_in_search_of_match_param(H(v)->mp, 0);
  if (Long_val(stack_limit) > 0)
    onig_set_match_stack_limit_size_of_match_param(H(v)->mp, (unsigned int) Long_val(stack_limit));
  CAMLreturn(v);
}

intnat e12_search(value h, value s, intnat start, intnat range, intnat opt) {
  const UChar *str = (const UChar *) String_val(s);
  const UChar *end = str + caml_string_length(s);
  return onig_search_with_param(H(h)->reg, str, end, str + start, str + range,
                                H(h)->region, (OnigOptionType) opt, H(h)->mp);
}
value e12_search_byte(value h, value s, value a, value b, value c) {
  return Val_long(e12_search(h, s, Long_val(a), Long_val(b), Long_val(c)));
}

intnat e12_match(value h, value s, intnat at, intnat opt) {
  const UChar *str = (const UChar *) String_val(s);
  const UChar *end = str + caml_string_length(s);
  return onig_match_with_param(H(h)->reg, str, end, str + at, H(h)->region,
                               (OnigOptionType) opt, H(h)->mp);
}
value e12_match_byte(value h, value s, value a, value b) {
  return Val_long(e12_match(h, s, Long_val(a), Long_val(b)));
}

intnat e12_nregs(value h) { return H(h)->region->num_regs; }
value e12_nregs_byte(value h) { return Val_long(e12_nregs(h)); }
intnat e12_beg(value h, intnat k) { return H(h)->region->beg[k]; }
value e12_beg_byte(value h, value k) { return Val_long(e12_beg(h, Long_val(k))); }
intnat e12_end(value h, intnat k) { return H(h)->region->end[k]; }
value e12_end_byte(value h, value k) { return Val_long(e12_end(h, Long_val(k))); }

/* raw pointers, for the ctypes column: (regex, region, param) */
value e12_raw(value h) {
  CAMLparam1(h);
  CAMLlocal1(t);
  t = caml_alloc_tuple(3);
  Store_field(t, 0, caml_copy_nativeint((intnat) H(h)->reg));
  Store_field(t, 1, caml_copy_nativeint((intnat) H(h)->region));
  Store_field(t, 2, caml_copy_nativeint((intnat) H(h)->mp));
  CAMLreturn(t);
}
