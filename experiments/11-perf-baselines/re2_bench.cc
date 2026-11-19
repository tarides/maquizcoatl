// Experiment #11: RE2 harness.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <re2/re2.h>
#include "driver_types.h"
#define ENGINE_NAME "re2"

#define O_IGNORECASE 1u
#define O_EXTEND 2u
#define O_MULTILINE 4u
#define O_SINGLELINE 8u
#define O_NEGATE_SINGLELINE 64u
#define O_CAPTURE_GROUP_BITS (128u | 256u)

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
  if (strcmp(p->encoding, "UTF-8") || !perl_like(p)) { snprintf(why, 128, "syntax or encoding"); return ST_UNSUP; }
  // RE2 has no extended (x) mode and no find-not-empty.
  if (p->options & ~(O_IGNORECASE | O_MULTILINE | O_SINGLELINE | O_CAPTURE_GROUP_BITS)) {
    snprintf(why, 128, "option %lu", p->options); return ST_UNSUP;
  }
  RE2::Options o;            // defaults: UTF-8, max_mem 8 MiB
  o.set_log_errors(false);
  o.set_case_sensitive(!(p->options & O_IGNORECASE));
  o.set_dot_nl(p->options & O_MULTILINE);
  std::string pat((const char *)p->pat, p->len);
  if (!singleline(p)) pat = "(?m)" + pat;   // '^' '$' at line boundaries
  RE2 *re = new RE2(pat, o);
  if (!re->ok()) {
    int c = re->error_code();
    snprintf(why, 128, "%d", c);
    delete re;
    return (c == RE2::ErrorPatternTooLarge) ? ST_LIMIT : ST_ERR;
  }
  *out = re;
  return ST_OK;
}

static void eng_free(void *p) { delete (RE2 *)p; }

static int eng_search(void *p, const unsigned char *s, size_t len, size_t start, size_t *ms, size_t *me)
{
  RE2 *re = (RE2 *)p;
  absl::string_view text((const char *)s, len), m;
  if (!re->Match(text, start, len, RE2::UNANCHORED, &m, 1)) return 0;
  *ms = m.data() - (const char *)s; *me = *ms + m.size();
  return 1;
}

#include "driver.h"
