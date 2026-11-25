#!/usr/bin/env python3
"""Experiment #9: select the fragment's cases.

1. Filter experiment #6's in-subset cases (in.tsv: index id kind pat_hex
   sub_hex a b c ncap ast) down to the fragment of FRAGMENT.md: the AST
   uses only E (empty), single-byte ASCII literals, concatenation,
   alternation, greedy star and capture groups.  Each dropped case gets
   the first reason met.  Output: fragment.tsv (same columns as in.tsv).
2. Re-check against the full extraction (experiment #6's
   cases/extract.py, all seven suites, 4,565 cases): an independent
   recogniser of fragment syntax (below) is run on every pattern; every
   case it accepts under the fragment's context (UTF-8,
   ONIG_SYNTAX_ONIGURUMA, no options, forward search) must be in
   fragment.tsv with the same AST, and every case of fragment.tsv must be
   accepted.  Cases with fragment syntax outside the context are counted
   per reason (informational).

usage: python3 -I select.py IN.tsv ALL.tsv OUTDIR
writes OUTDIR/fragment.tsv and OUTDIR/counts.md; exits non-zero if the
re-check fails.

Upstream test cases are taken from Oniguruma f95747b's upstream/test/*.c:
Copyright (c) 2002-2025 K.Kosako, BSD-2-Clause (see upstream/COPYING).
"""
import sys
from collections import Counter

KINDS = ("x2", "x3", "n", "e")


# ---- in.tsv's s-expressions -----------------------------------------

def parse_sexp(s):
    toks = s.replace("(", " ( ").replace(")", " ) ").split()
    pos = 0

    def go():
        nonlocal pos
        t = toks[pos]; pos += 1
        if t == "(":
            op = toks[pos]; pos += 1
            args = []
            while toks[pos] != ")":
                if op == "g" and not args:
                    args.append(int(toks[pos])); pos += 1
                else:
                    args.append(go())
            pos += 1
            return (op, *args)
        if t == "E":
            return ("E",)
        if t[0] == "L":
            h = t[1:]
            return ("L", tuple(int(h[i:i + 2], 16) for i in range(0, len(h), 2)))
        if t[0] == "C":
            return ("C",)
        raise ValueError(t)
    return go()


def drop_reason(ast_text):
    """First reason the AST is outside the fragment, or None."""
    if ast_text == "!":
        return "compile error (kind e: no AST, the fragment has no parser)"
    reasons = []

    def walk(n):
        op = n[0]
        if op == "C":
            reasons.append("character class or anychar")
        elif op == "L" and (len(n[1]) != 1 or n[1][0] >= 0x80):
            reasons.append("multibyte literal")
        elif op in (".", "|"):
            walk(n[1]); walk(n[2])
        elif op == "*":
            walk(n[1])
        elif op == "g":
            walk(n[2])
    walk(parse_sexp(ast_text))
    return reasons[0] if reasons else None


def sexp(n):
    op = n[0]
    if op == "E": return "E"
    if op == "L": return "L" + "".join(f"{b:02x}" for b in n[1])
    if op == "g": return f"(g {n[1]} {sexp(n[2])})"
    if op == "*": return f"(* {sexp(n[1])})"
    return f"({op} {sexp(n[1])} {sexp(n[2])})"


# ---- independent recogniser of fragment syntax ----------------------

META = set(b"\\()|*+?{}[].^$")
HEX = set(b"0123456789abcdefABCDEF")


class Out(Exception):
    pass


def recognise(p):
    """Parse pattern bytes p as fragment syntax (Oniguruma syntax).
    Returns (ast, ncap); raises Out(reason) when p is outside it, with
    'syntax error' for a quantifier with no target."""
    i = 0
    ncap = 0

    def atom():
        nonlocal i, ncap
        c = p[i]
        if c == 0x28:  # (
            if i + 1 < len(p) and p[i + 1] == 0x3f:
                raise Out("(? group")
            if i + 1 < len(p) and p[i + 1] == 0x2a:
                raise Out("(* verb")
            i += 1
            ncap += 1
            k = ncap
            body = alt()
            if i >= len(p) or p[i] != 0x29:
                raise Out("unbalanced parenthesis")
            i += 1
            return ("g", k, body)
        if c == 0x5c:  # backslash
            if i + 1 >= len(p):
                raise Out("trailing backslash")
            e = p[i + 1]
            if e in META or e in b"/-&<>":
                i += 2
                return ("L", (e,))
            if e == 0x78:  # x
                if i + 2 < len(p) and p[i + 2] == 0x7b:
                    j = i + 3
                    while j < len(p) and p[j] in HEX:
                        j += 1
                    if j == i + 3 or j >= len(p) or p[j] != 0x7d:
                        raise Out("malformed \\x{}")
                    v = int(p[i + 3:j], 16)
                    i = j + 1
                else:
                    j = i + 2
                    while j < len(p) and j < i + 4 and p[j] in HEX:
                        j += 1
                    if j == i + 2:
                        raise Out("malformed \\x")
                    v = int(p[i + 2:j], 16)
                    i = j
                if v >= 0x80:
                    raise Out("\\x >= 0x80")
                return ("L", (v,))
            raise Out("escape \\" + chr(e))
        if c >= 0x80:
            raise Out("non-ASCII byte")
        if c in b"+?{":
            raise Out(chr(c))
        if c in b"}]":
            raise Out(chr(c) + " (literal, left out conservatively)")
        if c == 0x5b:
            raise Out("character class")
        if c == 0x2e:
            raise Out("anychar")
        if c in b"^$":
            raise Out("anchor")
        i += 1
        return ("L", (c,))

    def cat():
        nonlocal i
        items = []
        while i < len(p) and p[i] not in b"|)":
            if p[i] == 0x2a:  # * with no target
                if not items:
                    raise Out("syntax error")
                if items[-1][0] == "*":
                    raise Out("nested quantifier **")
                items[-1] = ("*", items[-1])
                i += 1
                continue
            items.append(atom())
        if not items:
            return ("E",)
        r = items[-1]
        for x in reversed(items[:-1]):
            r = (".", x, r)
        return r

    def alt():
        nonlocal i
        a = cat()
        if i < len(p) and p[i] == 0x7c:
            i += 1
            return ("|", a, alt())
        return a

    ast = alt()
    if i != len(p):
        raise Out("unbalanced parenthesis")
    return ast, ncap


def context_reason(row):
    suite, _, kind, enc, syn, opt, d = row[:7]
    if suite == "test_regset":
        return "regset API"
    if d != "fwd":
        return "backward search"
    if enc != "UTF8":
        return "encoding " + enc
    if syn != "ONIGURUMA":
        return "syntax " + syn
    if int(opt) != 0:
        return "options"
    return None


def main():
    inf, allf, out = sys.argv[1:4]
    rows = [l.rstrip("\n").split("\t") for l in open(inf)]
    kept, dropped = [], []
    for f in rows:
        r = drop_reason(f[9])
        (dropped if r else kept).append((f, r))
    with open(f"{out}/fragment.tsv", "w") as o:
        for f, _ in kept:
            o.write("\t".join(f) + "\n")
    frag = {f[1]: f for f, _ in kept}

    # re-check against the full extraction
    allrows = [l.rstrip("\n").split("\t") for l in open(allf)]
    problems = []
    syn_ok = {}
    ctx_out = Counter()
    for row in allrows:
        cid = f"{row[0]}:{row[1]}"
        if row[0] == "test_regset":
            continue
        pat = bytes.fromhex(row[7])
        try:
            ast, ncap = recognise(pat)
        except Out as e:
            if cid in frag and str(e) != "syntax error":
                problems.append(f"{cid}: in fragment.tsv, recogniser says {e}")
            if str(e) == "syntax error" and context_reason(row) is None:
                syn_ok[cid] = ("e", None)
            continue
        cr = context_reason(row)
        if cr:
            ctx_out[cr] += 1
            continue
        syn_ok[cid] = (row[2], (ast, ncap))
        if cid not in frag:
            problems.append(f"{cid}: fragment syntax in context, not in fragment.tsv")
        elif sexp(ast) != frag[cid][9] or ncap != int(frag[cid][8]):
            problems.append(f"{cid}: AST differs: {sexp(ast)} vs {frag[cid][9]}")
    for cid in frag:
        if cid not in syn_ok:
            problems.append(f"{cid}: in fragment.tsv, not recognised in context")

    kc = Counter(f[2] for f, _ in kept)
    dc = Counter(r for _, r in dropped)
    dk = Counter((r, f[2]) for f, r in dropped)
    se = sorted(c for c, (k, _) in syn_ok.items() if k == "e")
    lines = ["# Experiment #9: fragment cases (written by cases/select.py)", "",
             f"Input: {len(rows)} in-subset cases of experiment #6.", "",
             "| | x2 | x3 | n | e | total |", "|---|---:|---:|---:|---:|---:|",
             "| fragment | " + " | ".join(str(kc[k]) for k in KINDS) + f" | {len(kept)} |"]
    for r, n in dc.most_common():
        lines.append(f"| dropped: {r} | " + " | ".join(str(dk[(r, k)]) for k in KINDS) + f" | {n} |")
    lines += ["", f"Re-check over the full extraction ({len(allrows)} cases): "
              f"{'OK' if not problems else 'FAILED'}; "
              f"fragment syntax in context: {sum(1 for v in syn_ok.values() if v[0] != 'e')}; "
              f"quantifier with no target in context (kind e, dropped above): {', '.join(se)}.", "",
              "Fragment syntax outside the context (informational; the recogniser reads "
              "bytes, so the EUC-JP and UTF-16 counts are byte-level):", "",
              "| Reason | Cases |", "|---|---:|"]
    lines += [f"| {r} | {n} |" for r, n in ctx_out.most_common()]
    if problems:
        lines += ["", "Problems:", ""] + ["- " + p for p in problems]
    open(f"{out}/counts.md", "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
