#!/usr/bin/env python3
"""Experiment #6 milestone 2: agreement of a verdict file with the C
oracle on the S2 cases, per kind (criterion 2).

  python3 -I agree2.py IN-S2.TSV ORACLE.txt TOOL.txt [DEVIATIONS.tsv]

x2: group 0 region equals the C library's (and the expected one);
x3: region of group mem equals the C library's; n: no match; e: the
tool rejects the pattern (code match reported separately).  For a
prover, the e cases that stack G's parser rejects are not emitted and
are counted as "inherited".  A case where
the tool disagrees with the C library and that is listed in
DEVIATIONS.tsv (id TAB DEV-NNN) is counted as "deviation logged".
Prints the counts and one line per disagreement."""
import sys

def load(f):
    d = {}
    for l in open(f):
        k, _, v = l.rstrip("\n").partition("\t")
        d[k] = v
    return d

cases = [l.rstrip("\n").split("\t") for l in open(sys.argv[1])]
orc, tool = load(sys.argv[2]), load(sys.argv[3])
devs = load(sys.argv[4]) if len(sys.argv) > 4 else {}
cnt = {}
bad = []
for c in cases:
    cid, kind, a, b, m = c[1], c[2], c[5], c[6], c[7]
    o, t = orc.get(cid, "?"), tool.get(cid, "?")
    if t == "?" and kind == "e" and orc.get(cid, "").startswith("ERR"):
        # not emitted to the provers: rejected by stack G's parser
        cnt.setdefault(kind, {}).setdefault("inherited", 0)
        cnt[kind]["inherited"] += 1
        continue
    def region(v, g):
        f = v.split()
        if f[0] != "MATCH" or len(f) < 3 + 2 * g:
            return None
        return (f[1 + 2 * g], f[2 + 2 * g])
    if kind == "x2":
        ok = region(t, 0) is not None and region(t, 0) == region(o, 0)
    elif kind == "x3":
        g = int(m)
        ok = region(t, g) is not None and region(t, g) == region(o, g)
    elif kind == "n":
        ok = t == "MISMATCH" and o == "MISMATCH"
    else:
        ok = t.startswith("ERR") and o.startswith("ERR")
    st = "pass" if ok else ("deviation" if cid in devs else "fail")
    cnt.setdefault(kind, {}).setdefault(st, 0)
    cnt[kind][st] += 1
    if kind == "e" and ok and t != o:
        cnt[kind].setdefault("code-differs", 0); cnt[kind]["code-differs"] += 1
    if not ok:
        bad.append((cid, kind, st, devs.get(cid, ""), o, t))
for k in sorted(cnt):
    print(k, sum(v for s, v in cnt[k].items() if s != "code-differs"), cnt[k])
for x in bad:
    print("\t".join(x))
