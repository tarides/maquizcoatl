#!/usr/bin/env python3
# Apply the experiment #1 instrumentation edits to a copy of Oniguruma's
# src/ directory (upstream f95747b).  Usage: make_instrument_patch.py SRC_DIR
#
# The edited files are derivatives of Oniguruma, Copyright (c) 2002-2021
# K.Kosako, distributed under the BSD-2-Clause licence (see COPYING in the
# upstream tree).  The edits only add counters; they do not change parsing.
import sys, pathlib

src = pathlib.Path(sys.argv[1])

def edit(name, pairs):
    p = src / name
    t = p.read_text()
    for old, new in pairs:
        if t.count(old) != 1:
            sys.exit(f"{name}: anchor found {t.count(old)} times: {old[:60]!r}")
        t = t.replace(old, new)
    p.write_text(t)

HDR = """
/* maquizcoatl experiment #1 instrumentation: per-pattern counters.
   Reset by the caller before onig_new / onig_parse_tree. */
extern int onig_instr_possessive;  /* TK_REPEAT/TK_INTERVAL, possessive */
extern int onig_instr_bounded;     /* TK_INTERVAL with finite upper bound */
extern int onig_instr_property;    /* TK_CHAR_PROPERTY (\\p, \\P) */
extern int onig_instr_atomic;      /* (?> opener in prs_bag */
extern int onig_instr_absent;      /* (?~ opener in prs_bag */
extern int onig_instr_mcfold;      /* a multi-code-point fold was applied */
"""

edit("regparse.h", [(
    "extern void   onig_node_free P_((Node* node));\n",
    "extern void   onig_node_free P_((Node* node));\n" + HDR)])

edit("regparse.c", [
    ('#include "st.h"\n',
     '#include "st.h"\n\n'
     'int onig_instr_possessive, onig_instr_bounded, onig_instr_property,\n'
     '    onig_instr_atomic, onig_instr_absent, onig_instr_mcfold;\n'),
    # fetch_token_cc: rename the definition, add a counting wrapper.
    ("static int\nfetch_token_cc(PToken* tok, UChar** src, UChar* end, ParseEnv* env, int state)\n{",
     "static int fetch_token_cc_raw(PToken* tok, UChar** src, UChar* end, ParseEnv* env, int state);\n"
     "static void instr_token(int r, PToken* tok);\n"
     "static int\nfetch_token_cc(PToken* tok, UChar** src, UChar* end, ParseEnv* env, int state)\n"
     "{\n  int r = fetch_token_cc_raw(tok, src, end, env, state);\n  instr_token(r, tok);\n  return r;\n}\n\n"
     "static int\nfetch_token_cc_raw(PToken* tok, UChar** src, UChar* end, ParseEnv* env, int state)\n{"),
    ("static int\nfetch_token(PToken* tok, UChar** src, UChar* end, ParseEnv* env)\n{",
     "static int fetch_token_raw(PToken* tok, UChar** src, UChar* end, ParseEnv* env);\n"
     "static void\ninstr_token(int r, PToken* tok)\n{\n"
     "  if (r == TK_CHAR_PROPERTY) onig_instr_property++;\n"
     "  if ((r == TK_REPEAT || r == TK_INTERVAL) && tok->u.repeat.possessive != 0)\n"
     "    onig_instr_possessive++;\n"
     "  if (r == TK_INTERVAL && ! IS_INFINITE_REPEAT(tok->u.repeat.upper))\n"
     "    onig_instr_bounded++;\n}\n\n"
     "static int\nfetch_token(PToken* tok, UChar** src, UChar* end, ParseEnv* env)\n"
     "{\n  int r = fetch_token_raw(tok, src, end, env);\n  instr_token(r, tok);\n  return r;\n}\n\n"
     "static int\nfetch_token_raw(PToken* tok, UChar** src, UChar* end, ParseEnv* env)\n{"),
    ("    case '>':            /* (?>...) stop backtrack */\n      *np = node_new_bag(BAG_STOP_BACKTRACK);",
     "    case '>':            /* (?>...) stop backtrack */\n      onig_instr_atomic++;\n      *np = node_new_bag(BAG_STOP_BACKTRACK);"),
    ("        int head_bar;\n        int is_range_cutter;\n\n        if (PEND) return ONIGERR_END_PATTERN_IN_GROUP;",
     "        int head_bar;\n        int is_range_cutter;\n\n        onig_instr_absent++;\n        if (PEND) return ONIGERR_END_PATTERN_IN_GROUP;"),
    ("      int n, j, m, index;\n      Node* list_node;\n      Node* ns[3];\n",
     "      int n, j, m, index;\n      Node* list_node;\n      Node* ns[3];\n\n"
     "      if ((env->case_fold_flag & INTERNAL_ONIGENC_CASE_FOLD_MULTI_CHAR) != 0)\n"
     "        onig_instr_mcfold = 1;\n"),
])

edit("regcomp.c", [(
    "    one_len = (OnigLen )enclen(enc, p);\n    if (n == 0) {\n      q = p + one_len;\n      if (q > end) q = end;\n      r = unravel_cf_string_add(&list, &sn, p, q, 0 /* flag */);",
    "    one_len = (OnigLen )enclen(enc, p);\n"
    "    if ((reg->case_fold_flag & INTERNAL_ONIGENC_CASE_FOLD_MULTI_CHAR) != 0) {\n"
    "      int k;\n      for (k = 0; k < n; k++)\n"
    "        if (items[k].code_len > 1 || items[k].byte_len != (int )one_len)\n"
    "          onig_instr_mcfold = 1;\n    }\n"
    "    if (n == 0) {\n      q = p + one_len;\n      if (q > end) q = end;\n      r = unravel_cf_string_add(&list, &sn, p, q, 0 /* flag */);")])
print("ok")
