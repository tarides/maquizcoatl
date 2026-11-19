/* Experiment #12: C-only driver, same protocol and output as the OCaml
   harness (bench/main.ml) for the commands agree, time, scan and cata.
   Linked to the same libonig.so as the stubs and ctypes columns.
   Build: gcc -O2 -I<upstream>/src cdriver.c -L<lib> -lonig */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "oniguruma.h"

typedef struct { int pid, syntax, options; long limit, stack_limit; unsigned char *pat; size_t plen;
                 regex_t *reg; OnigRegion *region; OnigMatchParam *mp; int err; } Pat;
typedef struct { int sid; unsigned char *s; size_t len; } Subj;
typedef struct { int cid, pid, sid, kind; long start, range, sopt, weight; Pat *p; Subj *s; } Case;

static Pat *pats; static int npats, cpats;
static Subj *subs; static int nsubs, csubs;
static Case *cases; static int ncases, ccases;

static OnigSyntaxType *syntax_of(int s) {
  return s == 1 ? ONIG_SYNTAX_RUBY : s == 2 ? ONIG_SYNTAX_PERL_NG : ONIG_SYNTAX_ONIGURUMA;
}

static unsigned char *unhex(const char *h, size_t *len) {
  size_t n = strlen(h) / 2;
  unsigned char *r = malloc(n + 1);
  /* manual decode: sscanf would rescan the whole string (strlen) per byte */
  for (size_t i = 0; i < n; i++) {
    int a = h[2 * i], b = h[2 * i + 1];
    a = a <= '9' ? a - '0' : (a | 32) - 'a' + 10;
    b = b <= '9' ? b - '0' : (b | 32) - 'a' + 10;
    r[i] = (unsigned char) (a * 16 + b);
  }
  r[n] = 0; *len = n; return r;
}

static long long now_ns(void) {
  struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
  return (long long) t.tv_sec * 1000000000LL + t.tv_nsec;
}

static void compile_pat(Pat *p) {
  OnigErrorInfo einfo;
  p->err = onig_new(&p->reg, p->pat, p->pat + p->plen, (OnigOptionType) p->options,
                    ONIG_ENCODING_UTF8, syntax_of(p->syntax), &einfo);
  if (p->err != ONIG_NORMAL) { p->reg = NULL; return; }
  p->region = onig_region_new();
  p->mp = onig_new_match_param();
  onig_initialize_match_param(p->mp);
  onig_set_retry_limit_in_match_of_match_param(p->mp, (unsigned long) p->limit);
  onig_set_retry_limit_in_search_of_match_param(p->mp, 0);
  if (p->stack_limit > 0) onig_set_match_stack_limit_size_of_match_param(p->mp, (unsigned int) p->stack_limit);
}

static Pat *find_pat(int pid) { for (int i = 0; i < npats; i++) if (pats[i].pid == pid) return &pats[i]; return NULL; }
static Subj *find_subj(int sid) { for (int i = 0; i < nsubs; i++) if (subs[i].sid == sid) return &subs[i]; return NULL; }

static void read_work(const char *file) {
  FILE *f = fopen(file, "rb");
  if (!f) { perror("work"); exit(2); }
  char *line = NULL; size_t cap = 0; ssize_t n;
  while ((n = getline(&line, &cap, f)) > 0) {
    if (line[n - 1] == '\n') line[--n] = 0;
    if (line[0] == 'P') {
      if (npats == cpats) { cpats = cpats ? 2 * cpats : 64; pats = realloc(pats, cpats * sizeof *pats); }
      Pat *p = &pats[npats++]; memset(p, 0, sizeof *p);
      char *hx = malloc(n + 1); hx[0] = 0;
      sscanf(line, "P %d %d %d %ld %ld %s", &p->pid, &p->syntax, &p->options, &p->limit, &p->stack_limit, hx);
      p->pat = unhex(hx, &p->plen); free(hx);
    } else if (line[0] == 'S') {
      if (nsubs == csubs) { csubs = csubs ? 2 * csubs : 64; subs = realloc(subs, csubs * sizeof *subs); }
      Subj *s = &subs[nsubs++];
      char *hx = malloc(n + 1); hx[0] = 0;
      sscanf(line, "S %d %s", &s->sid, hx);
      s->s = unhex(hx, &s->len); free(hx);
    } else if (line[0] == 'C') {
      if (ncases == ccases) { ccases = ccases ? 2 * ccases : 64; cases = realloc(cases, ccases * sizeof *cases); }
      Case *c = &cases[ncases++];
      sscanf(line, "C %d %d %d %d %ld %ld %ld %ld", &c->cid, &c->pid, &c->sid, &c->kind,
             &c->start, &c->range, &c->sopt, &c->weight);
    }
  }
  free(line); fclose(f);
  for (int i = 0; i < npats; i++) compile_pat(&pats[i]);
  for (int i = 0; i < ncases; i++) { cases[i].p = find_pat(cases[i].pid); cases[i].s = find_subj(cases[i].sid); }
}

static int run_case(Case *c) {
  const UChar *str = c->s->s, *end = str + c->s->len;
  if (c->kind == 0)
    return onig_search_with_param(c->p->reg, str, end, str + c->start, str + c->range,
                                  c->p->region, (OnigOptionType) c->sopt, c->p->mp);
  return onig_match_with_param(c->p->reg, str, end, str + c->start, c->p->region,
                               (OnigOptionType) c->sopt, c->p->mp);
}

static void agree(void) {
  for (int i = 0; i < ncases; i++) {
    Case *c = &cases[i];
    if (!c->p->reg) { printf("%d CERR %d\n", c->cid, c->p->err); continue; }
    int r = run_case(c);
    if (r >= 0) {
      OnigRegion *rg = c->p->region;
      printf("%d %d %d", c->cid, r, rg->num_regs);
      for (int k = 0; k < rg->num_regs; k++) printf(" %d %d", rg->beg[k], rg->end[k]);
      printf("\n");
    } else printf("%d %d\n", c->cid, r);
  }
}

static volatile long sink;

static void timecmd(double minsec) {
  long calls_per_pass = 0; int ok = 0;
  for (int i = 0; i < ncases; i++) if (cases[i].p->reg) { calls_per_pass += cases[i].weight; ok++; }
  #define PASS do { for (int i = 0; i < ncases; i++) { Case *c = &cases[i]; if (!c->p->reg) continue; \
      for (long w = 0; w < c->weight; w++) sink += run_case(c); } } while (0)
  PASS;  /* warm-up, untimed */
  long long t0 = now_ns(), lim = (long long) (minsec * 1e9); long passes = 0;
  while (now_ns() - t0 < lim) { PASS; passes++; }
  long long t1 = now_ns();
  double ns = (double) (t1 - t0);
  printf("engine=c cases=%d skipped=%d calls_per_pass=%ld passes=%ld sec=%.6f ns_per_call=%.3f minor_per_call=0.0000 major_per_call=0.0000 sink=%ld\n",
         ok, ncases - ok, calls_per_pass, passes, ns / 1e9, ns / (double) (passes * calls_per_pass), sink & 1);
}

static int enc_len(unsigned c) { return c < 0xc2 ? 1 : c < 0xe0 ? 2 : c < 0xf0 ? 3 : c < 0xf5 ? 4 : 1; }

static void scan(const char *subjfile, int pid, double minsec) {
  Pat *p = find_pat(pid);
  if (!p) { fprintf(stderr, "no pid\n"); exit(2); }
  if (!p->reg) { printf("engine=c pid=%d CERR %d\n", pid, p->err); return; }
  FILE *f = fopen(subjfile, "rb"); fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
  unsigned char *s = malloc(n + 1); if (fread(s, 1, n, f) != (size_t) n) exit(3); fclose(f);
  long m = 0; int err = 0;
  #define ONE do { long pos = 0; m = 0; err = 0; while (pos <= n) { \
      int r = onig_search_with_param(p->reg, s, s + n, s + pos, s + n, p->region, 0, p->mp); \
      if (r >= 0) { m++; long fin = p->region->end[0]; \
        pos = fin > r ? fin : (r < n ? r + enc_len(s[r]) : n + 1); } \
      else { if (r != ONIG_MISMATCH) err = r; pos = n + 1; } } } while (0)
  ONE;  /* warm-up */
  long matches = m; int e0 = err;
  long long t0 = now_ns(), lim = (long long) (minsec * 1e9); long scans = 0;
  while (scans == 0 || now_ns() - t0 < lim) { ONE; scans++; }
  long long t1 = now_ns();
  double sec = (double) (t1 - t0) / 1e9 / (double) scans;
  printf("engine=c pid=%d bytes=%ld matches=%ld err=%d scans=%ld sec_per_scan=%.6f bytes_per_sec=%.1f minor_per_match=0.0000 major_per_match=0.0000\n",
         pid, n, matches, e0, scans, sec, (double) n / sec);
}

static void cata(int syntax, int options, const char *hexpat, int len, long limit) {
  Pat p; memset(&p, 0, sizeof p);
  p.syntax = syntax; p.options = options; p.limit = limit; p.pat = unhex(hexpat, &p.plen);
  compile_pat(&p);
  if (!p.reg) { printf("engine=c n=%d CERR %d\n", len, p.err); return; }
  unsigned char *s = malloc(len + 2); memset(s, 'a', len); s[len] = '!'; s[len + 1] = 0;
  long long t0 = now_ns();
  int r = onig_search_with_param(p.reg, s, s + len + 1, s, s + len + 1, p.region, 0, p.mp);
  long long t1 = now_ns();
  const char *o = r >= 0 ? "match" : r == ONIG_MISMATCH ? "nomatch" : r == -17 ? "limit" : "other";
  printf("engine=c n=%d result=%d outcome=%s sec=%.6f\n", len, r, o, (double) (t1 - t0) / 1e9);
}

int main(int argc, char **argv) {
  OnigEncoding enc[1] = { ONIG_ENCODING_UTF8 };
  onig_initialize(enc, 1);
  if (argc == 3 && !strcmp(argv[1], "agree")) { read_work(argv[2]); agree(); }
  else if (argc == 4 && !strcmp(argv[1], "time")) { read_work(argv[2]); timecmd(atof(argv[3])); }
  else if (argc == 6 && !strcmp(argv[1], "scan")) { read_work(argv[3]); scan(argv[2], atoi(argv[4]), atof(argv[5])); }
  else if (argc == 7 && !strcmp(argv[1], "cata")) cata(atoi(argv[2]), atoi(argv[3]), argv[4], atoi(argv[5]), atol(argv[6]));
  else { fprintf(stderr, "usage: cdriver agree WORK | time WORK MINSEC | scan SUBJ WORK PID MINSEC | cata SYN OPT HEXPAT N LIMIT\n"); return 2; }
  return 0;
}
