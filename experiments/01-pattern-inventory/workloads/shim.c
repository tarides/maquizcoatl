/* shim.c -- LD_PRELOAD logger for Oniguruma calls (experiment #1).
 * Build: cc -shared -fPIC -O2 -o libonigshim.so shim.c -ldl -I<onig include>
 * Use:   ONIGSHIM_LOG=/path/log.tsv LD_PRELOAD=./libonigshim.so <host> ...
 * Interposes onig_new, onig_search, onig_search_with_param, onig_match and
 * onig_match_with_param on the shared libonig.  Log lines (tab-separated,
 * byte strings hex-encoded):
 *   N  reg  syntax  options  encoding  pattern_hex  result
 *   S  reg  subject_hex  start  range  options  result  beg0  end0  retry_limit_in_match  match_stack_limit
 *   M  reg  subject_hex  at  -  options  result  beg0  end0  retry_limit  stack_limit
 * Subjects longer than ONIGSHIM_MAX_SUBJECT bytes (default 65536) are logged
 * as "len:<n>" instead of hex.  Each process stops logging after
 * ONIGSHIM_MAX_LOG bytes (default 50 MB), and logs at most ONIGSHIM_MAX_CALLS
 * search/match calls (default 5000), so a test suite cannot fill the disk.
 * Offsets are byte offsets from the subject start; limits are "-" when the
 * call carries no OnigMatchParam.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include "oniguruma.h"

static FILE* logf;
static long max_subject = 65536, max_log = 50L << 20, max_calls = 5000, ncalls;
static pthread_mutex_t mu = PTHREAD_MUTEX_INITIALIZER;

static FILE* get_log(void) {
  if (!logf) {
    const char* p = getenv("ONIGSHIM_LOG");
    logf = fopen(p ? p : "/dev/null", "a");
    const char* m = getenv("ONIGSHIM_MAX_SUBJECT");
    if (m) max_subject = atol(m);
    m = getenv("ONIGSHIM_MAX_LOG");
    if (m) max_log = atol(m);
    m = getenv("ONIGSHIM_MAX_CALLS");
    if (m) max_calls = atol(m);
  }
  return logf;
}

static int over_budget(FILE* f) { return ftell(f) > max_log; }

static void hex(FILE* f, const UChar* s, const UChar* e) {
  for (; s < e; s++) fprintf(f, "%02x", *s);
}

/* Looked up at run time so that the shim loads in processes that do not
   link libonig (e.g. the shell spawned by a test runner). */
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
  if (over_budget(f)) { pthread_mutex_unlock(&mu); return r; }
  fprintf(f, "N\t%p\t%s\t%u\t%s\t", r == ONIG_NORMAL ? (void*)*reg : NULL,
          syntax_name(syntax), option, enc_name(enc));
  hex(f, pattern, pattern_end);
  fprintf(f, "\t%d\n", r);
  fflush(f);
  pthread_mutex_unlock(&mu);
  return r;
}

static void log_call(char kind, regex_t* reg, const UChar* str, const UChar* end,
                     const UChar* start, const UChar* range, OnigOptionType option,
                     int r, OnigRegion* region, OnigMatchParam* mp) {
  (void)mp;
  pthread_mutex_lock(&mu);
  FILE* f = get_log();
  if (over_budget(f) || ++ncalls > max_calls) { pthread_mutex_unlock(&mu); return; }
  fprintf(f, "%c\t%p\t", kind, (void*)reg);
  if (end - str > max_subject) fprintf(f, "len:%ld", (long)(end - str));
  else hex(f, str, end);
  fprintf(f, "\t%ld\t", (long)(start - str));
  if (range) fprintf(f, "%ld", (long)(range - str)); else fputc('-', f);
  fprintf(f, "\t%u\t%d\t", option, r);
  if (r >= 0 && region && region->num_regs > 0)
    fprintf(f, "%d\t%d", region->beg[0], region->end[0]);
  else
    fprintf(f, "-\t-");
  /* OnigMatchParam is opaque in the public API; its leading fields are
     match_stack_limit then retry_limit_in_match (upstream/src/regexec.c:186-190,
     USE_RETRY_LIMIT is defined in the default build, regint.h:83). */
  if (mp) {
    struct { unsigned int stack; unsigned long retry; } *lp = (void*)mp;
    fprintf(f, "\t%lu\t%u\n", lp->retry, lp->stack);
  } else
    fprintf(f, "\t-\t-\n");
  fflush(f);
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
