/* shim_long.c -- LD_PRELOAD logger for long-subject Oniguruma calls
 * (experiment #1, follow-up for #12; added after #11 started).
 * Build: cc -shared -fPIC -O2 -o libonigshim_long.so shim_long.c -ldl -I<onig include>
 * Use:   ONIGSHIM_DIR=/path/dir LD_PRELOAD=./libonigshim_long.so <host> ...
 *
 * Same interposition as shim.c, but it logs only the calls whose subject is
 * longer than ONIGSHIM_MIN_SUBJECT bytes (default 4096, the cap of the main
 * capture), so it captures what shim.c drops.  Hard caps, per process:
 *   ONIGSHIM_PER_PROCESS  long calls logged (default 5: the first 5)
 *   ONIGSHIM_MAX_SUBJECT  subject bytes (default 262144; longer subjects are
 *                         only counted, on the "L" line)
 *   ONIGSHIM_MAX_LOG      bytes written (default 4 MB)
 * Each process writes its own file <ONIGSHIM_DIR>/<pid>.tsv (no interleaving
 * between parallel test processes).  Lines (tab-separated, hex for bytes):
 *   P  script                       (last argument of the command line ending in .php, or argv[0])
 *   N  reg  syntax  options  encoding  pattern_hex  result
 *   D  subject_key  length  subject_hex   (once per distinct subject in the process)
 *   S  reg  subject_key  start  range  options  result  beg0  end0  retry_limit  stack_limit
 *   M  reg  subject_key  at  -  options  result  beg0  end0  retry_limit  stack_limit
 *   L  count  max_length            (at exit: long calls not logged because of a cap)
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <pthread.h>
#include "oniguruma.h"

static FILE* logf;
static int opened;
static long min_subject = 4096, max_subject = 262144, max_log = 4L << 20, per_process = 5, nlong;
static long nskipped, skipped_max;
static uint64_t keys[64];
static int nkeys;
static pthread_mutex_t mu = PTHREAD_MUTEX_INITIALIZER;

static void script_name(FILE* f) {
  char buf[8192];
  FILE* c = fopen("/proc/self/cmdline", "r");
  size_t n = c ? fread(buf, 1, sizeof buf - 1, c) : 0;
  if (c) fclose(c);
  buf[n] = 0;
  const char *best = buf, *p = buf;
  while (p < buf + n) {
    size_t l = strlen(p);
    if (l > 4 && strcmp(p + l - 4, ".php") == 0) best = p;
    p += l + 1;
  }
  fprintf(f, "P\t%s\n", best);
}

static FILE* get_log(void) {
  if (!opened) {
    opened = 1;
    const char* d = getenv("ONIGSHIM_DIR");
    if (d) {
      char path[4096];
      snprintf(path, sizeof path, "%s/%ld.tsv", d, (long)getpid());
      logf = fopen(path, "a");
    }
    const char* m;
    if ((m = getenv("ONIGSHIM_MIN_SUBJECT"))) min_subject = atol(m);
    if ((m = getenv("ONIGSHIM_MAX_SUBJECT"))) max_subject = atol(m);
    if ((m = getenv("ONIGSHIM_MAX_LOG"))) max_log = atol(m);
    if ((m = getenv("ONIGSHIM_PER_PROCESS"))) per_process = atol(m);
    if (per_process > 64) per_process = 64;
    if (logf) script_name(logf);
  }
  return logf;
}

static int over_budget(FILE* f) { return ftell(f) > max_log; }

static void hex(FILE* f, const UChar* s, const UChar* e) {
  for (; s < e; s++) fprintf(f, "%02x", *s);
}

static uint64_t fnv1a(const UChar* s, const UChar* e) {
  uint64_t h = 1469598103934665603ULL;
  for (; s < e; s++) { h ^= *s; h *= 1099511628211ULL; }
  return h;
}

static const char* syntax_name(OnigSyntaxType* s) {
  static const char* names[][2] = {
    {"OnigSyntaxOniguruma", "ONIGURUMA"}, {"OnigSyntaxRuby", "RUBY"},
    {"OnigSyntaxPerl_NG", "PERL_NG"}, {"OnigSyntaxPerl", "PERL"},
    {"OnigSyntaxJava", "JAVA"}, {"OnigSyntaxPython", "PYTHON"},
    {"OnigSyntaxGnuRegex", "GNU_REGEX"}, {"OnigSyntaxGrep", "GREP"},
    {"OnigSyntaxEmacs", "EMACS"}, {"OnigSyntaxPosixBasic", "POSIX_BASIC"},
    {"OnigSyntaxPosixExtended", "POSIX_EXTENDED"}, {"OnigSyntaxASIS", "ASIS"},
  };
  for (size_t i = 0; i < sizeof names / sizeof names[0]; i++)
    if ((void*)s == dlsym(RTLD_DEFAULT, names[i][0])) return names[i][1];
  return "OTHER";
}

static const char* enc_name(OnigEncoding e) {
  return e && e->name ? e->name : "?";
}

#define REAL(name) static __typeof__(name)* real_##name; \
  if (!real_##name) real_##name = (__typeof__(name)*)dlsym(RTLD_NEXT, #name)

int onig_new(OnigRegex* reg, const UChar* pattern, const UChar* pattern_end,
             OnigOptionType option, OnigEncoding enc, OnigSyntaxType* syntax,
             OnigErrorInfo* einfo) {
  REAL(onig_new);
  int r = real_onig_new(reg, pattern, pattern_end, option, enc, syntax, einfo);
  pthread_mutex_lock(&mu);
  FILE* f = get_log();
  if (f && !over_budget(f)) {
    fprintf(f, "N\t%p\t%s\t%u\t%s\t", r == ONIG_NORMAL ? (void*)*reg : NULL,
            syntax_name(syntax), option, enc_name(enc));
    hex(f, pattern, pattern_end);
    fprintf(f, "\t%d\n", r);
    fflush(f);
  }
  pthread_mutex_unlock(&mu);
  return r;
}

static void log_call(char kind, regex_t* reg, const UChar* str, const UChar* end,
                     const UChar* start, const UChar* range, OnigOptionType option,
                     int r, OnigRegion* region, OnigMatchParam* mp) {
  if (end - str <= min_subject && opened) return;
  pthread_mutex_lock(&mu);
  FILE* f = get_log();
  if (!f || end - str <= min_subject) { pthread_mutex_unlock(&mu); return; }
  if (over_budget(f) || nlong >= per_process || end - str > max_subject) {
    nskipped++;
    if (end - str > skipped_max) skipped_max = end - str;
    pthread_mutex_unlock(&mu);
    return;
  }
  nlong++;
  uint64_t k = fnv1a(str, end) ^ (uint64_t)(end - str);
  int seen = 0;
  for (int i = 0; i < nkeys; i++) if (keys[i] == k) seen = 1;
  if (!seen) {
    keys[nkeys++] = k;
    fprintf(f, "D\t%016llx\t%ld\t", (unsigned long long)k, (long)(end - str));
    hex(f, str, end);
    fputc('\n', f);
  }
  fprintf(f, "%c\t%p\t%016llx\t%ld\t", kind, (void*)reg, (unsigned long long)k, (long)(start - str));
  if (range) fprintf(f, "%ld", (long)(range - str)); else fputc('-', f);
  fprintf(f, "\t%u\t%d\t", option, r);
  if (r >= 0 && region && region->num_regs > 0)
    fprintf(f, "%d\t%d", region->beg[0], region->end[0]);
  else
    fprintf(f, "-\t-");
  /* Same layout assumption as shim.c (upstream/src/regexec.c:186-190). */
  if (mp) {
    struct { unsigned int stack; unsigned long retry; } *lp = (void*)mp;
    fprintf(f, "\t%lu\t%u\n", lp->retry, lp->stack);
  } else
    fprintf(f, "\t-\t-\n");
  fflush(f);
  pthread_mutex_unlock(&mu);
}

__attribute__((destructor)) static void finish(void) {
  pthread_mutex_lock(&mu);
  if (logf && nskipped) { fprintf(logf, "L\t%ld\t%ld\n", nskipped, skipped_max); fflush(logf); }
  pthread_mutex_unlock(&mu);
}

int onig_search(OnigRegex reg, const UChar* str, const UChar* end,
                const UChar* start, const UChar* range, OnigRegion* region,
                OnigOptionType option) {
  REAL(onig_search);
  int r = real_onig_search(reg, str, end, start, range, region, option);
  log_call('S', reg, str, end, start, range, option, r, region, NULL);
  return r;
}

int onig_search_with_param(OnigRegex reg, const UChar* str, const UChar* end,
                           const UChar* start, const UChar* range, OnigRegion* region,
                           OnigOptionType option, OnigMatchParam* mp) {
  REAL(onig_search_with_param);
  int r = real_onig_search_with_param(reg, str, end, start, range, region, option, mp);
  log_call('S', reg, str, end, start, range, option, r, region, mp);
  return r;
}

int onig_match(OnigRegex reg, const UChar* str, const UChar* end, const UChar* at,
               OnigRegion* region, OnigOptionType option) {
  REAL(onig_match);
  int r = real_onig_match(reg, str, end, at, region, option);
  log_call('M', reg, str, end, at, NULL, option, r, region, NULL);
  return r;
}

int onig_match_with_param(OnigRegex reg, const UChar* str, const UChar* end,
                          const UChar* at, OnigRegion* region, OnigOptionType option,
                          OnigMatchParam* mp) {
  REAL(onig_match_with_param);
  int r = real_onig_match_with_param(reg, str, end, at, region, option, mp);
  log_call('M', reg, str, end, at, NULL, option, r, region, mp);
  return r;
}
