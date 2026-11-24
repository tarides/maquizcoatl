/* Experiment #11: Oniguruma harness (both dispatch builds link this). */
#define ENGINE_NAME "oniguruma"
#define ENG_ADVANCE
#include "driver_types.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <oniguruma.h>

typedef struct { regex_t *re; OnigRegion *region; OnigEncoding enc; } onig_re;

static OnigSyntaxType *syntax_of(const char *s)
{
  if (!strcmp(s, "ONIGURUMA")) return ONIG_SYNTAX_ONIGURUMA;
  if (!strcmp(s, "RUBY")) return ONIG_SYNTAX_RUBY;
  if (!strcmp(s, "PERL_NG")) return ONIG_SYNTAX_PERL_NG;
  if (!strcmp(s, "PERL")) return ONIG_SYNTAX_PERL;
  if (!strcmp(s, "JAVA")) return ONIG_SYNTAX_JAVA;
  if (!strcmp(s, "PYTHON")) return ONIG_SYNTAX_PYTHON;
  if (!strcmp(s, "POSIX_BASIC")) return ONIG_SYNTAX_POSIX_BASIC;
  if (!strcmp(s, "POSIX_EXTENDED")) return ONIG_SYNTAX_POSIX_EXTENDED;
  if (!strcmp(s, "GREP")) return ONIG_SYNTAX_GREP;
  if (!strcmp(s, "EMACS")) return ONIG_SYNTAX_EMACS;
  return NULL;
}

static OnigEncoding enc_of(const char *e)
{
  if (!strcmp(e, "UTF-8")) return ONIG_ENCODING_UTF8;
  if (!strcmp(e, "EUC-JP")) return ONIG_ENCODING_EUC_JP;
  if (!strcmp(e, "Shift_JIS")) return ONIG_ENCODING_SJIS;
  if (!strcmp(e, "ISO-8859-1")) return ONIG_ENCODING_ISO_8859_1;
  return NULL;
}

static int eng_compile(const pattern_t *p, void **out, char *why)
{
  OnigSyntaxType *syn = syntax_of(p->syntax);
  OnigEncoding enc = enc_of(p->encoding);
  OnigErrorInfo einfo;
  regex_t *re;
  int r;
  if (!syn || !enc) { snprintf(why, 128, "syntax or encoding"); return ST_UNSUP; }
  r = onig_new(&re, p->pat, p->pat + p->len, (OnigOptionType)p->options, enc, syn, &einfo);
  if (r != ONIG_NORMAL) { snprintf(why, 128, "%d", r); return ST_ERR; }
  onig_re *o = (onig_re *)malloc(sizeof *o);
  o->re = re; o->region = onig_region_new(); o->enc = enc;
  *out = o;
  return ST_OK;
}

static void eng_free(void *p)
{
  onig_re *o = (onig_re *)p;
  if (!o) return;
  onig_region_free(o->region, 1);
  onig_free(o->re);
  free(o);
}

static int eng_search(void *p, const unsigned char *s, size_t len, size_t start, size_t *ms, size_t *me)
{
  onig_re *o = (onig_re *)p;
  int r = onig_search(o->re, s, s + len, s + start, s + len, o->region, ONIG_OPTION_NONE);
  if (r == ONIG_MISMATCH) return 0;
  if (r < 0) return r;
  *ms = o->region->beg[0]; *me = o->region->end[0];
  return 1;
}

static size_t eng_advance(void *p, const unsigned char *s, size_t len, size_t at)
{
  onig_re *o = (onig_re *)p;
  int n;
  if (o->enc == ONIG_ENCODING_UTF8) return utf8_advance(s, len, at);
  n = ONIGENC_MBC_ENC_LEN(o->enc, s + at);
  if (n < 1) n = 1;
  return at + n > len ? len - at : (size_t)n;
}

static int do_replay(const char *dir);
#define ENG_EXTRA_MAIN \
  if (argc >= 3 && !strcmp(argv[1], "replay")) return do_replay(argv[2]);
#include "driver.h"

/* Cross-check against #1's expected results: replays the original
 * calls (onig_search / onig_match, or a vscode scanner as
 * leftmost-first over its members), with the call's match parameters. */
static int do_replay(const char *dir)
{
  FILE *f;
  char *l;
  long ok = 0, bad = 0;
  load(dir);
  compile_all();
  f = open_in(dir, "calls.tsv");
  while ((l = read_line(f))) {
    char kind[16], mp[64];
    static char pids[65536];
    int sid;
    long start, range, er, ef, et;
    long gr, gf = -1, gt = -1;
    OnigMatchParam *mpar = onig_new_match_param();
    onig_initialize_match_param(mpar);
    char *fld[9], *q0 = l;
    int nf;
    for (nf = 0; nf < 9; nf++) { fld[nf] = q0; q0 = strchr(q0, '\t'); if (!q0) { nf++; break; } *q0++ = 0; }
    if (nf != 9) { fprintf(stderr, "bad calls line\n"); continue; }
    snprintf(kind, sizeof kind, "%s", fld[0]); snprintf(pids, sizeof pids, "%s", fld[1]);
    sid = atoi(fld[2]); start = atol(fld[3]); range = atol(fld[4]);
    er = atol(fld[5]); ef = atol(fld[6]); et = atol(fld[7]); snprintf(mp, sizeof mp, "%s", fld[8]);
    if (strcmp(mp, "-")) {
      unsigned long rl, sl;
      sscanf(mp, "%lu,%lu", &rl, &sl);
      onig_set_retry_limit_in_match_of_match_param(mpar, rl);
      onig_set_match_stack_limit_size_of_match_param(mpar, sl);
    }
    subject_t *sb = &subs[sid];
    if (!strcmp(kind, "regset")) {
      /* ONIG_REGSET_POSITION_LEAD: leftmost match, lowest index on ties;
       * -2 when a member does not compile. */
      char *q = pids;
      int idx = 0, best = -1;
      long bs = -1, be = -1;
      gr = -1;
      while (*q) {
        int pid = atoi(q);
        if (status[pid] != ST_OK) { best = -2; break; }
        onig_re *o = (onig_re *)res[pid];
        int r = onig_search_with_param(o->re, sb->s, sb->s + sb->len, sb->s + start, sb->s + range, o->region, ONIG_OPTION_NONE, mpar);
        if (r >= 0 && (best < 0 || r < bs)) { best = idx; bs = o->region->beg[0]; be = o->region->end[0]; }
        q = strchr(q, ',');
        if (!q) break;
        q++; idx++;
      }
      gr = best; if (best >= 0) { gf = bs; gt = be; }
    } else {
      int pid = atoi(pids);
      if (status[pid] != ST_OK) gr = atol(whys[pid]);
      else {
        onig_re *o = (onig_re *)res[pid];
        int r;
        if (!strcmp(kind, "match"))
          r = onig_match_with_param(o->re, sb->s, sb->s + sb->len, sb->s + start, o->region, ONIG_OPTION_NONE, mpar);
        else
          r = onig_search_with_param(o->re, sb->s, sb->s + sb->len, sb->s + start, sb->s + (range < 0 ? (long)sb->len : range), o->region, ONIG_OPTION_NONE, mpar);
        gr = r;
        if (r >= 0) { gf = o->region->beg[0]; gt = o->region->end[0]; }
      }
    }
    onig_free_match_param(mpar);
    /* #1 records no region for onig_match calls: compare the result only. */
    if (gr == er && (!strcmp(kind, "match") || (gf == ef && gt == et))) ok++;
    else { bad++; printf("DIFF\t%s\t%s\t%d\t%ld\texpected %ld %ld-%ld\tgot %ld %ld-%ld\n", kind, pids, sid, start, er, ef, et, gr, gf, gt); }
  }
  printf("REPLAY\tagree=%ld\tdiffer=%ld\n", ok, bad);
  return 0;
}
