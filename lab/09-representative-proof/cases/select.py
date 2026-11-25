#!/usr/bin/env python3
r"""Experiment #9: select the fragment's cases.

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
   accepted.  A case accepted in context that is not in in.tsv at all (a
   pure ASCII literal written with an escape experiment #6's parser does
   not read: \cX, \C-X, \o{...}, \uHHHH, several code points in \x{...})
   is added to fragment.tsv with the recogniser's AST and the
   extraction's columns; one that is in in.tsv but was dropped there is a
   re-check failure.  Cases with fragment syntax outside the context are
   counted per reason (informational).

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
OCT = set(b"01234567")


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
            if e in b"xo" and i + 2 < len(p) and p[i + 2] == 0x7b:
                # \x{H ...}, \o{O ...}: one or more code points separated
                # by spaces or newlines, at most 8 hex / 11 octal digits
                # each, optional separators before the brace
                # (upstream/src/regparse.c:5855-5903, :3723-3738,
                # :3811-3859)
                digits, width, base = (HEX, 8, 16) if e == 0x78 else (OCT, 11, 8)
                j = i + 3
                vs = []
                while True:
                    k = j
                    while j < len(p) and p[j] in digits:
                        j += 1
                    if j == k or j - k > width:
                        raise Out(f"malformed \\{chr(e)}{{}}")
                    vs.append(int(p[k:j], base))
                    if j < len(p) and p[j] == 0x7d:
                        break
                    if j >= len(p) or p[j] not in b" \n":
                        raise Out(f"malformed \\{chr(e)}{{}}")
                    while j < len(p) and p[j] in b" \n":
                        j += 1
                    if j < len(p) and p[j] == 0x7d:
                        break
                i = j + 1
                if any(v >= 0x80 for v in vs):
                    raise Out(f"\\{chr(e)}{{}} >= 0x80")
                if len(vs) == 1:
                    return ("L", (vs[0],))
                return ("SEQ", [("L", (v,)) for v in vs])
            if e == 0x78:  # \xHH, at most 2 digits
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
            if e == 0x75:  # \uHHHH, exactly 4 digits (regparse.c:5917-5927)
                h = p[i + 2:i + 6]
                if len(h) != 4 or any(b not in HEX for b in h):
                    raise Out("malformed \\u")
                v = int(h, 16)
                if v >= 0x80:
                    raise Out("\\u >= 0x80")
                i += 6
                return ("L", (v,))
            if e == 0x63 or (e == 0x43 and p[i + 2:i + 3] == b"-"):
                # \cX, \C-X: X & 0x9f, X = ? gives 0x7f; X may be an
                # escaped non-alphanumeric ASCII character, read as itself
                # (regparse.c:4772-4801)
                j = i + 2 if e == 0x63 else i + 3
                if j >= len(p):
                    raise Out("malformed control escape")
                x = p[j]
                if x == 0x5c:
                    if j + 1 >= len(p) or p[j + 1] >= 0x80 or chr(p[j + 1]).isalnum():
                        raise Out("control escape over an escape")
                    j += 1
                    x = p[j]
                elif x >= 0x80:
                    raise Out("non-ASCII control escape")
                i = j + 1
                return ("L", (0x7f if x == 0x3f else x & 0x9f,))
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
            a = atom()
            if a[0] == "SEQ":  # several literals; a quantifier is left out
                if i < len(p) and p[i] in b"*+?{":
                    raise Out("quantifier after a code point sequence")
                items.extend(a[1])
            else:
                items.append(a)
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
    frag = {f[1]: f for f, _ in kept}
    inids = {f[1] for f in rows}
    added = []

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
        if cid not in frag and cid not in inids and row[2] != "e" \
                and drop_reason(sexp(ast)) is None:
            # outside experiment #6's subset: add with the recogniser's AST
            f = [str(allrows.index(row)), cid, row[2], row[7], row[8],
                 row[9], row[10], row[11], str(ncap), sexp(ast)]
            added.append(f)
            frag[cid] = f
        elif cid not in frag:
            problems.append(f"{cid}: fragment syntax in context, not in fragment.tsv")
        elif sexp(ast) != frag[cid][9] or ncap != int(frag[cid][8]):
            problems.append(f"{cid}: AST differs: {sexp(ast)} vs {frag[cid][9]}")
    for cid in frag:
        if cid not in syn_ok:
            problems.append(f"{cid}: in fragment.tsv, not recognised in context")

    with open(f"{out}/fragment.tsv", "w") as o:
        for f in sorted(frag.values(), key=lambda f: int(f[0])):
            o.write("\t".join(f) + "\n")

    kc = Counter(f[2] for f, _ in kept)
    ka = Counter(f[2] for f in added)
    dc = Counter(r for _, r in dropped)
    dk = Counter((r, f[2]) for f, r in dropped)
    se = sorted(c for c, (k, _) in syn_ok.items() if k == "e")
    lines = ["# Experiment #9: fragment cases (written by cases/select.py)", "",
             f"Input: {len(rows)} in-subset cases of experiment #6.", "",
             "| | x2 | x3 | n | e | total |", "|---|---:|---:|---:|---:|---:|",
             "| fragment, from in.tsv | " + " | ".join(str(kc[k]) for k in KINDS) + f" | {len(kept)} |",
             "| fragment, added from the full extraction (not in in.tsv) | "
             + " | ".join(str(ka[k]) for k in KINDS) + f" | {len(added)} |",
             "| **fragment, total** | " + " | ".join(str(kc[k] + ka[k]) for k in KINDS)
             + f" | **{len(kept) + len(added)}** |"]
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
    lines += ["", "Added from the full extraction (pure ASCII literals written with escapes "
              "experiment #6's parser does not read):", ""]
    lines += [f"- {f[1]}: `{bytes.fromhex(f[3]).decode('ascii').replace(chr(10), '<newline>')}` -> `{f[9]}`" for f in added]
    if problems:
        lines += ["", "Problems:", ""] + ["- " + p for p in problems]
    open(f"{out}/counts.md", "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
