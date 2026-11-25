#!/usr/bin/env python3
"""Experiment #6 milestone 2: turn a prover driver's encoded verdicts
(one line per case, in the order of ids.txt: "0", "2" or
"1 s e [1 s e | 0]...") into stack G's verdict format (id TAB MATCH ...).

  python3 -I decode2.py IDS.txt VERDICTS.txt > TOOL.txt"""
import sys
ids = [l.strip() for l in open(sys.argv[1])]
for cid, l in zip(ids, open(sys.argv[2])):
    v = [int(x) for x in l.split()]
    if v[0] == 0:
        print(f"{cid}\tMISMATCH"); continue
    if v[0] == 2:
        print(f"{cid}\tLIMIT"); continue
    out, i = [v[1], v[2]], 3
    while i < len(v):
        if v[i] == 1:
            out += [v[i + 1], v[i + 2]]; i += 3
        else:
            out += [-1, -1]; i += 1
    print(f"{cid}\tMATCH " + " ".join(map(str, out)))
