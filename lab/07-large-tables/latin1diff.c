/* Experiment #7: list the code points < 256 where onigenc_unicode_is_code_ctype
   (ISO-8859-1 ctype table for ctype <= 14) differs from the CR_* table.
   Links against an out-of-tree build of Oniguruma f95747b (BSD-2-Clause). */
#include <stdio.h>
#include "oniguruma.h"
extern int onigenc_unicode_ctype_code_range(unsigned int ctype, const OnigCodePoint* ranges[]);
extern int onig_is_in_code_range(const UChar* p, OnigCodePoint code);
extern int onigenc_unicode_is_code_ctype(OnigCodePoint code, unsigned int ctype);
int main(void) {
  int n = 0;
  for (unsigned ct = 0; ct <= 14; ct++)
    for (unsigned c = 0; c < 256; c++) {
      const OnigCodePoint* r; onigenc_unicode_ctype_code_range(ct, &r);
      int t = onig_is_in_code_range((const UChar*)r, c) != 0, k = onigenc_unicode_is_code_ctype(c, ct) != 0;
      if (t != k) { n++; printf("ctype %u U+%04X CR_table %d is_code_ctype %d\n", ct, c, t, k); }
    }
  printf("total %d\n", n); return 0;
}
