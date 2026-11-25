/* Experiment #9: C reference at every start position.  Companion of
   experiment #6's oracle.c (copied unchanged next to this file), which
   gives the onig_search verdict of each case.  This one reads the same
   case file (tab-separated: index id kind pat_hex sub_hex ...), compiles
   each pattern with Oniguruma f95747b (UTF-8, ONIG_SYNTAX_ONIGURUMA,
   ONIG_OPTION_NONE) and, for every start position p = 0 .. |subject|,
   runs onig_match at p (one match_at call, no search loop, no
   optimiser), printing
     id TAB p TAB MISMATCH | LIMIT | ERR code | MATCH s0 e0 s1 e1 ...
   (unset groups as -1 -1).  A compile error prints one line with p = -.

   usage: oracle_at CASES.tsv

   Uses the public API of Oniguruma (oniguruma.h):
   Copyright (c) 2002-2025 K.Kosako, BSD-2-Clause (see upstream/COPYING). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "oniguruma.h"

static unsigned char *unhex(const char *h, int *len)
{
  int n = (int)strlen(h) / 2;
  unsigned char *b = malloc(n + 1);
  for (int i = 0; i < n; i++) sscanf(h + 2 * i, "%2hhx", &b[i]);
  b[n] = 0;
  *len = n;
  return b;
}

int main(int argc, char **argv)
{
  if (argc != 2) { fprintf(stderr, "usage: oracle_at CASES.tsv\n"); return 2; }
  FILE *f = fopen(argv[1], "r");
  if (!f) { perror("open"); return 2; }
  OnigEncoding use[1] = { ONIG_ENCODING_UTF8 };
  onig_initialize(use, 1);
  OnigRegion *region = onig_region_new();
  static char line[1 << 16];
  while (fgets(line, sizeof line, f)) {
    char *fld[6]; char *p = line;
    for (int k = 0; k < 6; k++) fld[k] = strsep(&p, "\t\n");
    int plen, slen;
    unsigned char *pat = unhex(fld[3], &plen), *sub = unhex(fld[4], &slen);
    regex_t *reg;
    OnigErrorInfo einfo;
    int r = onig_new(&reg, pat, pat + plen, ONIG_OPTION_NONE, ONIG_ENCODING_UTF8,
                     ONIG_SYNTAX_ONIGURUMA, &einfo);
    if (r != ONIG_NORMAL) { printf("%s\t-\tERR %d\n", fld[1], r); free(pat); free(sub); continue; }
    for (int s = 0; s <= slen; s++) {
      r = onig_match(reg, sub, sub + slen, sub + s, region, ONIG_OPTION_NONE);
      printf("%s\t%d\t", fld[1], s);
      if (r == ONIG_MISMATCH) printf("MISMATCH\n");
      else if (r == ONIGERR_RETRY_LIMIT_IN_MATCH_OVER) printf("LIMIT\n");
      else if (r < 0) printf("ERR %d\n", r);
      else {
        printf("MATCH");
        for (int k = 0; k < region->num_regs; k++)
          printf(" %d %d", region->beg[k], region->end[k]);
        printf("\n");
      }
    }
    onig_free(reg);
    free(pat); free(sub);
  }
  fclose(f);
  onig_region_free(region, 1);
  onig_end();
  return 0;
}
