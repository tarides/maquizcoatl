/* Experiment #7 follow-up: the 13 code points below U+0100 where
   onigenc_unicode_is_code_ctype (ISO-8859-1 table) and the CR_* ranges
   disagree. Matches each code point, UTF-8, Oniguruma syntax, against the
   ctype outside a class (\w, \p{...}) and inside one ([\w], [\p{...}],
   POSIX brackets), checks \b, \B, \W, [\W] on U+00B2, and prints the
   public ONIGENC_IS_CODE_* answers.
   Build: cc -I<upstream>/src -I<builddir> latin1ctype.c <builddir>/libonig.a */
#include <stdio.h>
#include <string.h>
#include "oniguruma.h"

static int run(const char* pat, const UChar* s, int n, int search)
{
  regex_t* r; OnigErrorInfo ei; int x;
  if (onig_new(&r, (const UChar*)pat, (const UChar*)pat + strlen(pat),
               ONIG_OPTION_NONE, ONIG_ENCODING_UTF8, ONIG_SYNTAX_ONIGURUMA, &ei))
    return -9;
  x = search ? onig_search(r, s, s + n, s, s + n, NULL, ONIG_OPTION_NONE)
             : onig_match(r, s, s + n, s, NULL, ONIG_OPTION_NONE);
  onig_free(r);
  return x;
}

static void row(unsigned cp, const char** pats, int k)
{
  UChar s[8]; int n = ONIGENC_CODE_TO_MBC(ONIG_ENCODING_UTF8, cp, s), j;
  printf("U+%04X", cp);
  for (j = 0; j < k; j++) printf("\t%s=%d", pats[j], run(pats[j], s, n, 0) > 0);
  printf("\n");
}

int main(void)
{
  OnigEncoding e = ONIG_ENCODING_UTF8;
  unsigned W[] = {0xB2, 0xB3, 0xB9, 0xBC, 0xBD, 0xBE};
  unsigned P[] = {0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x85};
  const char* wp[] = {"\\w", "[\\w]", "\\p{Word}", "[\\p{Word}]", "[[:word:]]"};
  const char* pp[] = {"\\p{Print}", "[\\p{Print}]", "[[:print:]]"};
  const char* cp[] = {"\\p{Cntrl}", "[\\p{Cntrl}]", "[[:cntrl:]]"};
  const char* sub = "a\xC2\xB2"; /* a, U+00B2 */
  int i;
  onig_initialize(&e, 1);
  for (i = 0; i < 6; i++) row(W[i], wp, 5);
  for (i = 0; i < 6; i++) row(P[i], pp, 3);
  row(0xAD, cp, 3);
  printf("search a\\b on a U+00B2 -> %d\n", run("a\\b", (const UChar*)sub, 3, 1));
  printf("search a\\B on a U+00B2 -> %d\n", run("a\\B", (const UChar*)sub, 3, 1));
  printf("search \\W on U+00B2 -> %d\n", run("\\W", (const UChar*)sub + 1, 2, 1));
  printf("search [\\W] on U+00B2 -> %d\n", run("[\\W]", (const UChar*)sub + 1, 2, 1));
  for (i = 0; i < 6; i++)
    printf("API ONIGENC_IS_CODE_WORD(U+%04X)=%d\n", W[i],
           ONIGENC_IS_CODE_WORD(ONIG_ENCODING_UTF8, W[i]) != 0);
  for (i = 0; i < 6; i++)
    printf("API ONIGENC_IS_CODE_PRINT(U+%04X)=%d\n", P[i],
           ONIGENC_IS_CODE_PRINT(ONIG_ENCODING_UTF8, P[i]) != 0);
  printf("API ONIGENC_IS_CODE_CNTRL(U+00AD)=%d\n",
         ONIGENC_IS_CODE_CNTRL(ONIG_ENCODING_UTF8, 0xAD) != 0);
  onig_end();
  return 0;
}
