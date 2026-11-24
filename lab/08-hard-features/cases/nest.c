/* Experiment #8: subexpression-call cases that need a non-default nest
   limit (onig_set_subexp_call_max_nest_level).  Same input format as
   probes/harness.c (8-column TSV) except that the options column holds
   NEST=<k> (the limit for this case) or SCAN (print, for limits 0..30,
   the result at each limit).  Syntax Oniguruma, encoding UTF-8, ASCII
   subjects only.  Output: the harness columns (id, syntax, encoding,
   options, casefold, version, build, pattern, subject, result,
   result_bytes); offsets are bytes = code points on ASCII subjects.
   Build: cc -I<upstream>/src nest.c -L<build> -lonig. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "oniguruma.h"

#ifndef BUILD_TYPE
#define BUILD_TYPE "debug"
#endif

static void run(const char *id, const char *opts, const char *pat,
                const char *subj, int limit)
{
  regex_t *reg; OnigErrorInfo einfo; char res[512];
  int r, sl = (int)strlen(subj);
  onig_set_subexp_call_max_nest_level(limit);
  fprintf(stderr, "@@probe %s\n", id);
  r = onig_new(&reg, (const UChar *)pat, (const UChar *)pat + strlen(pat),
               ONIG_OPTION_NONE, ONIG_ENCODING_UTF8, ONIG_SYNTAX_ONIGURUMA, &einfo);
  if (r != ONIG_NORMAL) {
    char msg[ONIG_MAX_ERROR_MESSAGE_LEN];
    onig_error_code_to_str((UChar *)msg, r, &einfo);
    snprintf(res, sizeof res, "E %d %s", r, msg);
  } else {
    OnigRegion *rg = onig_region_new();
    const UChar *s = (const UChar *)subj;
    r = onig_search(reg, s, s + sl, s, s + sl, rg, ONIG_OPTION_NONE);
    if (r >= 0) snprintf(res, sizeof res, "M %d-%d", rg->beg[0], rg->end[0]);
    else if (r == ONIG_MISMATCH) strcpy(res, "N");
    else snprintf(res, sizeof res, "X %d", r);
    onig_region_free(rg, 1); onig_free(reg);
  }
  printf("%s\tOniguruma\tUTF-8\t%s\t-\t%s\t%s\t%s\t%s\t%s\t%s\n", id, opts,
         onig_version(), BUILD_TYPE, pat, subj, res, res);
}

int main(int argc, char *argv[])
{
  char line[4096]; FILE *f;
  OnigEncoding enc = ONIG_ENCODING_UTF8;
  if (argc != 2) { fprintf(stderr, "usage: %s FILE.tsv\n", argv[0]); return 2; }
  if (!(f = fopen(argv[1], "r"))) { perror("open"); return 2; }
  onig_initialize(&enc, 1);
  printf("id\tsyntax\tencoding\toptions\tcasefold\tversion\tbuild\tpattern\tsubject\tresult\tresult_bytes\n");
  while (fgets(line, sizeof line, f)) {
    char *fld[8]; int nf = 0; char *p = line; size_t L = strlen(line);
    if (L && line[L - 1] == '\n') line[--L] = 0;
    if (line[0] == '#' || line[0] == 0) continue;
    fld[nf++] = p;
    while ((p = strchr(p, '\t')) && nf < 8) { *p++ = 0; fld[nf++] = p; }
    if (nf < 6 || !strcmp(fld[0], "id")) continue;
    if (!strcmp(fld[3], "SCAN")) {
      char id[256], o[32]; int k;
      for (k = 0; k <= 30; k++) {
        snprintf(id, sizeof id, "%s@%d", fld[0], k);
        snprintf(o, sizeof o, "NEST=%d", k);
        run(id, o, fld[4], fld[5], k);
      }
    } else if (!strncmp(fld[3], "NEST=", 5)) {
      run(fld[0], fld[3], fld[4], fld[5], atoi(fld[3] + 5));
    } else fprintf(stderr, "%s: options must be NEST=<k> or SCAN\n", fld[0]);
  }
  onig_end();
  return 0;
}
