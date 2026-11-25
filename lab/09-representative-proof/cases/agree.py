#!/usr/bin/env python3
"""Experiment #9: agreement of a tool's VM and semantics with the C library.

Inputs: the case file (fragment.tsv or extra.tsv), the C oracle's
onig_search verdicts (oracle.c: id TAB verdict), the per-start-position
verdicts (oracle_at.c: id TAB p TAB verdict) and the tool driver's output
(id TAB p|search TAB engine TAB verdict).  Cases where the C library hit
the retry limit (LIMIT) are excluded and listed.

Checks, per case:
  expect  the C search verdict against the upstream test's expectation
          (x2: match [a,b); x3: group c spans [a,b); n: no match)
  search  each engine's left-to-right search against C's onig_search
  at      each engine at every start position against C's onig_match

usage: python3 -I agree.py CASES.tsv ORACLE_SEARCH ORACLE_AT TOOL_OUT [LABEL]
Prints a Markdown table and the disagreements; exits non-zero on any.
"""
import sys
from collections import defaultdict


def main():
    cf, osf, oaf, tf = sys.argv[1:5]
    label = sys.argv[5] if len(sys.argv) > 5 else tf
    cases = [l.rstrip("\n").split("\t") for l in open(cf)]
    osr = dict(l.rstrip("\n").split("\t", 1) for l in open(osf))
    oat = {}
    for l in open(oaf):
        i, p, v = l.rstrip("\n").split("\t")
        oat[(i, p)] = v
    tool = {}
    engines = []
    for l in open(tf):
        i, p, e, v = l.rstrip("\n").split("\t")
        tool[(i, p, e)] = v
        if e not in engines:
            engines.append(e)
    excluded = sorted({i for (i, _), v in oat.items() if v == "LIMIT"} |
                      {i for i, v in osr.items() if v == "LIMIT"})
    bad = []
    n_expect = 0
    ok = defaultdict(int)
    tot = defaultdict(int)
    for f in cases:
        cid, kind = f[1], f[2]
        if cid in excluded:
            continue
        a, b, c = int(f[5]), int(f[6]), int(f[7])
        v = osr[cid].split()
        if kind == "n":
            good = v[0] == "MISMATCH"
        elif v[0] != "MATCH":
            good = False
        else:
            nums = list(map(int, v[1:]))
            good = (nums[2 * c], nums[2 * c + 1]) == (a, b)
        n_expect += good
        if not good:
            bad.append(f"{cid}: C {osr[cid]} vs test expectation {kind} {a} {b} {c}")
        nsub = len(f[4]) // 2
        for e in engines:
            tot[(e, "search")] += 1
            t = tool.get((cid, "search", e))
            if t == osr[cid]:
                ok[(e, "search")] += 1
            else:
                bad.append(f"{cid} search {e}: {t} vs C {osr[cid]}")
            for p in range(nsub + 1):
                tot[(e, "at")] += 1
                t = tool.get((cid, str(p), e))
                if t == oat[(cid, str(p))]:
                    ok[(e, "at")] += 1
                else:
                    bad.append(f"{cid} p={p} {e}: {t} vs C {oat[(cid, str(p))]}")
    ncases = len(cases) - len(excluded)
    print(f"### {label}\n")
    print(f"Cases: {len(cases)}, excluded (C retry limit): {len(excluded)}"
          + (f" ({', '.join(excluded)})" if excluded else "")
          + f"; C search agrees with the upstream expectation on {n_expect}/{ncases}.\n")
    print("| Engine | search = C onig_search | every start position = C onig_match |")
    print("|---|---:|---:|")
    for e in engines:
        print(f"| {e} | {ok[(e, 'search')]}/{tot[(e, 'search')]} | {ok[(e, 'at')]}/{tot[(e, 'at')]} |")
    if bad:
        print("\nDisagreements:\n")
        for x in bad:
            print("- " + x)
    print()
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
