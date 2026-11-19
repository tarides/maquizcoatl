/* classify.c -- maquizcoatl experiment #1: compile and classify triples.
 *
 * Input (stdin), one triple per line, tab-separated:
 *   id  syntax  options(decimal)  encoding  pattern(hex)
 * Output (stdout), one line per triple, tab-separated:
 *   id  status  code  <15 feature columns>  message
 * status is ok | error | crash | timeout.
 *
 * Build modes:
 *   -DSTOCK  link against the stock libonig: only onig_new is called and
 *            the feature columns are printed as "-".
 *   default  link against the instrumented static library (see
 *            instrument.patch) and its internal headers: counters plus a
 *            walk of the tree returned by onig_parse_tree.
 *
 * Each triple is processed in a forked child with a 10 s alarm, so a crash
 * or hang in the library is recorded instead of stopping the run.
 *
 * Uses Oniguruma's internal headers (Copyright (c) 2002-2021 K.Kosako,
 * BSD-2-Clause); this file itself only calls into them.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/mman.h>

#ifdef STOCK
#include "oniguruma.h"
#else
#include "regint.h"
#include "regparse.h"
#endif

static OnigSyntaxType* syntax_of(const char* s) {
  struct { const char* n; OnigSyntaxType* s; } t[] = {
    {"ONIGURUMA", ONIG_SYNTAX_ONIGURUMA}, {"RUBY", ONIG_SYNTAX_RUBY},
    {"PERL_NG", ONIG_SYNTAX_PERL_NG}, {"PERL", ONIG_SYNTAX_PERL},
    {"JAVA", ONIG_SYNTAX_JAVA}, {"PYTHON", ONIG_SYNTAX_PYTHON},
    {"GNU_REGEX", ONIG_SYNTAX_GNU_REGEX}, {"GREP", ONIG_SYNTAX_GREP},
    {"EMACS", ONIG_SYNTAX_EMACS}, {"POSIX_BASIC", ONIG_SYNTAX_POSIX_BASIC},
    {"POSIX_EXTENDED", ONIG_SYNTAX_POSIX_EXTENDED}, {"ASIS", ONIG_SYNTAX_ASIS},
  };
  for (size_t i = 0; i < sizeof t / sizeof t[0]; i++)
    if (strcmp(t[i].n, s) == 0) return t[i].s;
  return NULL;
}

static OnigEncoding encoding_of(const char* s) {
  struct { const char* n; OnigEncoding e; } t[] = {
    {"US-ASCII", ONIG_ENCODING_ASCII}, {"UTF-8", ONIG_ENCODING_UTF8},
    {"UTF-16BE", ONIG_ENCODING_UTF16_BE}, {"UTF-16LE", ONIG_ENCODING_UTF16_LE},
    {"UTF-32BE", ONIG_ENCODING_UTF32_BE}, {"UTF-32LE", ONIG_ENCODING_UTF32_LE},
    {"ISO-8859-1", ONIG_ENCODING_ISO_8859_1}, {"ISO-8859-2", ONIG_ENCODING_ISO_8859_2},
    {"ISO-8859-3", ONIG_ENCODING_ISO_8859_3}, {"ISO-8859-4", ONIG_ENCODING_ISO_8859_4},
    {"ISO-8859-5", ONIG_ENCODING_ISO_8859_5}, {"ISO-8859-6", ONIG_ENCODING_ISO_8859_6},
    {"ISO-8859-7", ONIG_ENCODING_ISO_8859_7}, {"ISO-8859-8", ONIG_ENCODING_ISO_8859_8},
    {"ISO-8859-9", ONIG_ENCODING_ISO_8859_9}, {"ISO-8859-10", ONIG_ENCODING_ISO_8859_10},
    {"ISO-8859-11", ONIG_ENCODING_ISO_8859_11}, {"ISO-8859-13", ONIG_ENCODING_ISO_8859_13},
    {"ISO-8859-14", ONIG_ENCODING_ISO_8859_14}, {"ISO-8859-15", ONIG_ENCODING_ISO_8859_15},
    {"ISO-8859-16", ONIG_ENCODING_ISO_8859_16}, {"EUC-JP", ONIG_ENCODING_EUC_JP},
    {"EUC-TW", ONIG_ENCODING_EUC_TW}, {"EUC-KR", ONIG_ENCODING_EUC_KR},
    {"EUC-CN", ONIG_ENCODING_EUC_CN}, {"Shift_JIS", ONIG_ENCODING_SJIS},
    {"KOI8-R", ONIG_ENCODING_KOI8_R}, {"CP1251", ONIG_ENCODING_CP1251},
    {"Big5", ONIG_ENCODING_BIG5}, {"GB18030", ONIG_ENCODING_GB18030},
  };
  for (size_t i = 0; i < sizeof t / sizeof t[0]; i++)
    if (strcmp(t[i].n, s) == 0) return t[i].e;
  return NULL;
}

enum { F_CAPTURES, F_NAMED, F_BACKREF, F_LOOKAHEAD, F_LOOKBEHIND, F_ATOMIC,
       F_POSSESSIVE, F_BOUNDED, F_CALL, F_ABSENT, F_COND, F_CALLOUT, F_PROP,
       F_CI, F_MCFOLD, F_N };

/* Shared with the parent across fork. */
struct result { int status; int code; int f[F_N]; char msg[ONIG_MAX_ERROR_MESSAGE_LEN]; };

#ifndef STOCK
struct walk { int f[F_N]; int named_groups; int capture_only_named; };

static void walk(Node* node, struct walk* w) {
  while (node != NULL) {
    switch (ND_TYPE(node)) {
    case ND_LIST: case ND_ALT:
      walk(ND_CAR(node), w);
      node = ND_CDR(node);
      continue;
    case ND_BACKREF:
      /* The condition of (?(<name>)...) is a checker backref, not a match. */
      if (! ND_IS_CHECKER(node)) w->f[F_BACKREF] = 1;
      return;
    case ND_CALL: w->f[F_CALL] = 1; return;
    case ND_QUANT: node = ND_BODY(node); continue;
    case ND_ANCHOR: {
      int t = ANCHOR_(node)->type;
      if (t == ANCR_PREC_READ || t == ANCR_PREC_READ_NOT) w->f[F_LOOKAHEAD] = 1;
      if (t == ANCR_LOOK_BEHIND || t == ANCR_LOOK_BEHIND_NOT) w->f[F_LOOKBEHIND] = 1;
      if (ANCHOR_HAS_BODY(ANCHOR_(node))) { node = ND_BODY(node); continue; }
      return;
    }
    case ND_GIMMICK:
#ifdef USE_CALLOUT
      if (GIMMICK_(node)->type == GIMMICK_CALLOUT) w->f[F_CALLOUT] = 1;
#endif
      return;
    case ND_BAG: {
      BagNode* b = BAG_(node);
      switch (b->type) {
      case BAG_MEMORY:
        if (ND_IS_NAMED_GROUP(node)) { w->f[F_NAMED] = 1; w->f[F_CAPTURES] = 1; }
        else if (! w->capture_only_named) w->f[F_CAPTURES] = 1;
        break;
      case BAG_OPTION:
        if ((b->o.options & ONIG_OPTION_IGNORECASE) != 0) w->f[F_CI] = 1;
        break;
      case BAG_IF_ELSE:
        w->f[F_COND] = 1;
        walk(b->te.Then, w);
        walk(b->te.Else, w);
        break;
      default: break;
      }
      node = ND_BODY(node);
      continue;
    }
    default: return;
    }
  }
}
#endif

static void child(struct result* res, const UChar* pat, size_t len,
                  OnigOptionType opt, OnigEncoding enc, OnigSyntaxType* syn) {
  regex_t* reg;
  OnigErrorInfo einfo;
#ifndef STOCK
  onig_instr_possessive = onig_instr_bounded = onig_instr_property = 0;
  onig_instr_atomic = onig_instr_absent = onig_instr_mcfold = 0;
#endif
  int r = onig_new(&reg, pat, pat + len, opt, enc, syn, &einfo);
  res->code = r;
  if (r != ONIG_NORMAL) {
    onig_error_code_to_str((UChar*)res->msg, r, &einfo);
    res->status = 1;
    return;
  }
  res->status = 0;
#ifndef STOCK
  res->f[F_POSSESSIVE] = onig_instr_possessive > 0;
  res->f[F_BOUNDED] = onig_instr_bounded > 0;
  res->f[F_PROP] = onig_instr_property > 0;
  res->f[F_ATOMIC] = onig_instr_atomic > 0;
  res->f[F_ABSENT] = onig_instr_absent > 0;
  res->f[F_MCFOLD] = onig_instr_mcfold > 0;
  int nnamed = onig_number_of_names(reg);
  onig_free(reg);

  /* Second pass: the parser's tree, before reduce_string_list/tune_tree. */
  regex_t sreg;
  ParseEnv env;
  Node* root = NULL;
  memset(&sreg, 0, sizeof sreg);
  r = onig_reg_init(&sreg, opt, ONIGENC_CASE_FOLD_DEFAULT, enc, syn);
  if (r != 0) { res->status = 3; res->code = r; return; }
  memset(&env, 0, sizeof env);
  r = onig_parse_tree(&root, pat, pat + len, &sreg, &env);
  if (r != 0) { res->status = 3; res->code = r; return; }
  struct walk w;
  memset(&w, 0, sizeof w);
  w.capture_only_named = nnamed > 0
    && IS_SYNTAX_BV(syn, ONIG_SYN_CAPTURE_ONLY_NAMED_GROUP)
    && (opt & ONIG_OPTION_CAPTURE_GROUP) == 0;
  walk(root, &w);
  for (int i = 0; i < F_N; i++)
    if (i != F_POSSESSIVE && i != F_BOUNDED && i != F_PROP && i != F_ATOMIC
        && i != F_ABSENT && i != F_MCFOLD)
      res->f[i] = w.f[i];
  if ((opt & ONIG_OPTION_IGNORECASE) != 0) res->f[F_CI] = 1;
  onig_node_free(root);
  onig_free_body(&sreg);
#else
  onig_free(reg);
#endif
}

static int hexval(int c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  return -1;
}

int main(void) {
  OnigEncoding all[] = { ONIG_ENCODING_UTF8 };
  onig_initialize(all, 1);
  struct result* res = mmap(NULL, sizeof *res, PROT_READ | PROT_WRITE,
                            MAP_SHARED | MAP_ANONYMOUS, -1, 0);
  static char line[1 << 20];
  static UChar pat[1 << 19];
  while (fgets(line, sizeof line, stdin)) {
    line[strcspn(line, "\n")] = 0;
    char* id = strtok(line, "\t");
    char* syn = strtok(NULL, "\t");
    char* opt = strtok(NULL, "\t");
    char* enc = strtok(NULL, "\t");
    char* hex = strtok(NULL, "\t");
    if (hex == NULL) hex = "";
    if (!id || !syn || !opt || !enc) continue;
    size_t len = 0;
    for (char* h = hex; h[0] && h[1]; h += 2) pat[len++] = hexval(h[0]) * 16 + hexval(h[1]);
    OnigSyntaxType* s = syntax_of(syn);
    OnigEncoding e = encoding_of(enc);
    if (!s || !e) { printf("%s\tbad-input\t0\n", id); continue; }
    onig_initialize(&e, 1);
    memset(res, 0, sizeof *res);
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
      alarm(10);
      child(res, pat, len, (OnigOptionType)strtoul(opt, NULL, 10), e, s);
      _exit(0);
    }
    int st;
    waitpid(pid, &st, 0);
    const char* status;
    if (WIFSIGNALED(st)) status = WTERMSIG(st) == SIGALRM ? "timeout" : "crash";
    else if (res->status == 0) status = "ok";
    else if (res->status == 3) status = "parse-tree-error";
    else status = "error";
    printf("%s\t%s\t%d", id, status, WIFSIGNALED(st) ? WTERMSIG(st) : res->code);
    for (int i = 0; i < F_N; i++) {
#ifdef STOCK
      printf("\t-");
#else
      printf("\t%d", res->f[i]);
#endif
    }
    printf("\t%s\n", res->msg);
  }
  return 0;
}
