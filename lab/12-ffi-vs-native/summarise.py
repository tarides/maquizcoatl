#!/usr/bin/env python3
"""Experiment #12: build the result tables from one run directory.

usage: python3 -I summarise.py RUN_DIR OUT_DIR

RUN_DIR is a copy of <exp>/out/<run-id>/ (work/, agree/, tests.out,
alloc.txt, short.csv, large.csv, cata.csv, conditions.csv).  Writes
Markdown tables to OUT_DIR/*.md and summary CSVs beside them.
"""
import csv, os, statistics, sys
from collections import Counter, defaultdict

ENG = ["c", "stubs", "ctypes", "vm", "vm-flambda", "re"]
FAM = ["jq", "php", "vscode"]


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


def read_work(path):
    P, S, C = {}, {}, []
    for l in open(path):
        f = l.split()
        if f[0] == "P":
            P[int(f[1])] = f
        elif f[0] == "S":
            S[int(f[1])] = len(f[2]) // 2 if len(f) > 2 else 0
        elif f[0] == "C":
            C.append([int(x) for x in f[1:]])
    return P, S, C


def coverage(rd, out):
    lines = ["| Family | Triples in subset / total | Calls in subset / total | Weighted calls (frequency profile) | Top rejection reasons |",
             "|---|---|---|---|---|"]
    for fam in FAM + ["longphp"]:
        P, S, C = read_work(os.path.join(rd, "work", f"{fam}.all.work"))
        cov = [l.split() for l in open(os.path.join(rd, "work", f"{fam}.coverage.tsv"))]
        st = {int(c[0]): (int(c[1]), c[2], c[3]) for c in cov}
        w = {c[0]: c[7] for c in C}
        pid_any = defaultdict(bool)
        for cid, (pid, s, _) in st.items():
            pid_any[pid] |= (s == "valid")
        reasons = Counter()
        for cid, (pid, s, r) in st.items():
            if s != "valid":
                reasons[r] += w[cid] if fam == "vscode" else 1
        n_valid = sum(1 for v in st.values() if v[1] == "valid")
        wv = sum(w[c] for c, v in st.items() if v[1] == "valid")
        wt = sum(w.values())
        top = ", ".join(f"`{r}` {n:,}" for r, n in reasons.most_common(5))
        lines.append(f"| {fam} | {sum(pid_any.values())} / {len(pid_any)} | {n_valid:,} / {len(st):,} "
                     f"({100 * n_valid / len(st):.1f}%) | "
                     + (f"{wv:,} / {wt:,} ({100 * wv / wt:.1f}%)" if fam == "vscode" else "-")
                     + f" | {top} |")
    note = ("\nTriples are counted per (syntax, options, retry limit, stack limit, pattern); "
            "a triple is in the subset when at least one of its calls is admitted. "
            "VS Code calls are scanner searches expanded to one search per member triple "
            "(11,263 committed searches; weights from the frequency profile). "
            "Invalid-in-subset (Oniguruma compile error) calls: none in the workloads.\n")
    open(os.path.join(out, "coverage.md"), "w").write("\n".join(lines) + "\n" + note)


def tests(rd, out):
    res = [l.split(None, 2) for l in open(os.path.join(rd, "tests.out")) if not l.startswith("RESULT")]
    kinds = Counter()
    inset = Counter()
    fails = []
    outr = Counter()
    for line, kind, verdict in res:
        kinds[kind] += 1
        v = verdict.strip()
        if "out-of-subset" in v:
            outr[v.split("out-of-subset ")[1]] += 1
            continue
        inset[kind] += 1
        if v != "ok":
            fails.append((line, kind, v))
    lines = ["| Kind | Extracted | In subset | Passed |", "|---|---|---|---|"]
    passed = Counter(k for (l, k, v) in res if v.strip() == "ok")
    for k in ["x2", "x3", "n", "e"]:
        lines.append(f"| {k} | {kinds[k]} | {inset[k]} | {passed[k]} |")
    lines.append(f"| total | {sum(kinds.values())} (+1 multi-line case, line 1379, callouts: out) | "
                 f"{sum(inset.values())} | {sum(passed.values())} |")
    lines.append("")
    lines.append("Failures: " + ("none" if not fails else "; ".join(f"line {a} {b}: {c}" for a, b, c in fails)))
    lines.append("")
    lines.append("Top reasons for out of subset: " + ", ".join(f"`{r}` {n}" for r, n in outr.most_common(8)))
    open(os.path.join(out, "tests.md"), "w").write("\n".join(lines) + "\n")


def agreement(rd, out):
    lines = ["| Family | Cases run | stubs = C | ctypes = C | VM (ffi) = C | VM (flambda) = VM (ffi) | C = experiment #1 expected |",
             "|---|---|---|---|---|---|---|"]
    disagreements = []
    for fam in FAM + ["longphp"]:
        rd_ = lambda e: dict(l.rstrip("\n").split(" ", 1) for l in open(os.path.join(rd, "agree", f"{fam}.{e}")))
        c = rd_("c")
        s, t, v, vf = rd_("stubs"), rd_("ctypes"), rd_("vm"), rd_("vm-flambda")
        nv = sum(1 for k in c if v.get(k) == c[k])
        for k in c:
            if v.get(k) != c[k]:
                disagreements.append((fam, k, c[k], v.get(k)))
        # expected from experiment #1
        if fam != "vscode":
            exp = {l.split()[0]: l.split()[1:] for l in open(os.path.join(rd, "work", f"{fam}.expected.tsv"))}
            ok = tot = 0
            for k, r in c.items():
                f = r.split()
                e = exp[k]
                tot += 1
                if int(f[0]) >= 0:
                    span = (int(f[2]), int(f[3]))
                    good = int(e[0]) == int(f[0]) and (e[1] == "-1" or (int(e[1]), int(e[2])) == span)
                else:
                    good = int(e[0]) == int(f[0])
                ok += good
            expcol = f"{ok} / {tot}"
        else:
            # regset ONIG_REGSET_POSITION_LEAD: smallest match start, then lowest index
            ok = tot = 0
            for l in open(os.path.join(rd, "work", "vscode.lines.tsv")):
                line, count, idx, b, e, cids = l.rstrip("\n").split("\t")
                cids = cids.split(",") if cids else []
                if not cids or any(x not in c for x in cids):
                    continue
                best = None
                for i, x in enumerate(cids):
                    f = c[x].split()
                    if int(f[0]) >= 0 and (best is None or int(f[0]) < best[1]):
                        best = (i, int(f[2]), int(f[3]))
                tot += 1
                if best is None:
                    ok += (int(idx) < 0)
                else:
                    ok += (int(idx) == best[0] and int(b) == best[1] and int(e) == best[2])
            expcol = f"{ok} / {tot} scanner searches with all members in subset"
        lines.append(f"| {fam} | {len(c):,} | {'yes' if s == c else 'NO'} | {'yes' if t == c else 'NO'} | "
                     f"{nv:,} / {len(c):,} | {'yes' if vf == v else 'NO'} | {expcol} |")
    lines.append("")
    lines.append("VM disagreements (case id, Oniguruma `result nregs beg end ...`, VM):")
    lines.append("")
    for fam, k, a, b in disagreements:
        lines.append(f"- {fam} case {k}: C `{a}`, VM `{b}`")
    open(os.path.join(out, "agreement.md"), "w").write("\n".join(lines) + "\n")


def short(rd, out):
    rows = list(csv.DictReader(open(os.path.join(rd, "short.csv"))))
    cell = defaultdict(list)
    alloc = defaultdict(list)
    for r in rows:
        if r["rc"] != "0" or not r["ns_per_call"]:
            continue
        cell[(r["engine"], r["family"])].append(float(r["ns_per_call"]))
        alloc[(r["engine"], r["family"])].append((float(r["minor_per_call"]), float(r["major_per_call"])))
    summ = {}
    lines = ["| Family | Engine | runs | min ns/call | median ns/call | IQR | IQR/median | minor words/call | major words/call |",
             "|---|---|---|---|---|---|---|---|---|"]
    with open(os.path.join(out, "short-summary.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["family", "engine", "runs", "min", "median", "iqr", "minor", "major"])
        for fam in FAM + ["longphp"]:
            for e in ENG:
                xs = cell.get((e, fam))
                if not xs:
                    continue
                mn, md, iqr = q(xs)
                mi = statistics.median(a for a, _ in alloc[(e, fam)])
                ma = statistics.median(b for _, b in alloc[(e, fam)])
                summ[(e, fam)] = md
                flag = " (noisy)" if iqr > 0.1 * md else ""
                lines.append(f"| {fam} | {e} | {len(xs)} | {fmt(mn)} | {fmt(md)} | {fmt(iqr)} | {100 * iqr / md:.1f}%{flag} | {mi:.2f} | {ma:.4f} |")
                w.writerow([fam, e, len(xs), mn, md, iqr, mi, ma])
    open(os.path.join(out, "short.md"), "w").write("\n".join(lines) + "\n")
    return summ


def large(rd, out):
    rows = list(csv.DictReader(open(os.path.join(rd, "large.csv"))))
    lst = [l.split() for l in open(os.path.join(rd, "work", "large.list"))][1:]
    rank = {(s, int(p)): (int(r), h) for s, r, p, fam, calls, h in lst}
    cell = defaultdict(list)
    alloc = defaultdict(list)
    bad = Counter()
    for r in rows:
        if r["rc"] != "0" or not r["bytes_per_sec"]:
            bad[(r["engine"], r["source"], r["size"], r["rc"])] += 1
            continue
        k = (r["engine"], r["source"], r["size"], int(r["pid"]))
        cell[k].append(float(r["bytes_per_sec"]))
        alloc[k].append(float(r["minor_per_match"]))
    per = {}
    with open(os.path.join(out, "large-patterns.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["engine", "source", "size", "pid", "rank", "pattern_hex", "runs", "min_Bps", "median_Bps", "iqr_Bps", "minor_per_match"])
        for k, xs in sorted(cell.items()):
            mn, md, iqr = q(xs)
            per[k] = (md, iqr)
            w.writerow(list(k) + [rank[(k[1], k[3])][0], rank[(k[1], k[3])][1], len(xs), mn, md, iqr,
                                  statistics.median(alloc[k])])
    agg = {}
    lines = ["| Source | Size | Engine | patterns | median over patterns of median MB/s | min..max of per-pattern medians (MB/s) | patterns with IQR > 10% |",
             "|---|---|---|---|---|---|---|"]
    for src in ["log", "src"]:
        for size in ["1m", "16m"]:
            for e in ENG:
                ks = [k for k in per if k[:3] == (e, src, size)]
                if not ks:
                    continue
                meds = [per[k][0] for k in ks]
                noisy = sum(1 for k in ks if per[k][1] > 0.1 * per[k][0])
                agg[(e, src, size)] = statistics.median(meds)
                lines.append(f"| {src} | {size} | {e} | {len(ks)} | {statistics.median(meds) / 1e6:,.1f} | "
                             f"{min(meds) / 1e6:,.1f}..{max(meds) / 1e6:,.1f} | {noisy} |")
    if bad:
        lines.append("")
        lines.append("Runs without a result: " + ", ".join(f"{k}: {n}" for k, n in bad.items()))
    open(os.path.join(out, "large.md"), "w").write("\n".join(lines) + "\n")
    return agg


def cata(rd, out):
    rows = list(csv.DictReader(open(os.path.join(rd, "cata.csv"))))
    cell = defaultdict(list)
    for r in rows:
        cell[(r["engine"], r["family"], int(r["len"]))].append((r["outcome"] or f"rc{r['rc']}", float(r["sec"] or "nan")))
    lines = ["| Family | n | " + " | ".join(ENG) + " | outcomes agree with C |",
             "|---|---|" + "---|" * len(ENG) + "---|"]
    summ = {}
    for fam in FAM:
        for n in sorted({k[2] for k in cell if k[1] == fam}):
            cs = []
            ref = Counter(o for o, _ in cell.get(("c", fam, n), []))
            agree = []
            for e in ENG:
                xs = cell.get((e, fam, n))
                if not xs:
                    cs.append("-")
                    continue
                oc = Counter(o for o, _ in xs)
                md = statistics.median(t for _, t in xs)
                summ[(e, fam, n)] = (oc.most_common(1)[0][0], md)
                cs.append(f"{'/'.join(oc)} {md * 1e3:.2f} ms")
                if e not in ("c", "re"):
                    agree.append(f"{e}:{'yes' if oc == ref else 'NO'}")
            lines.append(f"| {fam} | {n} | " + " | ".join(cs) + f" | {' '.join(agree)} |")
    lines.append("")
    lines.append("Cell: outcome over the 10 runs (`limit` = ONIGERR_RETRY_LIMIT_IN_MATCH_OVER, -17, retry budget 10,000,000 per start position) and median wall time of the search. `re` has no backtracking and no budget: reference only.")
    open(os.path.join(out, "cata.md"), "w").write("\n".join(lines) + "\n")
    return summ


def conclusion(short_s, large_s, cata_s, out):
    lines = ["| Shape | Workload | C driver | stubs - C (FFI, stubs) | ctypes - C (FFI, ctypes) | VM - C (engine, ffi) | VM - C (engine, flambda) | cheaper option |",
             "|---|---|---|---|---|---|---|---|"]
    for fam in FAM + ["longphp"]:
        c = short_s.get(("c", fam))
        if c is None:
            continue
        g = lambda e: short_s.get((e, fam))
        s, t, v, vf = g("stubs"), g("ctypes"), g("vm"), g("vm-flambda")
        best = min((x, n) for x, n in [(s, "stubs"), (t, "ctypes"), (v, "VM ffi"), (vf, "VM flambda")] if x)
        lab = "short (ns/call)" if fam != "longphp" else "synthetic long PHP (ns/call)"
        lines.append(f"| {lab} | {fam} | {fmt(c)} | {fmt(s - c)} ({100 * (s - c) / c:+.0f}%) | {fmt(t - c)} ({100 * (t - c) / c:+.0f}%) | "
                     f"{fmt(v - c)} ({100 * (v - c) / c:+.0f}%) | {fmt(vf - c)} ({100 * (vf - c) / c:+.0f}%) | {best[1]} |")
    for src in ["log", "src"]:
        for size in ["1m", "16m"]:
            c = large_s.get(("c", src, size))
            if c is None:
                continue
            # throughput: express as time per MiB so that differences are costs
            tm = lambda e: (1 << 20) / large_s[(e, src, size)] * 1e3 if (e, src, size) in large_s else None
            tc, ts, tt, tv, tvf = tm("c"), tm("stubs"), tm("ctypes"), tm("vm"), tm("vm-flambda")
            best = min((x, n) for x, n in [(ts, "stubs"), (tt, "ctypes"), (tv, "VM ffi"), (tvf, "VM flambda")] if x)
            lines.append(f"| large (ms per MiB, median over patterns) | {src}-{size} | {tc:.3f} | {ts - tc:+.3f} | {tt - tc:+.3f} | "
                         f"{tv - tc:+.3f} ({tv / tc:.1f}x) | {tvf - tc:+.3f} ({tvf / tc:.1f}x) | {best[1]} |")
    open(os.path.join(out, "conclusion.md"), "w").write("\n".join(lines) + "\n")


def main():
    rd, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    coverage(rd, out)
    tests(rd, out)
    agreement(rd, out)
    s = short(rd, out) if os.path.exists(os.path.join(rd, "short.csv")) else {}
    l = large(rd, out) if os.path.exists(os.path.join(rd, "large.csv")) else {}
    c = cata(rd, out) if os.path.exists(os.path.join(rd, "cata.csv")) else {}
    conclusion(s, l, c, out)


if __name__ == "__main__":
    main()
