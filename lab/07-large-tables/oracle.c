/* Experiment #7 C oracle, linked against an out-of-tree build of
   Oniguruma f95747b (upstream/, BSD-2-Clause).
   oracle <queries.txt> <names.txt> <table-answers> <is_code_ctype-answers>
   For each "ctype code" query: table answer = onig_is_in_code_range on
   the CR_* array returned by onigenc_unicode_ctype_code_range; also
   onigenc_unicode_is_code_ctype.  Then each name through
   ONIGENC_PROPERTY_NAME_TO_CTYPE (ctype, or the negative error code). */
#include <stdio.h>
#include <string.h>
#include "oniguruma.h"
typedef unsigned int OnigCtype_;
extern int onigenc_unicode_ctype_code_range(OnigCtype_ ctype, const OnigCodePoint* ranges[]);
extern int onig_is_in_code_range(const UChar* p, OnigCodePoint code);
extern int onigenc_unicode_is_code_ctype(OnigCodePoint code, unsigned int ctype);

int main(int argc, char** argv) {
  OnigEncoding enc = ONIG_ENCODING_UTF8;
  onig_initialize(&enc, 1);
  FILE *q = fopen(argv[1], "r"), *n = fopen(argv[2], "r");
  FILE *a = fopen(argv[3], "w"), *b = fopen(argv[4], "w");
  unsigned ct, c; long diff = 0;
  while (fscanf(q, "%u %u", &ct, &c) == 2) {
    const OnigCodePoint* r;
    if (onigenc_unicode_ctype_code_range(ct, &r) != 0) return 2;
    int t = onig_is_in_code_range((const UChar*)r, c) != 0;
    int k = onigenc_unicode_is_code_ctype(c, ct) != 0;
    fprintf(a, "%d\n", t); fprintf(b, "%d\n", k);
    if (t != k) { diff++; fprintf(stderr, "is_code_ctype differs: ctype %u U+%04X table %d iso %d\n", ct, c, t, k); }
  }
  char buf[256];
  while (fgets(buf, sizeof buf, n)) {
    size_t l = strcspn(buf, "\n"); buf[l] = 0;
    int r = ONIGENC_PROPERTY_NAME_TO_CTYPE(enc, (UChar*)buf, (UChar*)buf + l);
    fprintf(a, "%d\n", r); fprintf(b, "%d\n", r);
  }
  fprintf(stderr, "table vs is_code_ctype differences on sample: %ld\n", diff);
  onig_end();
  return 0;
}
