/* Experiment #6: C reference.  Reads the in-subset case file written by
   `g classify` (tab-separated: index id kind pat_hex sub_hex ...), runs
   every case through Oniguruma f95747b (UTF-8, ONIG_SYNTAX_ONIGURUMA,
   ONIG_OPTION_NONE, forward onig_search over the whole subject) and
   prints one verdict per case in stack G's format:
     id ERR code | id MISMATCH | id LIMIT | id MATCH s0 e0 s1 e1 ...
   Then times REPS passes: compile only, search only (precompiled), and
   end to end (compile + search + free), on stderr.

   usage: oracle IN.tsv REPS */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "oniguruma.h"

#define MAXC 4096

static int nc;
static char *ids[MAXC];
static unsigned char *pats[MAXC], *subs[MAXC];
static int plen[MAXC], slen[MAXC];

static unsigned char *unhex(const char *h, int *len)
{
  int n = (int)strlen(h) / 2;
  unsigned char *b = malloc(n + 1);
  for (int i = 0; i < n; i++) sscanf(h + 2 * i, "%2hhx", &b[i]);
  b[n] = 0;
  *len = n;
  return b;
}

static double now(void)
{
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec + t.tv_nsec * 1e-9;
}

static int compile(int i, regex_t **reg)
{
  OnigErrorInfo einfo;
  return onig_new(reg, pats[i], pats[i] + plen[i], ONIG_OPTION_NONE,
                  ONIG_ENCODING_UTF8, ONIG_SYNTAX_ONIGURUMA, &einfo);
}

static int search(regex_t *reg, int i, OnigRegion *region)
{
  return onig_search(reg, subs[i], subs[i] + slen[i], subs[i], subs[i] + slen[i],
                     region, ONIG_OPTION_NONE);
}

int main(int argc, char **argv)
{
  if (argc != 3) { fprintf(stderr, "usage: oracle IN.tsv REPS\n"); return 2; }
  int reps = atoi(argv[2]);
  FILE *f = fopen(argv[1], "r");
  static char line[1 << 16];
  while (fgets(line, sizeof line, f)) {
    char *fld[6]; char *p = line;
    for (int k = 0; k < 6; k++) { fld[k] = strsep(&p, "\t\n"); }
    ids[nc] = strdup(fld[1]);
    pats[nc] = unhex(fld[3], &plen[nc]);
    subs[nc] = unhex(fld[4], &slen[nc]);
    nc++;
  }
  fclose(f);
  OnigEncoding use[1] = { ONIG_ENCODING_UTF8 };
  onig_initialize(use, 1);
  OnigRegion *region = onig_region_new();
  static regex_t *regs[MAXC];
  for (int i = 0; i < nc; i++) {
    int r = compile(i, &regs[i]);
    if (r != ONIG_NORMAL) { printf("%s\tERR %d\n", ids[i], r); regs[i] = NULL; continue; }
    r = search(regs[i], i, region);
    if (r == ONIG_MISMATCH) printf("%s\tMISMATCH\n", ids[i]);
    else if (r == ONIGERR_RETRY_LIMIT_IN_MATCH_OVER) printf("%s\tLIMIT\n", ids[i]);
    else if (r < 0) printf("%s\tERR %d\n", ids[i], r);
    else {
      printf("%s\tMATCH", ids[i]);
      for (int k = 0; k < region->num_regs; k++)
        printf(" %d %d", region->beg[k], region->end[k]);
      printf("\n");
    }
  }
  /* timing */
  long sink = 0;
  double t0 = now();
  for (int r = 0; r < reps; r++)
    for (int i = 0; i < nc; i++) {
      regex_t *reg;
      if (compile(i, &reg) == ONIG_NORMAL) onig_free(reg);
    }
  double t1 = now();
  for (int r = 0; r < reps; r++)
    for (int i = 0; i < nc; i++)
      if (regs[i]) sink += search(regs[i], i, region);
  double t2 = now();
  for (int r = 0; r < reps; r++)
    for (int i = 0; i < nc; i++) {
      regex_t *reg;
      if (compile(i, &reg) == ONIG_NORMAL) {
        sink += search(reg, i, region);
        onig_free(reg);
      }
    }
  double t3 = now();
  double tot = (double)nc * reps;
  fprintf(stderr, "cases=%d reps=%d parse_s=%.3f search_s=%.3f e2e_s=%.3f "
          "parse_cps=%.0f search_cps=%.0f e2e_cps=%.0f sink=%ld\n",
          nc, reps, t1 - t0, t2 - t1, t3 - t2, tot / (t1 - t0), tot / (t2 - t1),
          tot / (t3 - t2), sink);
  onig_region_free(region, 1);
  onig_end();
  return 0;
}
