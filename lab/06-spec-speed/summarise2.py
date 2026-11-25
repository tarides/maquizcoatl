#!/usr/bin/env python3
"""Experiment #6 milestone 2: summarise a run's outputs (medians of the
three timed runs) as Markdown tables.

  python3 -I summarise2.py OUT_DIR [M1_OUT_DIR]

OUT_DIR is <exp>/m2/out/<run-id> copied back (subdirectories g, why3,
fstar with times.tsv and the drivers' logs).  M1_OUT_DIR (optional) is
the run directory of milestone 2's WP D (milestone 1's Isabelle and Lean
reruns)."""
import os, re, statistics, sys

BAR = 34.7          # cases/s: 10^6 cases in 8 hours
CAP = 1200


def secs(w):
    p = [float(x) for x in w.split(":")]
    return p[0] * 60 + p[1] if len(p) == 2 else p[0] * 3600 + p[1] * 60 + p[2]


def times(d):
    rows = {}
    f = os.path.join(d, "times.tsv")
    if not os.path.exists(f):
        return rows
    for l in open(f):
        lab, run, st, wall, rss, load = l.rstrip("\n").split("\t")
        if run in ("cal", "x"):
            continue
        rows.setdefault(lab, []).append((run, int(st), secs(wall) if wall else None,
                                         int(rss) if rss else 0, load))
    return rows


def med(xs):
    xs = [x for x in xs if x is not None]
    return statistics.median(xs) if xs else None


def kv(line):
    return dict(re.findall(r"(\w+)=([\d.]+)", line))


def driver_lines(d, label):
    out = []
    for r in ("1", "2", "3"):
        f = os.path.join(d, f"{label}.{r}.log")
        if os.path.exists(f):
            ls = [l for l in open(f) if "cps=" in l]
            if ls:
                out.append(kv(ls[-1]))
    return out


def fmt(x, nd=0):
    return "-" if x is None else (f"{x:,.{nd}f}")


def main():
    o = sys.argv[1]
    print("## Throughput (median of three runs)\n")
    print("| Row | Mode | Parse cases/s | Search cases/s | End to end cases/s | 10^6 cases (s) | Verdict |")
    print("|-----|------|---:|---:|---:|---:|---|")
    g = driver_lines(f"{o}/g", "g-ocamlopt")
    c = driver_lines(f"{o}/g", "c-oracle")
    gparse = med([float(x["parse_cps"]) for x in g]) if g else None
    for name, rows in (("C library (reference)", c), ("stack G, ocamlopt", g)):
        if rows:
            p = med([float(x["parse_cps"]) for x in rows])
            s = med([float(x["search_cps"]) for x in rows])
            e = med([float(x["e2e_cps"]) for x in rows])
            print(f"| {name} | native | {fmt(p)} | {fmt(s)} | {fmt(e)} | {fmt(1e6 / e, 1)} | "
                  f"{'meets' if e >= BAR else 'below'} |")
    for tool, lab, name in (("why3", "why3-extracted", "Why3, extracted OCaml"),
                            ("fstar", "fstar-extracted", "F*, extracted OCaml")):
        rows = driver_lines(f"{o}/{tool}", lab)
        if rows:
            s = med([float(x["search_cps"]) for x in rows])
            e = 1 / (1 / gparse + 1 / s) if gparse else s
            print(f"| {name} | extracted | (stack G) | {fmt(s)} | {fmt(e)} | {fmt(1e6 / e, 1)} | "
                  f"{'meets' if e >= BAR else 'below'} |")
    print("\n## In-prover modes (evaluation minus Q0, median of three)\n")
    print("| Mode | Q0 s | Q s | Cases | Cases/s (search) | End to end cases/s | 10^6 cases (h) | Verdict | Peak RSS MB |")
    print("|------|---:|---:|---:|---:|---:|---:|---|---:|")
    ncases = {"why3": 1160, "fstar": 1160}
    for tool, q0, qx, name, passes in (("why3", "why3-Q0", "why3-QX", "Why3 `why3 execute`", 1),
                                       ("fstar", "fstar-Q0", "fstar-QN", "F\\* normaliser", 1)):
        t = times(f"{o}/{tool}")
        if qx not in t:
            continue
        q0m = med([r[2] for r in t.get(q0, [])])
        ok = [r for r in t[qx] if r[1] == 0]
        to = [r for r in t[qx] if r[1] == 124]
        if ok:
            qm = med([r[2] for r in ok])
            n = ncases[tool] * passes
            cps = n / (qm - q0m)
            e = 1 / (1 / gparse + 1 / cps) if gparse else cps
            rss = max(r[3] for r in t[qx]) / 1024
            print(f"| {name} | {fmt(q0m, 1)} | {fmt(qm, 1)} | {n} | {fmt(cps, 1)} | {fmt(e, 1)} | "
                  f"{fmt(1e6 / e / 3600, 1)} | {'meets' if e >= BAR else 'below'} | {fmt(rss)} |")
        if to:
            print(f"| {name} | {fmt(q0m, 1)} | timeout ({CAP} s) | - | - | - | - | below | - |")
    print("\n## T_spec (median of three clean runs, seconds)\n")
    print("| Label | Runs | Median s | Loads (1 min) |")
    print("|-------|---:|---:|---|")
    for tool in ("why3", "fstar"):
        t = times(f"{o}/{tool}")
        for lab in sorted(t):
            if any(k in lab for k in ("typecheck", "vcgen", "extract-ocaml", "ocamlopt", "check")):
                rs = t[lab]
                print(f"| {lab} | {len(rs)} | {fmt(med([r[2] for r in rs]), 2)} | "
                      f"{', '.join(r[4].split()[0] for r in rs)} |")
    print("\n## Spot check (full property table, property-heavy cases)\n")
    print("| Label | Status | Wall s | Peak RSS MB | Load |")
    print("|-------|---|---:|---:|---|")
    for tool in ("why3", "fstar"):
        t = times(f"{o}/{tool}")
        for lab in sorted(t):
            if lab.endswith("F"):
                for r in t[lab]:
                    print(f"| {lab} | {r[1]} | {fmt(r[2], 1)} | {fmt(r[3] / 1024)} | {r[4]} |")
    print("\n## All timed runs\n")
    print("| Tool | Label | Run | Status | Wall s | Peak RSS MB | Load |")
    print("|------|-------|---|---|---:|---:|---|")
    for tool in ("g", "why3", "fstar"):
        for lab, rs in sorted(times(f"{o}/{tool}").items()):
            for r in rs:
                print(f"| {tool} | {lab} | {r[0]} | {r[1]} | {fmt(r[2], 2)} | {fmt(r[3] / 1024)} | {r[4]} |")


if __name__ == "__main__":
    main()
