/*
 * harness.c: semantic probe harness for Oniguruma (experiment #2).
 *
 * Reads a probe data file (TSV, see probes/README.md) and, for each probe,
 * compiles the pattern with onig_new under the named syntax, encoding and
 * options, searches the whole subject with onig_search, and prints one TSV
 * record per probe on stdout.
 *
 * Usage: harness FILE.tsv
 *
 * Build: see probes/Makefile (BUILD_TYPE is a string baked in at compile
 * time so that each record says which library it ran against).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "oniguruma.h"

#ifndef BUILD_TYPE
#define BUILD_TYPE "unknown"
#endif

#define MAXF 16
#define BUF 8192

static OnigSyntaxType strict_backref_syntax;

static OnigSyntaxType *syntax_of(const char *name)
{
  if (!strcmp(name, "Oniguruma")) return ONIG_SYNTAX_ONIGURUMA;
  if (!strcmp(name, "Ruby")) return ONIG_SYNTAX_RUBY;
  if (!strcmp(name, "Perl")) return ONIG_SYNTAX_PERL;
  if (!strcmp(name, "Perl_NG")) return ONIG_SYNTAX_PERL_NG;
  if (!strcmp(name, "Java")) return ONIG_SYNTAX_JAVA;
  if (!strcmp(name, "Python")) return ONIG_SYNTAX_PYTHON;
  if (!strcmp(name, "Oniguruma+STRICT_BACKREF")) return &strict_backref_syntax;
  return NULL;
}

static OnigEncoding encoding_of(const char *name)
{
  if (!strcmp(name, "UTF-8")) return ONIG_ENCODING_UTF8;
  if (!strcmp(name, "ISO-8859-1")) return ONIG_ENCODING_ISO_8859_1;
  return NULL;
}

static int options_of(const char *s, OnigOptionType *out)
{
  char buf[BUF];
  char *tok, *save;
  OnigOptionType o = ONIG_OPTION_NONE;
  strncpy(buf, s, BUF - 1); buf[BUF - 1] = 0;
  for (tok = strtok_r(buf, ",", &save); tok; tok = strtok_r(NULL, ",", &save)) {
    if (!strcmp(tok, "NONE") || !*tok) continue;
    else if (!strcmp(tok, "IGNORECASE")) o |= ONIG_OPTION_IGNORECASE;
    else if (!strcmp(tok, "IGNORECASE_IS_ASCII")) o |= ONIG_OPTION_IGNORECASE_IS_ASCII;
    else if (!strcmp(tok, "EXTEND")) o |= ONIG_OPTION_EXTEND;
    else if (!strcmp(tok, "MULTILINE")) o |= ONIG_OPTION_MULTILINE;
    else if (!strcmp(tok, "FIND_LONGEST")) o |= ONIG_OPTION_FIND_LONGEST;
    else if (!strcmp(tok, "CAPTURE_GROUP")) o |= ONIG_OPTION_CAPTURE_GROUP;
    else return -1;
  }
  *out = o;
  return 0;
}

static int hexval(int c)
{
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

/* Decode subject escapes: \xHH (one byte), \u{H..} (code point, encoded
   in the probe's encoding), \\, \t, \n.  Other text is copied verbatim
   (UTF-8 in the data file). */
static int decode_subject(const char *s, unsigned char *out, int utf8)
{
  int n = 0;
  while (*s) {
    if (s[0] == '\\' && s[1] == 'x' && hexval(s[2]) >= 0 && hexval(s[3]) >= 0) {
      out[n++] = (unsigned char)(hexval(s[2]) * 16 + hexval(s[3]));
      s += 4;
    } else if (s[0] == '\\' && s[1] == 'u' && s[2] == '{') {
      unsigned long cp = 0;
      s += 3;
      while (*s && *s != '}') cp = cp * 16 + hexval(*s++);
      if (*s == '}') s++;
      if (!utf8) out[n++] = (unsigned char)cp;
      else if (cp < 0x80) out[n++] = cp;
      else if (cp < 0x800) { out[n++] = 0xC0 | (cp >> 6); out[n++] = 0x80 | (cp & 0x3F); }
      else if (cp < 0x10000) { out[n++] = 0xE0 | (cp >> 12); out[n++] = 0x80 | ((cp >> 6) & 0x3F); out[n++] = 0x80 | (cp & 0x3F); }
      else { out[n++] = 0xF0 | (cp >> 18); out[n++] = 0x80 | ((cp >> 12) & 0x3F); out[n++] = 0x80 | ((cp >> 6) & 0x3F); out[n++] = 0x80 | (cp & 0x3F); }
    } else if (s[0] == '\\' && s[1] == '\\') { out[n++] = '\\'; s += 2; }
    else if (s[0] == '\\' && s[1] == 't') { out[n++] = '\t'; s += 2; }
    else if (s[0] == '\\' && s[1] == 'n') { out[n++] = '\n'; s += 2; }
    else out[n++] = (unsigned char)*s++;
  }
  return n;
}

/* Byte offset -> code point offset. */
static int cp_off(const unsigned char *s, int off, int utf8)
{
  int i, n = 0;
  if (!utf8) return off;
  for (i = 0; i < off; i++) if ((s[i] & 0xC0) != 0x80) n++;
  return n;
}

static void format_region(char *out, OnigRegion *rg, const unsigned char *s,
                          int utf8, int bytes)
{
  int i, k = 0;
  for (i = 0; i < rg->num_regs; i++) {
    const char *sep = i == 0 ? "M " : (i == 1 ? " | " : " ");
    if (i > 0) k += sprintf(out + k, "%s%d=", sep, i);
    else k += sprintf(out + k, "%s", sep);
    if (rg->beg[i] == ONIG_REGION_NOTPOS) k += sprintf(out + k, "-");
    else if (bytes) k += sprintf(out + k, "%d-%d", rg->beg[i], rg->end[i]);
    else k += sprintf(out + k, "%d-%d", cp_off(s, rg->beg[i], utf8),
                      cp_off(s, rg->end[i], utf8));
  }
}

int main(int argc, char *argv[])
{
  FILE *f;
  char line[BUF];
  OnigEncoding encs[2] = { ONIG_ENCODING_UTF8, ONIG_ENCODING_ISO_8859_1 };
  unsigned int cf;

  if (argc != 2) { fprintf(stderr, "usage: %s FILE.tsv\n", argv[0]); return 2; }
  f = fopen(argv[1], "r");
  if (!f) { perror(argv[1]); return 2; }

  onig_initialize(encs, 2);
  onig_copy_syntax(&strict_backref_syntax, ONIG_SYNTAX_ONIGURUMA);
  onig_set_syntax_behavior(&strict_backref_syntax,
    onig_get_syntax_behavior(&strict_backref_syntax) | ONIG_SYN_STRICT_CHECK_BACKREF);
  cf = onig_get_default_case_fold_flag();

  printf("id\tsyntax\tencoding\toptions\tcasefold\tversion\tbuild\tpattern\tsubject\tresult\tresult_bytes\n");
  while (fgets(line, sizeof line, f)) {
    char *fld[MAXF];
    int nf = 0;
    char *p = line;
    size_t L = strlen(line);
    if (L && line[L - 1] == '\n') line[--L] = 0;
    if (line[0] == '#' || line[0] == 0) continue;
    fld[nf++] = p;
    while ((p = strchr(p, '\t')) && nf < MAXF) { *p++ = 0; fld[nf++] = p; }
    if (nf < 6) { fprintf(stderr, "bad line: %s\n", line); continue; }
    if (!strcmp(fld[0], "id")) continue; /* header */
    {
      const char *id = fld[0], *syn = fld[1], *encn = fld[2], *opts = fld[3];
      const char *pat = fld[4], *subj = fld[5];
      OnigSyntaxType *sx = syntax_of(syn);
      OnigEncoding enc = encoding_of(encn);
      OnigOptionType o;
      unsigned char s[BUF];
      int sl, r, utf8;
      regex_t *reg;
      OnigErrorInfo einfo;
      char res[BUF], resb[BUF];

      if (!sx || !enc || options_of(opts, &o) < 0) {
        fprintf(stderr, "%s: bad syntax/encoding/options\n", id);
        continue;
      }
      /* Marker so that sanitizer reports on stderr can be attributed. */
      fprintf(stderr, "@@probe %s\n", id);
      utf8 = (enc == ONIG_ENCODING_UTF8);
      sl = decode_subject(subj, s, utf8);
      r = onig_new(&reg, (const UChar *)pat, (const UChar *)pat + strlen(pat),
                   o, enc, sx, &einfo);
      if (r != ONIG_NORMAL) {
        char msg[ONIG_MAX_ERROR_MESSAGE_LEN];
        onig_error_code_to_str((UChar *)msg, r, &einfo);
        sprintf(res, "E %d %s", r, msg);
        strcpy(resb, res);
      } else {
        OnigRegion *rg = onig_region_new();
        r = onig_search(reg, s, s + sl, s, s + sl, rg, ONIG_OPTION_NONE);
        if (r >= 0) {
          format_region(res, rg, s, utf8, 0);
          format_region(resb, rg, s, utf8, 1);
        } else if (r == ONIG_MISMATCH) {
          strcpy(res, "N"); strcpy(resb, "N");
        } else {
          char msg[ONIG_MAX_ERROR_MESSAGE_LEN];
          onig_error_code_to_str((UChar *)msg, r);
          sprintf(res, "X %d %s", r, msg);
          strcpy(resb, res);
        }
        onig_region_free(rg, 1);
        onig_free(reg);
      }
      printf("%s\t%s\t%s\t%s\t0x%x\t%s\t%s\t%s\t%s\t%s\t%s\n", id, syn, encn,
             *opts ? opts : "NONE", cf, onig_version(), BUILD_TYPE, pat, subj,
             res, resb);
      fflush(stdout);
    }
  }
  fclose(f);
  fprintf(stderr, "@@probe <exit>\n");
  onig_end();
  return 0;
}
