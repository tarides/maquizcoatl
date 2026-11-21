/* posix_syntax_size.c: a client that includes onigposix.h alone (as
   upstream/sample/posix.c does) sees the four-field OnigSyntaxType of
   upstream/src/onigposix.h:118-127; the library is built with the
   five-field one of upstream/src/oniguruma.h:413-419. onig_copy_syntax
   (upstream/src/regsyntax.c:291-294, "*to = *from") then writes the
   library's size into the client's object. The guard bytes after the
   client's object show how many bytes were written past its end.
   Candidate entry in spec/deviations.md. */
#include <stdio.h>
#include <string.h>
#include "onigposix.h"

int main(void) {
  struct { OnigSyntaxType s; unsigned char guard[64]; } x;
  memset(&x, 0xAA, sizeof x);
  onig_copy_syntax(&x.s, ONIG_SYNTAX_RUBY);
  size_t n = 0;
  for (size_t i = 0; i < sizeof x.guard; i++) if (x.guard[i] != 0xAA) n = i + 1;
  printf("sizeof(OnigSyntaxType) seen by an onigposix.h-only client: %zu\n", sizeof x.s);
  printf("bytes written past the client's object by onig_copy_syntax: %zu\n", n);
  return 0;
}
