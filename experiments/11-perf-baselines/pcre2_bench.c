/* Experiment #11: PCRE2 harness. Built twice: -DE11_JIT=0 (interpreter)
 * and -DE11_JIT=1 (JIT; compile time includes pcre2_jit_compile). */
#define PCRE2_CODE_UNIT_WIDTH 8
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pcre2.h>
#include "driver_types.h"
#ifndef E11_JIT
#define E11_JIT 0
#endif
#define ENGINE_NAME (E11_JIT ? "pcre2-jit" : "pcre2-interp")

typedef struct { pcre2_code *re; pcre2_match_data *md; uint32_t mopts; } pc_re;

/* Oniguruma options (oniguruma.h) used by the workloads. */
#define O_IGNORECASE 1u
#define O_EXTEND 2u
#define O_MULTILINE 4u          /* Oniguruma: '.' matches newline */
#define O_SINGLELINE 8u         /* '^' '$' are buffer anchors */
#define O_FIND_LONGEST 16u
#define O_FIND_NOT_EMPTY 32u
#define O_NEGATE_SINGLELINE 64u
#define O_CAPTURE_GROUP_BITS (128u | 256u)

/* Translation of a pattern triple into engine flags, identical in
 * spirit for every non-Oniguruma engine: syntax must be one of the
 * Perl-like flavours; the effective SINGLELINE is the option or the
 * syntax default (PERL_NG, PERL, JAVA, PYTHON set it). */
static int singleline(const pattern_t *p)
{
  if (p->options & O_NEGATE_SINGLELINE) return 0;
  return (p->options & O_SINGLELINE) || !strcmp(p->syntax, "PERL_NG") || !strcmp(p->syntax, "PERL")
    || !strcmp(p->syntax, "JAVA") || !strcmp(p->syntax, "PYTHON");
}
static int perl_like(const pattern_t *p)
{
  return !strcmp(p->syntax, "ONIGURUMA") || !strcmp(p->syntax, "RUBY") || !strcmp(p->syntax, "PERL_NG")
    || !strcmp(p->syntax, "PERL") || !strcmp(p->syntax, "JAVA") || !strcmp(p->syntax, "PYTHON");
}

static int eng_compile(const pattern_t *p, void **out, char *why)
{
  uint32_t o = PCRE2_UTF | PCRE2_UCP | PCRE2_MATCH_INVALID_UTF;
  int err;
  PCRE2_SIZE off;
  pcre2_code *re;
  pc_re *r;
  if (strcmp(p->encoding, "UTF-8") || !perl_like(p)) { snprintf(why, 128, "syntax or encoding"); return ST_UNSUP; }
  if (p->options & ~(O_IGNORECASE | O_EXTEND | O_MULTILINE | O_SINGLELINE | O_FIND_NOT_EMPTY | O_CAPTURE_GROUP_BITS)) {
    snprintf(why, 128, "option %lu", p->options); return ST_UNSUP;
  }
  if (p->options & O_IGNORECASE) o |= PCRE2_CASELESS;
  if (p->options & O_EXTEND) o |= PCRE2_EXTENDED;
  if (p->options & O_MULTILINE) o |= PCRE2_DOTALL;
  if (!singleline(p)) o |= PCRE2_MULTILINE;
  re = pcre2_compile(p->pat, p->len, o, &err, &off, NULL);
  if (!re) {
    snprintf(why, 128, "%d", err);
    return (err == PCRE2_ERROR_PATTERN_TOO_LARGE || err == PCRE2_ERROR_HEAP_FAILED) ? ST_LIMIT : ST_ERR;
  }
  if (E11_JIT) {
    int j = pcre2_jit_compile(re, PCRE2_JIT_COMPLETE);
    if (j != 0) { snprintf(why, 128, "jit %d", j); pcre2_code_free(re); return j == PCRE2_ERROR_NOMEMORY ? ST_LIMIT : ST_ERR; }
  }
  r = (pc_re *)malloc(sizeof *r);
  r->re = re;
  r->md = pcre2_match_data_create_from_pattern(re, NULL);
  r->mopts = (p->options & O_FIND_NOT_EMPTY) ? PCRE2_NOTEMPTY : 0;
  *out = r;
  return ST_OK;
}

static void eng_free(void *p)
{
  pc_re *r = (pc_re *)p;
  if (!r) return;
  pcre2_match_data_free(r->md);
  pcre2_code_free(r->re);
  free(r);
}

static int eng_search(void *p, const unsigned char *s, size_t len, size_t start, size_t *ms, size_t *me)
{
  pc_re *r = (pc_re *)p;
  /* pcre2_match uses the JIT code when it exists (JIT build) and the
   * interpreter otherwise. Default match context: match limit
   * 10,000,000, depth limit and heap limit at their defaults, JIT stack
   * 32 KiB (no pcre2_jit_stack_assign). */
  int rc = pcre2_match(r->re, s, len, start, r->mopts, r->md, NULL);
  if (rc == PCRE2_ERROR_NOMATCH) return 0;
  if (rc < 0) return rc;
  PCRE2_SIZE *ov = pcre2_get_ovector_pointer(r->md);
  *ms = ov[0]; *me = ov[1];
  return 1;
}

#include "driver.h"
