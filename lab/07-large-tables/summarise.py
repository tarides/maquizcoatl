#!/usr/bin/env python3
"""Experiment #7: summarise times.tsv files (label, run, status, wall, rss KB, load).

summarise.py <times.tsv>...  prints, per label, the runs' wall-clock seconds,
the median, the median peak RSS in MB, the exit statuses and the load range.
"""
import statistics, sys
from collections import defaultdict

def secs(w):
    if not w:
        return None
    p = [float(x) for x in w.split(":")]
    return p[0] * 3600 + p[1] * 60 + p[2] if len(p) == 3 else p[0] * 60 + p[1]

rows = defaultdict(list)
order = []
for f in sys.argv[1:]:
    tool = f.split("/")[-2]
    for line in open(f):
        lab, run, st, wall, rss, load = (line.rstrip("\n").split("\t") + [""] * 6)[:6]
        k = (tool, lab)
        if k not in rows:
            order.append(k)
        rows[k].append((run, int(st), secs(wall), int(rss) // 1024 if rss else None, load.split(" ")[0]))
print("| tool | step | runs | wall-clock s (each) | median s | median peak RSS MB | status | load (1 min) |")
print("|---|---|---|---|---|---|---|---|")
for k in order:
    r = rows[k]
    w = [x[2] for x in r if x[2] is not None]
    m = [x[3] for x in r if x[3] is not None]
    print("| %s | %s | %d | %s | %s | %s | %s | %s |" % (
        k[0], k[1], len(r), ", ".join("%.2f" % x for x in w),
        "%.2f" % statistics.median(w) if w else "", "%d" % statistics.median(m) if m else "",
        ",".join(str(x[1]) for x in r), "-".join(sorted({x[4] for x in r})[::max(1, len(r) - 1)])))
