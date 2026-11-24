/* Experiment #11: common driver for the C and C++ harnesses.
 *
 * An engine file defines ENGINE_NAME and the functions below, then
 * includes this file. Usage of the resulting binary:
 *
 *   <bin> check   <workload-dir>                 agreement listing (stdout)
 *   <bin> compile <workload-dir> [<only-file>]   compile timing
 *   <bin> time    <workload-dir> [<only-file>]   search timing
 *   <bin> worst   <pattern> <syntax> <options> <n>   one search of "a"*n "!"
 *
 * <only-file> lists the pattern ids to include (one per line); without
 * it every pattern the engine compiles is included.
 *
 * Compile and search timing run in separate processes, so that the
 * compile loop cannot change the state (heap, caches, branch
 * predictors) the search is timed in. Both modes first compile every
 * pattern once, untimed, to know which ones the engine accepts.
 *
 * `compile` prints one line per included pattern:
 *   C <pid> <median compile nanoseconds> <compilations>
 * `time` prints:
 *   W <warm-up pass seconds> <minimum repetition seconds, 0 for no byte>
 *   T <rep> <seconds per pass> <passes in this repetition>   (nrep lines)
 *   S bytes_per_pass=... matches_per_pass=... included_patterns=...
 * A repetition repeats whole passes until it has lasted at least the
 * minimum (E11_REP_MIN, default 0.5 s); its time is its length divided
 * by its number of passes. The Rust and OCaml harnesses do the same.
 *
 * eng_search extracts every capture group of the match, as a caller
 * that needs the groups would; only the overall match is reported.
 *
 * Matches are enumerated identically in every engine: search from a
 * start offset in the whole subject, starting at 0; after a match
 * [s, e) the next search starts at e, or, when s == e, at e plus one
 * character (eng_advance: one UTF-8 code point, one byte if the lead
 * byte is not a valid UTF-8 lead byte).
 */
#include "driver_types.h"

/* Engine interface. eng_compile returns a status and sets *re (ST_OK)
 * or writes a short reason into why[128]. eng_search returns 1 and
 * sets *ms, *me on a match, 0 when there is none, a negative engine
 * error code otherwise. */
static int eng_compile(const pattern_t *p, void **re, char *why);
static void eng_free(void *re);
static int eng_search(void *re, const unsigned char *s, size_t len,
                      size_t start, size_t *ms, size_t *me);
#ifndef ENG_ADVANCE
static size_t eng_advance(void *re, const unsigned char *s, size_t len, size_t at)
{
  (void)re;
  return utf8_advance(s, len, at);
}
#endif

static double now(void)
{
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static unsigned char *unhex(const char *h, size_t *len)
{
  size_t n = strlen(h) / 2, i;
  unsigned char *b = (unsigned char *)malloc(n + 1);
  for (i = 0; i < n; i++) {
    unsigned v;
    sscanf(h + 2 * i, "%2x", &v);
    b[i] = (unsigned char)v;
  }
  b[n] = 0;
  *len = n;
  return b;
}

static char *read_line(FILE *f)
{
  static char *buf = NULL;
  static size_t cap = 0;
  ssize_t r = getline(&buf, &cap, f);
  if (r < 0) return NULL;
  if (r > 0 && buf[r - 1] == '\n') buf[r - 1] = 0;
  return buf;
}

static FILE *open_in(const char *dir, const char *name)
{
  char path[4096];
  FILE *f;
  snprintf(path, sizeof path, "%s/%s", dir, name);
  f = fopen(path, "r");
  if (!f) { fprintf(stderr, "cannot open %s\n", name); exit(2); }
  return f;
}

static pattern_t *pats; static int npats;
static subject_t *subs; static int nsubs;
static int (*pairs)[2]; static int npairs;

static void load(const char *dir)
{
  FILE *f; char *l; int cap;
  f = open_in(dir, "patterns.tsv"); cap = 16; pats = (pattern_t *)malloc(cap * sizeof *pats);
  while ((l = read_line(f))) {
    char id[64];
    char *h;
    pattern_t *p;
    if (npats == cap) { cap *= 2; pats = (pattern_t *)realloc(pats, cap * sizeof *pats); }
    p = &pats[npats++];
    sscanf(l, "%d\t%63s\t%31s\t%lu\t%31s", &p->pid, id, p->syntax, &p->options, p->encoding);
    h = strrchr(l, '\t') + 1;
    p->pat = unhex(h, &p->len);
  }
  fclose(f);
  f = open_in(dir, "subjects.tsv"); cap = 16; subs = (subject_t *)malloc(cap * sizeof *subs);
  while ((l = read_line(f))) {
    char *h = strchr(l, '\t') + 1;
    if (nsubs == cap) { cap *= 2; subs = (subject_t *)realloc(subs, cap * sizeof *subs); }
    subs[nsubs].s = unhex(h, &subs[nsubs].len); nsubs++;
  }
  fclose(f);
  f = open_in(dir, "pairs.tsv"); cap = 16; pairs = (int (*)[2])malloc(cap * sizeof *pairs);
  while ((l = read_line(f))) {
    if (npairs == cap) { cap *= 2; pairs = (int (*)[2])realloc(pairs, cap * sizeof *pairs); }
    sscanf(l, "%d\t%d", &pairs[npairs][0], &pairs[npairs][1]); npairs++;
  }
  fclose(f);
}

static void **res; static int *status; static char (*whys)[128];

static void compile_all(void)
{
  int i;
  res = (void **)calloc(npats, sizeof *res);
  status = (int *)calloc(npats, sizeof *status);
  whys = (char (*)[128])calloc(npats, sizeof *whys);
  for (i = 0; i < npats; i++) status[i] = eng_compile(&pats[i], &res[i], whys[i]);
}

/* Enumerate the matches of one pair; returns the number of matches,
 * calls out() for each when non-NULL, stores an error code in *err. */
static long enum_pair(int i, FILE *out, int *err)
{
  int pid = pairs[i][0];
  subject_t *sb = &subs[pairs[i][1]];
  size_t pos = 0, ms, me;
  long n = 0;
  *err = 0;
  while (pos <= sb->len) {
    int r = eng_search(res[pid], sb->s, sb->len, pos, &ms, &me);
    if (r < 0) { *err = r; break; }
    if (r == 0) break;
    n++;
    if (out) fprintf(out, " %zu-%zu", ms, me);
    if (me > ms) pos = me;
    else { if (me >= sb->len) break; pos = me + eng_advance(res[pid], sb->s, sb->len, me); }
  }
  return n;
}

static int cmpd(const void *a, const void *b)
{
  double x = *(const double *)a, y = *(const double *)b;
  return x < y ? -1 : x > y;
}

static char *include; /* per pid: 1 when timed */

static double pass(long *matches, double *bytes)
{
  int i, err;
  long m = 0;
  double b = 0, t0 = now();
  for (i = 0; i < npairs; i++) {
    if (!include[pairs[i][0]]) continue;
    m += enum_pair(i, NULL, &err);
    b += subs[pairs[i][1]].len;
  }
  if (matches) *matches = m;
  if (bytes) *bytes = b;
  return now() - t0;
}

static int do_check(const char *dir)
{
  int i, err;
  double t;
  load(dir);
  compile_all();
  for (i = 0; i < npats; i++) {
    static const char *nm[] = {"ok", "err", "unsup", "limit"};
    printf("P\t%d\t%s\t%s\n", i, nm[status[i]], whys[i]);
  }
  for (i = 0; i < npairs; i++) {
    if (status[pairs[i][0]] != ST_OK) continue;
    printf("M\t%d\t%d\t", pairs[i][0], pairs[i][1]);
    enum_pair(i, stdout, &err);
    if (err) printf(" !%d", err);
    printf("\n");
  }
  include = (char *)malloc(npats);
  for (i = 0; i < npats; i++) include[i] = status[i] == ST_OK;
  t = pass(NULL, NULL);
  printf("PASS\t%.6f\n", t);
  return 0;
}

/* Loads the workload, compiles every pattern once (untimed) and sets
 * include[]: the patterns listed in <only> that compile, or every
 * pattern that compiles when <only> is NULL. Returns 0, or 2 when the
 * only-file cannot be read. */
static int setup(const char *dir, const char *only)
{
  int i;
  load(dir);
  compile_all();
  include = (char *)malloc(npats);
  for (i = 0; i < npats; i++) include[i] = only ? 0 : status[i] == ST_OK;
  if (only) {
    FILE *f = fopen(only, "r");
    char *l;
    if (!f) { fprintf(stderr, "cannot open only-file\n"); return 2; }
    while ((l = read_line(f))) { int p = atoi(l); if (p >= 0 && p < npats && status[p] == ST_OK) include[p] = 1; }
    fclose(f);
  }
  return 0;
}

static int do_compile(const char *dir, const char *only)
{
  int i, r;
  /* Protocol parameters (plan step 7), overridable for the projection. */
  long cmin_n = getenv("E11_COMPILE_N") ? atol(getenv("E11_COMPILE_N")) : 1000;
  double cmin_t = getenv("E11_COMPILE_MIN") ? atof(getenv("E11_COMPILE_MIN")) : 0.010;
  double ccap = getenv("E11_COMPILE_CAP") ? atof(getenv("E11_COMPILE_CAP")) : 1.0;
  size_t ccap_n = 1024;
  double *ct;
  if ((r = setup(dir, only))) return r;
  ct = (double *)malloc(sizeof(double) * ccap_n);
  /* Compile time per pattern: compilations until at least cmin_n of
   * them and cmin_t seconds, or ccap seconds; their median. */
  for (i = 0; i < npats; i++) {
    long n = 0;
    double start, el;
    char why[128];
    if (!include[i]) continue;
    start = now();
    for (;;) {
      void *re = NULL;
      double a = now(), d;
      eng_compile(&pats[i], &re, why);
      d = now() - a;
      eng_free(re);
      if ((size_t)n == ccap_n) { ccap_n *= 2; ct = (double *)realloc(ct, ccap_n * sizeof(double)); }
      ct[n++] = d;
      el = now() - start;
      if ((n >= cmin_n && el >= cmin_t) || el >= ccap) break;
    }
    qsort(ct, n, sizeof(double), cmpd);
    printf("C\t%d\t%.1f\t%ld\n", i, ct[n / 2] * 1e9, n);
  }
  free(ct);
  fflush(stdout);
  return 0;
}

static int do_time(const char *dir, const char *only)
{
  int i, r, rep, k, npass, nrep;
  long matches;
  double bytes, t, *ts;
  double rep_min = getenv("E11_REP_MIN") ? atof(getenv("E11_REP_MIN")) : 0.5;
  nrep = getenv("E11_REPS") ? atoi(getenv("E11_REPS")) : 5;
  if ((r = setup(dir, only))) return r;
  /* Search: one untimed warm-up pass, then nrep repetitions. Each
   * repetition repeats whole passes until at least rep_min seconds
   * have elapsed, so its length does not depend on an estimate taken
   * on the (slower) warm-up pass. A pass with no subject byte (every
   * pair excluded) has nothing to time: one pass per repetition. */
  t = pass(&matches, &bytes);
  if (bytes == 0) rep_min = 0;
  printf("W\t%.6f\t%g\n", t, rep_min);
  ts = (double *)malloc(nrep * sizeof(double));
  for (rep = 0; rep < nrep; rep++) {
    double t0 = now(), el;
    npass = 0;
    do { pass(NULL, NULL); npass++; el = now() - t0; } while (el < rep_min);
    ts[rep] = el / npass;
    printf("T\t%d\t%.9f\t%d\n", rep, ts[rep], npass);
  }
  printf("S\tbytes_per_pass=%.0f\tmatches_per_pass=%ld\tincluded_patterns=", bytes, matches);
  for (k = 0, i = 0; i < npats; i++) k += include[i];
  printf("%d\n", k);
  fflush(stdout);
  return 0;
}

static int do_worst(const char *pat, const char *syntax, const char *opts, int n)
{
  pattern_t p;
  void *re = NULL;
  char why[128];
  unsigned char *s;
  size_t ms, me;
  int st, r;
  double t0, t;
  memset(&p, 0, sizeof p);
  strncpy(p.syntax, syntax, sizeof p.syntax - 1);
  strcpy(p.encoding, "UTF-8");
  p.options = strtoul(opts, NULL, 0);
  p.pat = (unsigned char *)pat; p.len = strlen(pat);
  st = eng_compile(&p, &re, why);
  if (st != ST_OK) { printf("compile\t%d\t%s\n", st, why); return 0; }
  s = (unsigned char *)malloc(n + 2);
  memset(s, 'a', n); s[n] = '!'; s[n + 1] = 0;
  t0 = now();
  r = eng_search(re, s, n + 1, 0, &ms, &me);
  t = now() - t0;
  printf("result\t%d\t%.6f\n", r, t);
  return 0;
}

int main(int argc, char **argv)
{
  if (argc >= 3 && !strcmp(argv[1], "check")) return do_check(argv[2]);
  if (argc >= 3 && !strcmp(argv[1], "compile")) return do_compile(argv[2], argc > 3 ? argv[3] : NULL);
  if (argc >= 3 && !strcmp(argv[1], "time")) return do_time(argv[2], argc > 3 ? argv[3] : NULL);
  if (argc >= 6 && !strcmp(argv[1], "worst")) return do_worst(argv[2], argv[3], argv[4], atoi(argv[5]));
#ifdef ENG_EXTRA_MAIN
  ENG_EXTRA_MAIN
#endif
  fprintf(stderr, "usage: %s check|compile|time|worst ...\n", argv[0]);
  return 2;
}
