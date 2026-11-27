#!/usr/bin/env python3
"""Issue #22: result tables from one run directory.

usage: python3 -I summarise22.py RUN_DIR E12_SUMMARY_DIR OUT_DIR

RUN_DIR is a copy of <exp>/out/<run-id>/ (work/, work12/, agree/,
short.csv, large.csv, cata.csv, catafuel.csv, conv.csv,
conv-subject.txt, and the *-repeat.csv files of noisy cells).
E12_SUMMARY_DIR is experiment #12's summary directory
(lab/results/2026-11-19-exp-12-raw/summary), for context columns.
Writes Markdown tables and CSVs to OUT_DIR.
"""
import csv, os, statistics, sys
from collections import Counter, defaultdict

FAM = ["jq", "php", "vscode", "longphp"]
COLS = ["c", "stubs", "ctypes", "vm", "rocq", "fstar"]
LARGE = ["c", "stubs", "ctypes", "vm", "rocq-scan", "fstar-scan"]
CATA = ["c", "c-noopt", "stubs", "ctypes", "vm", "rocq", "fstar"]


def q(xs):
    xs = sorted(xs)
    if len(xs) == 1:
        return xs[0], xs[0], 0.0
    qs = statistics.quantiles(xs, n=4, method="inclusive")
    return xs[0], statistics.median(xs), qs[2] - qs[0]


def fmt(x, nd=1):
    if x is None:
        return "-"
    if abs(x) >= 1e4:
        return f"{x:,.0f}"
    return f"{x:.{nd}f}"


def col(e):
    """Column of an engine name (the scan mode belongs to its engine's column)."""
    return e[:-5] if e.endswith("-scan") else e


def rows(rd, name):
    p = os.path.join(rd, name)
    return list(csv.DictReader(open(p))) if os.path.exists(p) else []


# ---------------------------------------------------------------- agreement

def agreement(rd, out):
    lines = ["| Family | Calls | stubs = C | ctypes = C | VM = C | Rocq = C | F\\* = C | scan modes = C | C limit codes | agreed (timed) | C = experiment #1 expected |",
             "|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---|"]
    dis = []
    for fam in FAM:
        rd_ = lambda e: dict(l.rstrip("\n").split(" ", 1) for l in open(os.path.join(rd, "agree", f"{fam}.{e}")))
        c = rd_("c")
        n = len(c)
        cnt = {}
        for e in ["stubs", "ctypes", "vm", "rocq", "fstar"] + (["rocq-scan", "fstar-scan"] if fam == "longphp" else []):
            o = rd_(e)
            cnt[e] = sum(1 for k in c if o.get(k) == c[k])
            dis += [(fam, e, k, c[k], o.get(k)) for k in c if o.get(k) != c[k]]
        lim = sum(1 for v in c.values() if v.split()[0] in ("-15", "-17", "-18"))
        agreed = sum(1 for l in open(os.path.join(rd, "work", f"{fam}.agreed.work")) if l.startswith("C "))
        if fam != "vscode":
            exp = {l.split()[0]: l.split()[1:] for l in open(os.path.join(rd, "work12", f"{fam}.expected.tsv"))}
            ok = 0
            for k, r in c.items():
                f, e = r.split(), exp[k]
                if int(f[0]) >= 0:
                    ok += int(e[0]) == int(f[0]) and (e[1] == "-1" or (int(e[1]), int(e[2])) == (int(f[2]), int(f[3])))
                else:
                    ok += int(e[0]) == int(f[0])
            expcol = f"{ok} / {n}"
        else:
            ok = tot = skipped = 0
            for l in open(os.path.join(rd, "work12", "vscode.lines.tsv")):
                line, count, idx, b, e, cids = l.rstrip("\n").split("\t")
                cids = cids.split(",") if cids else []
                if not cids:
                    skipped += 1   # member-less scanner (experiment #12's rule)
                    continue
                if any(x not in c for x in cids):
                    continue
                best = None
                for i, x in enumerate(cids):
                    f = c[x].split()
                    if int(f[0]) >= 0 and (best is None or int(f[0]) < best[1]):
                        best = (i, int(f[2]), int(f[3]))
                tot += 1
                ok += (int(idx) < 0) if best is None else \
                    (int(idx) == best[0] and int(b) == best[1] and int(e) == best[2])
            expcol = (f"{ok} / {tot} scanner searches whose members are all in the fragment "
                      f"({skipped} searches on member-less scanners skipped)")
        scan = " ".join(f"{e}: {cnt[e]:,}" for e in ["rocq-scan", "fstar-scan"] if e in cnt) or "-"
        lines.append(f"| {fam} | {n:,} | {cnt['stubs']:,} | {cnt['ctypes']:,} | {cnt['vm']:,} | {cnt['rocq']:,} | "
                     f"{cnt['fstar']:,} | {scan} | {lim} | {agreed:,} | {expcol} |")
    lines += ["", "Disagreements with C (family, column, case id, C `result nregs beg end ...`, column):", ""]
    lines += [f"- {f} {e} case {k}: C `{a}`, {e} `{b}`" for f, e, k, a, b in dis] or ["- none"]
    open(os.path.join(out, "agreement.md"), "w").write("\n".join(lines) + "\n")


# ---------------------------------------------------------------- short

def cells_of(rd, name, key, val, extra=()):
    cell, aux = defaultdict(list), defaultdict(list)
    bad = Counter()
    for r in rows(rd, name):
        k = tuple(r[x] for x in key)
        if r["rc"] != "0" or not r[val]:
            bad[k + (r["rc"],)] += 1
            continue
        cell[k].append(float(r[val]))
        aux[k].append(tuple(float(r[x]) for x in extra))
    return cell, aux, bad


def short(rd, e12, out):
    cell, aux, bad = cells_of(rd, "short.csv", ["engine", "family"], "ns_per_call",
                              ["minor_per_call", "major_per_call"])
    rcell, raux, _ = cells_of(rd, "short-repeat.csv", ["engine", "family"], "ns_per_call",
                              ["minor_per_call", "major_per_call"])
    ctx = {(r["engine"], r["family"]): float(r["median"]) for r in csv.DictReader(open(os.path.join(e12, "short-summary.csv")))}
    summ = {}
    lines = ["| Family | Column | runs | min ns/call | median ns/call | IQR/median | minor words/call | major words/call | experiment #12, full subset (context) |",
             "|---|---|---:|---:|---:|---:|---:|---:|---:|"]
    with open(os.path.join(out, "short-summary.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["family", "column", "engine", "runs", "min", "median", "iqr", "minor", "major", "repeated", "noisy"])
        for fam in FAM:
            for c in COLS:
                e = c + "-scan" if fam == "longphp" and c in ("rocq", "fstar") else c
                xs, ax, rep = cell.get((e, fam)), aux.get((e, fam)), ""
                if not xs:
                    continue
                mn, md, iqr = q(xs)
                if iqr > 0.1 * md and (e, fam) in rcell:
                    xs, ax, rep = rcell[(e, fam)], raux[(e, fam)], " (repeated)"
                    mn, md, iqr = q(xs)
                noisy = iqr > 0.1 * md
                mi = statistics.median(a for a, _ in ax)
                ma = statistics.median(b for _, b in ax)
                summ[(c, fam)] = (md, mi, ma)
                name = e if e == c else f"{c} ({e})"
                lines.append(f"| {fam} | {name} | {len(xs)} | {fmt(mn)} | {fmt(md)} | {100 * iqr / md:.1f}%"
                             f"{' noisy' if noisy else ''}{rep} | {mi:.2f} | {ma:.4f} | {fmt(ctx.get((c, fam)))} |")
                w.writerow([fam, c, e, len(xs), mn, md, iqr, mi, ma, bool(rep), noisy])
        for fam in FAM:
            for c in ["vm-flambda", "re"]:
                if (c, fam) in ctx:
                    lines.append(f"| {fam} | {c} (not rerun) | - | - | - | - | - | - | {fmt(ctx[(c, fam)])} |")
    if bad:
        lines += ["", "Runs without a result: " + ", ".join(f"{k}: {n}" for k, n in bad.items())]
    open(os.path.join(out, "short.md"), "w").write("\n".join(lines) + "\n")
    return summ


def conv(rd, out):
    cell, aux, _ = cells_of(rd, "conv.csv", ["engine", "family"], "ns_per_call",
                            ["ns_per_byte", "minor_per_call", "major_per_call", "calls_per_pass", "bytes_per_pass"])
    res = {}
    lines = ["| Family | Engine | runs | median ns/call | IQR/median | ns/byte | bytes/call | minor words/call | major words/call |",
             "|---|---|---:|---:|---:|---:|---:|---:|---:|"]
    for fam in FAM:
        for e in ["rocq", "fstar"]:
            xs = cell.get((e, fam))
            if not xs:
                continue
            mn, md, iqr = q(xs)
            a = aux[(e, fam)]
            res[(e, fam)] = md
            lines.append(f"| {fam} | {e} | {len(xs)} | {fmt(md)} | {100 * iqr / md:.1f}% | "
                         f"{statistics.median(x[0] for x in a):.3f} | {a[0][4] / a[0][3]:,.1f} | "
                         f"{statistics.median(x[1] for x in a):.2f} | {statistics.median(x[2] for x in a):.4f} |")
    lines += ["", "Whole-subject conversion (scan mode; one conversion per process, in the untimed warm-up of `scan`):", "",
              "| Engine | Subject | ns/byte | minor words | major words | heap after (MB) | major collections |",
              "|---|---|---:|---:|---:|---:|---:|"]
    p = os.path.join(rd, "conv-subject.txt")
    if os.path.exists(p):
        for l in open(p):
            kv = dict(x.split("=", 1) for x in l.split() if "=" in x)
            if "ns_per_byte" in kv:
                lines.append(f"| {kv['engine']} | {kv['subject']} | {kv['ns_per_byte']} | {float(kv['minor_words']):,.0f} | "
                             f"{float(kv['major_words']):,.0f} | {kv['heap_mb_after']} | {kv['major_collections']} |")
        last = [l for l in open(p) if "gc_minor_heap_size" in l]
        if last:
            kv = dict(x.split("=", 1) for x in last[0].split() if "=" in x)
            lines += ["", "GC settings: " + ", ".join(f"{k[3:]} {v}" for k, v in kv.items() if k.startswith("gc_"))
                      + f", OCAMLRUNPARAM {kv.get('ocamlrunparam')}."]
    open(os.path.join(out, "conv.md"), "w").write("\n".join(lines) + "\n")
    return res


def costs(s, cv, out):
    lines = ["| Family | C driver (ns/call) | stubs - C | ctypes - C | VM - C | Rocq - C | F\\* - C | Rocq - VM, gross | Rocq - VM, net of conversion | F\\* - VM, gross | F\\* - VM, net of conversion |",
             "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for fam in FAM:
        g = lambda e: s.get((e, fam), (None,))[0]
        c, st, ct, v, r, f = (g(x) for x in COLS)
        if None in (c, v):
            continue
        d = lambda x, y: "-" if x is None or y is None else f"{fmt(x - y)} ({x / y:.1f}x)"
        net = lambda x, e: "-" if x is None or (e, fam) not in cv else f"{fmt(x - cv[(e, fam)] - v)}"
        conv_note = "" if fam != "longphp" else " (scan mode: conversion outside the timed passes)"
        lines.append(f"| {fam} | {fmt(c)} | {d(st, c)} | {d(ct, c)} | {d(v, c)} | {d(r, c)} | {d(f, c)} | "
                     f"{d(r, v)} | {net(r, 'rocq') if fam != 'longphp' else '-'} | {d(f, v)} | "
                     f"{net(f, 'fstar') if fam != 'longphp' else '-'} |")
    lines += ["", "Differences of medians in ns per call; the factor is the ratio of the two medians. "
              "Net of conversion: the extracted column minus its median per-call conversion cost "
              "(conv.md), minus the hand-written VM. Long PHP runs the extracted columns in scan mode, "
              "so its figures exclude the conversion already."]
    open(os.path.join(out, "costs.md"), "w").write("\n".join(lines) + "\n")


# ---------------------------------------------------------------- large

def large(rd, e12, out):
    rs = rows(rd, "large.csv")
    lst = [l.split() for l in open(os.path.join(rd, "work", "large.list"))][1:]
    rank = {(s, int(p)): (int(r), h) for s, r, p, fam, calls, h in lst}
    cell, aux, bad = defaultdict(list), defaultdict(list), Counter()
    matches = defaultdict(set)
    for r in rs:
        k = (col(r["engine"]), r["source"], r["size"], int(r["pid"]))
        if r["rc"] != "0" or not r["bytes_per_sec"]:
            bad[(r["engine"], r["source"], r["size"], "timeout" if r["rc"] == "124" else f"rc {r['rc']}")] += 1
            continue
        cell[k].append(float(r["bytes_per_sec"]))
        aux[k].append(float(r["minor_per_match"]))
        matches[k[1:]].add((k[0], r["matches"]))
    rep = defaultdict(list)
    for r in rows(rd, "large-repeat.csv"):
        if r["rc"] == "0" and r["bytes_per_sec"]:
            rep[(col(r["engine"]), r["source"], r["size"], int(r["pid"]))].append(float(r["bytes_per_sec"]))
    per = {}
    with open(os.path.join(out, "large-patterns.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["column", "source", "size", "pid", "rank", "pattern_hex", "runs", "min_Bps", "median_Bps",
                    "iqr_Bps", "minor_per_match", "repeated", "noisy"])
        for k, xs in sorted(cell.items()):
            mn, md, iqr = q(xs)
            repd = False
            if iqr > 0.1 * md and k in rep:
                mn, md, iqr = q(rep[k])
                repd = True
            per[k] = (md, iqr)
            w.writerow(list(k) + [rank[(k[1], k[3])][0], rank[(k[1], k[3])][1], len(xs), mn, md, iqr,
                                  statistics.median(aux[k]), repd, iqr > 0.1 * md])
    # Context: experiment #12's medians over the patterns this run timed
    # (after a reduction, a subset of work/large.list), not over the list.
    timed = {(k[1], k[3]) for k in cell}
    ctx = defaultdict(list)
    for r in csv.DictReader(open(os.path.join(e12, "large-patterns.csv"))):
        if (r["source"], int(r["pid"])) in timed:
            ctx[(r["engine"], r["source"], r["size"])].append(float(r["median_Bps"]))
    agg = {}
    lines = ["| Source | Size | Column | patterns | median over patterns of median MB/s | min..max of per-pattern medians (MB/s) | patterns with IQR > 10% | median minor words/match | experiment #12, same patterns (context) |",
             "|---|---|---|---:|---:|---|---:|---:|---:|"]
    for src in ["log", "src"]:
        for size in ["1m", "16m"]:
            for c in [col(x) for x in LARGE]:
                ks = [k for k in per if k[:3] == (c, src, size)]
                cx = ctx.get((c, src, size))
                cxs = f"{statistics.median(cx) / 1e6:,.1f}" if cx else "-"
                if not ks:
                    nb = sum(n for k, n in bad.items() if col(k[0]) == c and k[1:3] == (src, size))
                    if nb:
                        lines.append(f"| {src} | {size} | {c} | 0 | no result ({nb} runs) | - | - | - | {cxs} |")
                    continue
                meds = [per[k][0] for k in ks]
                noisy = sum(1 for k in ks if per[k][1] > 0.1 * per[k][0])
                agg[(c, src, size)] = statistics.median(meds)
                lines.append(f"| {src} | {size} | {c} | {len(ks)} | {statistics.median(meds) / 1e6:,.2f} | "
                             f"{min(meds) / 1e6:,.2f}..{max(meds) / 1e6:,.2f} | {noisy} | "
                             f"{statistics.median(statistics.median(aux[k]) for k in ks):.2f} | {cxs} |")
    mism = {k: v for k, v in matches.items() if len({m for _, m in v}) > 1}
    lines += ["", "Match counts per (source, size, pattern): "
              + ("identical across columns" if not mism else "DIFFER: " + "; ".join(f"{k}: {sorted(v)}" for k, v in mism.items()))]
    if bad:
        lines += ["", "Runs without a result: " + ", ".join(f"{k}: {n}" for k, n in sorted(bad.items()))]
    open(os.path.join(out, "large.md"), "w").write("\n".join(lines) + "\n")
    return agg


# ---------------------------------------------------------------- catastrophic

def cata(rd, out):
    cell = defaultdict(list)
    for r in rows(rd, "cata.csv"):
        cell[(r["engine"], r["family"], int(r["len"]))].append((r["outcome"] or f"rc{r['rc']}", float(r["sec"] or "nan")))
    lines = ["| Pattern | n | " + " | ".join(CATA) + " | outcomes = c-noopt |", "|---|---:|" + "---|" * len(CATA) + "---|"]
    summ = {}
    for fam, pat in [("php-frag", "(a|aa)*b"), ("jq-frag", "(aa*)*b")]:
        for n in sorted({k[2] for k in cell if k[1] == fam}):
            ref = Counter(o for o, _ in cell.get(("c-noopt", fam, n), []))
            cs, ag = [], []
            for e in CATA:
                xs = cell.get((e, fam, n))
                if not xs:
                    cs.append("-")
                    continue
                oc = Counter(o for o, _ in xs)
                md = statistics.median(t for _, t in xs)
                summ[(e, fam, n)] = ("/".join(oc), md)
                cs.append(f"{'/'.join(oc)} {md * 1e3:,.3f} ms")
                if e != "c-noopt":
                    ag.append(f"{e}:{'yes' if set(oc) == set(ref) else 'no'}")
            lines.append(f"| `{pat}` | {n} | " + " | ".join(cs) + f" | {' '.join(ag)} |")
    lines += ["", "Cell: outcomes over the runs (`limit` = -17, retry budget 10,000,000 per start position; "
              "`cap` = 60 s timeout) and median wall time of one search. `c`, `stubs`, `ctypes` use the default "
              "libonig, whose optimiser rejects both subjects before backtracking; `c-noopt` is the same driver "
              "on the `-DONIG_DONT_OPTIMIZE` build. `rocq`, `fstar`: fuel `max_int`."]
    fcell = defaultdict(list)
    for r in rows(rd, "catafuel.csv"):
        fcell[(r["engine"], r["family"], int(r["len"]))].append((r["outcome"] or f"rc{r['rc']}", float(r["sec"] or "nan")))
    lines += ["", "Not comparable: time until `OutOfFuel` with a stated fuel of 10,000,000 VM instructions per start "
              "position (fuel counts instructions; the C budget counts backtracks):", "",
              "| Pattern | n | rocq | fstar |", "|---|---:|---|---|"]
    for fam, pat in [("php-frag", "(a|aa)*b"), ("jq-frag", "(aa*)*b")]:
        for n in sorted({k[2] for k in fcell if k[1] == fam}):
            cs = []
            for e in ["rocq", "fstar"]:
                xs = fcell.get((e, fam, n))
                if not xs:
                    cs.append("-")
                    continue
                oc = Counter(o for o, _ in xs)
                cs.append(f"{'/'.join(oc)} {statistics.median(t for _, t in xs) * 1e3:,.1f} ms")
            lines.append(f"| `{pat}` | {n} | " + " | ".join(cs) + " |")
    open(os.path.join(out, "cata.md"), "w").write("\n".join(lines) + "\n")
    return summ


def conclusion(s, lg, out):
    lines = ["| Shape | Workload | C driver | stubs - C | ctypes - C | VM - C | Rocq - C | F\\* - C | cheapest OCaml option |",
             "|---|---|---:|---:|---:|---:|---:|---:|---|"]
    for fam in FAM:
        g = lambda e: s.get((e, fam), (None,))[0]
        c = g("c")
        if c is None:
            continue
        opts = [(g(e), n) for e, n in [("stubs", "stubs"), ("ctypes", "ctypes"), ("vm", "VM"), ("rocq", "Rocq"), ("fstar", "F*")] if g(e)]
        d = lambda x: "-" if x is None else f"{fmt(x - c)} ({x / c:.1f}x)"
        lab = "short (ns/call)" if fam != "longphp" else "synthetic long PHP (ns/call)"
        lines.append(f"| {lab} | {fam} | {fmt(c)} | {d(g('stubs'))} | {d(g('ctypes'))} | {d(g('vm'))} | "
                     f"{d(g('rocq'))} | {d(g('fstar'))} | {min(opts)[1]} |")
    for src in ["log", "src"]:
        for size in ["1m", "16m"]:
            if ("c", src, size) not in lg:
                continue
            tm = lambda e: (1 << 20) / lg[(e, src, size)] * 1e3 if (e, src, size) in lg else None
            c = tm("c")
            d = lambda x: "not run" if x is None else f"{x - c:+,.3f} ({x / c:,.1f}x)"
            opts = [(tm(e), n) for e, n in [("stubs", "stubs"), ("ctypes", "ctypes"), ("vm", "VM"), ("rocq", "Rocq"), ("fstar", "F*")] if tm(e)]
            lines.append(f"| large (ms per MiB, median over patterns) | {src}-{size} | {c:.3f} | {d(tm('stubs'))} | "
                         f"{d(tm('ctypes'))} | {d(tm('vm'))} | {d(tm('rocq'))} | {d(tm('fstar'))} | {min(opts)[1]} |")
    open(os.path.join(out, "conclusion.md"), "w").write("\n".join(lines) + "\n")


def main():
    rd, e12, out = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    agreement(rd, out)
    s = short(rd, e12, out)
    cv = conv(rd, out)
    costs(s, cv, out)
    lg = large(rd, e12, out)
    cata(rd, out)
    conclusion(s, lg, out)


if __name__ == "__main__":
    main()
