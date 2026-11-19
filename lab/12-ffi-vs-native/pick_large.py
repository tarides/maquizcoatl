#!/usr/bin/env python3
"""Experiment #12: choose the large-subject patterns.

  python3 -I pick_large.py cand WORKDIR   -> WORKDIR/cand.work, cand.meta
  (then: main.exe largeok SUBJECT cand.work > WORKDIR/largeok.<source>)
  python3 -I pick_large.py pick WORKDIR N -> WORKDIR/large.work, large.list

Candidates: the in-subset triples of the three families (classified work
files), ranked by call count (VS Code weighted by the frequency profile),
ties broken by family then pattern bytes; per source the top N that are
in the subset for that subject and not anchored at the start.
"""
import os, sys
from collections import defaultdict


def read(path):
    P, C = {}, defaultdict(int)
    for l in open(path):
        f = l.split()
        if f[0] == "P":
            P[int(f[1])] = f[2:]
        elif f[0] == "C":
            C[int(f[2])] += int(f[8])
    return P, C


def cand(wd):
    out = open(os.path.join(wd, "cand.work"), "w")
    meta = open(os.path.join(wd, "cand.meta"), "w")
    key = {}
    n = 0
    for fam in ("jq", "php", "vscode"):
        P, C = read(os.path.join(wd, fam + ".work"))
        for pid, (syn, opt, lim, stk, *hx) in P.items():
            hx = hx[0] if hx else ""
            k = (syn, opt, lim, stk, hx)
            if k in key:
                key[k][1] += C[pid]
                continue
            key[k] = [n, C[pid], fam]
            out.write(f"P {n} {syn} {opt} {lim} {stk} {hx}\n")
            n += 1
    for (syn, opt, lim, stk, hx), (gid, calls, fam) in key.items():
        meta.write(f"{gid} {fam} {calls} {hx or '-'}\n")


def pick(wd, n):
    meta = {}
    for l in open(os.path.join(wd, "cand.meta")):
        gid, fam, calls, hx = l.split()
        meta[int(gid)] = (fam, int(calls), "" if hx == "-" else hx)
    P = {}
    for l in open(os.path.join(wd, "cand.work")):
        f = l.split()
        P[int(f[1])] = l
    chosen = set()
    lst = open(os.path.join(wd, "large.list"), "w")
    lst.write("source rank pid family calls pattern_hex\n")
    for src in ("log", "src"):
        ok = {}
        for l in open(os.path.join(wd, "largeok." + src)):
            pid, st = l.split()
            ok[int(pid)] = st
        ranked = sorted((g for g in meta if ok.get(g) == "valid"),
                        key=lambda g: (-meta[g][1], meta[g][0], meta[g][2]))
        for r, g in enumerate(ranked[:n], 1):
            chosen.add(g)
            fam, calls, hx = meta[g]
            lst.write(f"{src} {r} {g} {fam} {calls} {hx or '-'}\n")
    with open(os.path.join(wd, "large.work"), "w") as w:
        for g in sorted(chosen):
            w.write(P[g])


if __name__ == "__main__":
    if sys.argv[1] == "cand":
        cand(sys.argv[2])
    else:
        pick(sys.argv[2], int(sys.argv[3]))
