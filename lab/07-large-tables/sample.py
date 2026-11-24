#!/usr/bin/env python3
"""Experiment #7 query sample and comparison.

sample.py gen <table.json> <outdir>
  writes queries.txt ("ctype codepoint" per line, decimal) and names.txt
  (one property name per line), and expected.txt from the parsed table.
sample.py compare <expected> <answers> [<n>]
  compares two answer files line by line, prints mismatches (max 20) and
  a summary line; exit status 1 on any mismatch.
"""
import json, os, sys

def gen(tj, out):
    t = json.load(open(tj))
    q = []
    for ct, a in enumerate(t["code_ranges"]):
        pts = set()
        for lo, hi in t["arrays"][a]:
            for c in (lo - 1, lo, hi, hi + 1):
                if 0 <= c <= 0x10FFFF:
                    pts.add(c)
        q += [(ct, c) for c in sorted(pts)]
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "queries.txt"), "w") as f:
        f.write("".join("%d %d\n" % x for x in q))
    with open(os.path.join(out, "names.txt"), "w") as f:
        f.write("".join(n + "\n" for n, _ in t["names"]))
    def mem(rs, c):
        return any(lo <= c <= hi for lo, hi in rs)
    with open(os.path.join(out, "expected.txt"), "w") as f:
        f.write("".join("%d\n" % mem(t["arrays"][t["code_ranges"][ct]], c) for ct, c in q))
        f.write("".join("%d\n" % c for _, c in t["names"]))
    print("queries %d names %d" % (len(q), len(t["names"])))

def compare(e, a, n=None):
    E = open(e).read().split("\n")
    A = open(a).read().split("\n")
    if n is not None:  # targets without name lookup: first n lines (the ctype queries) only
        E = E[:int(n)] + [""]
        print("comparing the %s ctype queries only (no name lookup in this target)" % n)
    bad = [(i + 1, x, y) for i, (x, y) in enumerate(zip(E, A)) if x != y]
    if len(E) != len(A):
        bad.append(("length", len(E), len(A)))
    for b in bad[:20]:
        print("mismatch line %s: expected %r got %r" % b)
    print("compared %d lines, %d mismatches" % (len(E) - 1, len(bad)))
    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    {"gen": gen, "compare": compare}[sys.argv[1]](*sys.argv[2:])
