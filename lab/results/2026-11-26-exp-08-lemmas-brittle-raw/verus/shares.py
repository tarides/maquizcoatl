#!/usr/bin/env python3
# Issue #34, run 4: rlimit shares and per-version summaries from brittle.sh's
# checks.tsv and functions.tsv (Verus).  Share = per-function rlimit count /
# 30,000,000 (default --rlimit 10 x 3,000,000 units, experiment #9's
# calibration, rechecked in this run).  Run with python3 -I.
#   shares.py <checks.tsv> <functions.tsv> [function ...]
import csv
import statistics
import sys

LIMIT = 30_000_000
SEEDS = ["default"] + [str(i) for i in range(1, 11)]
VERS = ["4.16.0", "5.3.0", "4.15.3"]
chk = list(csv.DictReader(open(sys.argv[1]), delimiter="\t"))
fun = list(csv.DictReader(open(sys.argv[2]), delimiter="\t"))
fun = [r for r in fun if r["label"] == ""]
focus = sys.argv[3:]

print("## Cells (version, seed): exit verified errors wall user sys rss max_fn_share max_fn failing")
for r in chk:
    sh = int(r["max_fn_rlimit"]) / LIMIT if r["max_fn_rlimit"] not in ("", "0") else 0
    print("\t".join([r["version"], r["seed"], r["label"] or "-", r["exit"], r["verified"], r["errors"],
                     r["wall_s"], r["user_s"], r["sys_s"], r["max_rss_kb"], "%.3f" % sh,
                     r["max_fn"], r["failing"]]))

print("\n## Per version: cells, passing, wall median (min-max), CPU median, function checks, >10%, >25%, >50%, failed fns, highest share")
for v in VERS:
    rows = [r for r in chk if r["version"] == v and r["label"] == ""]
    ok = [r for r in rows if r["exit"] == "0" and r["errors"] == "0" and r["failing"] == "-"]
    walls = [float(r["wall_s"]) for r in rows]
    cpu = [float(r["user_s"]) + float(r["sys_s"]) for r in rows]
    fr = [r for r in fun if r["version"] == v]
    shares = [(int(r["rlimit"]) / LIMIT, r["function"], r["seed"]) for r in fr]
    failed = [r for r in fr if r["success"] != "True"]
    mx = max(shares) if shares else (0, "-", "-")
    print("%s\t%d\t%d\t%.2f (%.2f-%.2f)\t%.2f\t%d\t%d\t%d\t%d\t%d\t%.3f %s seed %s" % (
        v, len(rows), len(ok), statistics.median(walls), min(walls), max(walls), statistics.median(cpu),
        len(fr), sum(s > .10 for s, _, _ in shares), sum(s > .25 for s, _, _ in shares),
        sum(s > .50 for s, _, _ in shares), len(failed), mx[0], mx[1], mx[2]))

print("\n## Functions above 10% in any cell: version function count>10% max (seed)")
for v in VERS:
    by = {}
    for r in fun:
        if r["version"] != v:
            continue
        s = int(r["rlimit"]) / LIMIT
        by.setdefault(r["function"], []).append((s, r["seed"]))
    for f, l in sorted(by.items(), key=lambda kv: -max(kv[1])[0]):
        if max(l)[0] > .10:
            print("%s\t%s\t%d\t%.3f (%s)" % (v, f, sum(s > .10 for s, _ in l), max(l)[0], max(l)[1]))

print("\n## Largest share per function, all cells, top 12 by 4.16.0 max")
allf = {}
for r in fun:
    allf.setdefault(r["function"], {}).setdefault(r["version"], []).append(int(r["rlimit"]) / LIMIT)
top = sorted(allf, key=lambda f: -max(allf[f].get("4.16.0", [0])))[:12]
for f in top:
    print(f + "\t" + "\t".join("%s %.3f" % (v, max(allf[f].get(v, [0]))) for v in VERS))

for f in focus:
    print("\n## %s per seed (default, 1..10)" % f)
    for v in VERS:
        d = {r["seed"]: int(r["rlimit"]) / LIMIT for r in fun if r["version"] == v and r["function"].endswith("::" + f)}
        print(v + "\t" + "\t".join(".%03d" % round(d[s] * 1000) if s in d and d[s] < 1 else ("%.3f" % d[s] if s in d else "?") for s in SEEDS))
