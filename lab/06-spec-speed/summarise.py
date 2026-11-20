#!/usr/bin/env python3
"""Experiment #6: summarise milestone 1 (cases, agreement, throughput,
T_spec, experiment #7's idle rerun) as Markdown tables.

usage: python3 -I summarise.py DATA OUT
  DATA holds all.tsv, verdicts.tsv, in.tsv, in-ext.tsv, ids.txt
  OUT is the copied <exp>/out/<run-id> (g/, rocq/, lean/, why3/, fstar/,
  e07/ for the idle rerun)
"""
import sys, os, re, statistics
from collections import Counter, defaultdict

TOOLS = ["rocq", "lean", "why3", "fstar"]


def rows(path):
    return [l.rstrip("\n").split("\t") for l in open(path) if l.strip()]


def wall(s):
    p = s.split(":")
    return sum(float(x) * 60 ** i for i, x in enumerate(reversed(p)))


def times(path):
    """label -> run -> (status, wall s, rss KB, load1)"""
    t = defaultdict(dict)
    if not os.path.exists(path):
        return t
    for f in rows(path):
        lab, run, st, w, rss, load = f[:6]
        t[lab][run] = (int(st), wall(w) if w else float("nan"),
                       int(rss) if rss else 0, load.split()[0])
    return t


def med(xs):
    return statistics.median(xs) if xs else float("nan")


def decode(enc, ncap):
    v = [int(x) for x in enc.split()]
    if v == [0]:
        return "MISMATCH"
    if v == [2]:
        return "LIMIT"
    out = ["MATCH", v[1], v[2]]
    i = 3
    for _ in range(ncap):
        if v[i] == 0:
            out += [-1, -1]; i += 1
        else:
            out += [v[i + 1], v[i + 2]]; i += 3
    return " ".join(map(str, out))


def main():
    data, out = sys.argv[1:3]
    allc = rows(f"{data}/all.tsv")
    cls = rows(f"{data}/verdicts.tsv")
    inn = rows(f"{data}/in.tsv")
    ext = rows(f"{data}/in-ext.tsv")
    ids = [l.strip() for l in open(f"{data}/ids.txt")]
    P = print

    # ---- cases --------------------------------------------------------
    P("## Cases\n")
    P("| Suite | Cases | In subset | x2 | x3 | n | e |")
    P("|-------|------:|----------:|---:|---:|--:|--:|")
    insub = {f[1] for f in cls if f[3] == "in"}
    kinds = {f[1]: f[2] for f in cls}
    suites = Counter(r[0] for r in allc)
    for s, n in suites.items():
        ks = Counter(kinds[i] for i in insub if i.split(":")[0] == s)
        P(f"| `{s}` | {n} | {sum(ks.values())} | {ks['x2']} | {ks['x3']} | {ks['n']} | {ks['e']} |")
    ks = Counter(kinds[i] for i in insub)
    P(f"| total | {len(allc)} | {len(insub)} | {ks['x2']} | {ks['x3']} | {ks['n']} | {ks['e']} |\n")
    P("Out of the subset, by first reason met (suite-level reasons first):\n")
    P("| Reason | Cases |")
    P("|--------|------:|")
    for r, n in Counter(f[4] for f in cls if f[3] == "out").most_common():
        P(f"| {r} | {n} |")
    ke = Counter(f[2] for f in ext)
    P(f"\nInformational: accepting `+`, `?` and `(?:...)` (desugared) would put "
      f"{len(ext)} cases in the subset ({ke['x2']} x2, {ke['x3']} x3, {ke['n']} n, "
      f"{ke['e']} e), {len(ext) - len(inn)} more.\n")

    # ---- agreement ----------------------------------------------------
    info = {f[1]: f for f in inn}          # id -> in.tsv row
    cv = dict(r for r in rows(f"{out}/g/oracle-verdicts.txt"))
    gv = dict(r for r in rows(f"{out}/g/g-verdicts.txt"))

    def region(v, k):
        w = v.split()
        if w[0] != "MATCH" or len(w) < 3 + 2 * k:
            return None
        return (int(w[1 + 2 * k]), int(w[2 + 2 * k]))

    def agree(cid, v):
        f = info[cid]
        kind, c = f[2], cv[cid]
        if kind == "x2":
            return region(v, 0) is not None and region(v, 0) == region(c, 0)
        if kind == "x3":
            m = int(f[7])
            return region(v, m) is not None and region(v, m) == region(c, m)
        if kind == "n":
            return v == "MISMATCH"
        if kind == "e":
            return v.startswith("ERR")

    def test_ok(cid):     # the C verdict against the test file's expectation
        f = info[cid]
        kind, c = f[2], cv[cid]
        a, b, m = int(f[5]), int(f[6]), int(f[7])
        if kind == "x2": return region(c, 0) == (a, b)
        if kind == "x3": return region(c, m) == (a, b)
        if kind == "n": return c == "MISMATCH"
        if kind == "e": return c == f"ERR {a}"

    P("## Agreement\n")
    P("C against the test files' expectations: "
      f"{sum(test_ok(i) for i in info)}/{len(info)}.\n")
    P("| Row | x2 | x3 | n | e | e code | All regions identical to C | Out of subset |")
    P("|-----|---:|---:|--:|--:|-------:|--------------------------:|--------------:|")
    nout = len(allc) - len(insub)

    def line(name, verd, inherited_e):
        cnt = Counter(); tot = Counter()
        for cid, f in info.items():
            k = f[2]; tot[k] += 1
            if k == "e":
                v = gv[cid]          # parser verdict: stack G's
            else:
                v = verd[cid]
            if agree(cid, v): cnt[k] += 1
        ecode = sum(1 for cid, f in info.items() if f[2] == "e" and gv[cid] == cv[cid])
        same = sum(1 for cid in info if (gv if info[cid][2] == "e" else verd)[cid] == cv[cid])
        e = f"{cnt['e']}/{tot['e']}" + (" (stack G's parser)" if inherited_e else "")
        P(f"| {name} | {cnt['x2']}/{tot['x2']} | {cnt['x3']}/{tot['x3']} | {cnt['n']}/{tot['n']} | "
          f"{e} | {ecode}/{tot['e']} | {same}/{len(info)} | {nout} |")
    line("stack G", gv, False)
    for t in TOOLS:
        p = f"{out}/{t}/verdicts.txt"
        if not os.path.exists(p):
            P(f"| {t} | missing |"); continue
        enc = [l.strip() for l in open(p)]
        verd = {cid: decode(e, int(info[cid][8])) for cid, e in zip(ids, enc)}
        line(t, verd, True)
    P("")

    # ---- throughput ---------------------------------------------------
    P("## Throughput\n")
    P("Extracted or compiled code: in-process timing of REPS passes (median of three runs);"
      " wall-clock and peak RSS of the whole process from `/usr/bin/time -v`.\n")
    P("| Row | Mode | REPS | Parse cases/s | Search cases/s | End to end cases/s | 10^6 cases (s) | Wall s | RSS MB | Load (1 min) |")
    P("|-----|------|-----:|-------------:|---------------:|-------------------:|---------------:|-------:|-------:|-------------|")
    labs = [("g", "c-oracle", "C library (reference)"), ("g", "g-ocamlopt", "stack G, ocamlopt"),
            ("rocq", "rocq-extracted", "Rocq, extracted OCaml"),
            ("lean", "lean-lake-exe", "Lean 4, lake native build"),
            ("why3", "why3-extracted", "Why3, extracted OCaml"),
            ("fstar", "fstar-extracted", "F*, extracted OCaml")]
    gparse = None
    for d, lab, name in labs:
        tt = times(f"{out}/{d}/times.tsv").get(lab, {})
        vals = defaultdict(list)
        for run in tt:
            for l in open(f"{out}/{d}/{lab}.{run}.log"):
                if "cps=" in l:
                    for k, v in re.findall(r"(\w+)=([\d.]+)", l):
                        vals[k].append(float(v))
        if not tt:
            continue
        reps = int(vals["reps"][0])
        pc = med(vals.get("parse_cps", []))
        sc = med(vals["search_cps"])
        ec = med(vals.get("e2e_cps", []))
        if lab == "g-ocamlopt":
            gparse = pc
        if d not in ("g",) and gparse:
            ec = 1 / (1 / gparse + 1 / sc)   # stack G parse + prover search
        e6 = 1e6 / ec
        P(f"| {name} | {'native' if d == 'g' else 'extracted'} | {reps} | "
          f"{'%.0f' % pc if pc == pc else '(stack G)'} | {sc:.0f} | {ec:.0f} | {e6:.1f} | "
          f"{med([x[1] for x in tt.values()]):.2f} | {max(x[2] for x in tt.values()) / 1024:.0f} | "
          f"{', '.join(x[3] for _, x in sorted(tt.items()))} |")
    P("\nFor prover rows, end to end = stack G's parse plus the prover's search "
      "(plan step 8); 10^6 cases (s) = 10^6 / end-to-end cases/s.\n")

    P("In-prover evaluation: wall-clock of the evaluation command minus the import-only "
      "baseline Q0 of the same run (experiment #7's method), median of three runs.\n")
    P("| Prover | Mode | Passes | Cases | Eval s (median) | Q0 s (median) | Search cases/s | 10^6 cases (s) | Peak RSS MB | Load (1 min) |")
    P("|--------|------|-------:|------:|----------------:|--------------:|---------------:|---------------:|------------:|-------------|")
    reps = dict(l.split("#")[0].strip().split("=") for l in open(f"{data}/reps.env")
                if "=" in l)
    inp = [("rocq", "rocq-QV", "vm_compute", "REPS_VM"),
           ("rocq", "rocq-QN", "native_compute", "REPS_NATIVE"),
           ("rocq", "rocq-QN1", "native_compute, first call (1 pass)", None),
           ("lean", "lean-QE", "#eval", "REPS_EVAL"),
           ("why3", "why3-QX", "why3 execute", "REPS_EXEC"),
           ("fstar", "fstar-QN", "assert_norm (normaliser; extra mode)", "REPS_NORM")]
    nc = len(ids)
    for d, lab, mode, rk in inp:
        tt = times(f"{out}/{d}/times.tsv")
        q = tt.get(lab, {}); q0 = tt.get(f"{d}-Q0", {})
        if not q:
            continue
        r = int(reps[rk]) if rk else 1
        diffs = [q[run][1] - q0[run][1] for run in q if run in q0]
        st = ",".join(str(x[0]) for x in q.values())
        cps = r * nc / med(diffs) if med(diffs) > 0 else float("nan")
        e2e = 1 / (1 / gparse + 1 / cps) if gparse else cps
        P(f"| {d} | {mode} | {r} | {r * nc} | {med([x[1] for x in q.values()]):.2f} | "
          f"{med([x[1] for x in q0.values()]):.2f} | {cps:.0f} | {1e6 / e2e:.1f} | "
          f"{max(x[2] for x in q.values()) / 1024:.0f} | {', '.join(x[3] for _, x in sorted(q.items()))}"
          f"{'' if set(st.split(',')) == {'0'} else ' (status ' + st + ')'} |")
    P("")

    # ---- T_spec -------------------------------------------------------
    P("## T_spec (milestone 1)\n")
    P("| Prover, target | Step | Median s | Runs s | Peak RSS MB | Load (1 min) per run | Status |")
    P("|----------------|------|---------:|--------|------------:|----------------------|--------|")
    steps = {"rocq": ["rocq-check", "rocq-extract", "rocq-ocamlopt"],
             "lean": ["lean-check", "lean-emit-c", "lean-cc"],
             "why3": ["why3-typecheck", "why3-vcgen", "why3-extract-ocaml", "why3-ocamlopt"],
             "fstar": ["fstar-check", "fstar-extract-ocaml", "fstar-ocamlopt"]}
    totals = {}
    for d, ls in steps.items():
        tt = times(f"{out}/{d}/times.tsv")
        tot = 0
        for lab in ls:
            q = {r: v for r, v in tt.get(lab, {}).items() if r in ("1", "2", "3")}
            if not q:
                continue
            m = med([x[1] for x in q.values()])
            if lab != "lean-check":   # lean-emit-c re-elaborates: check is included in it
                tot += m
            P(f"| {d} | {lab} | {m:.2f} | {', '.join('%.2f' % x[1] for _, x in sorted(q.items()))} | "
              f"{max(x[2] for x in q.values()) / 1024:.0f} | {', '.join(x[3] for _, x in sorted(q.items()))} | "
              f"{','.join(str(x[0]) for _, x in sorted(q.items()))} |")
        totals[d] = tot
    P("\nT_spec (sum of medians; Lean: emit-c includes elaboration, as experiment #7 counted it; "
      "Why3: type check + extraction + compile, VC generation listed apart):\n")
    for d, v in totals.items():
        if d == "why3":
            tt = times(f"{out}/why3/times.tsv")
            vc = med([x[1] for r, x in tt.get("why3-vcgen", {}).items()])
            v -= vc
        P(f"- {d}: {v:.2f} s")
    P("")

    # ---- experiment #7 idle rerun ---------------------------------------
    e7 = f"{out}/e07"
    if os.path.isdir(e7):
        P("## Experiment #7 T_table, idle rerun (runs 11-13)\n")
        P("| Label | Median s | Runs s | Peak RSS MB | Load (1 min) per run | Status |")
        P("|-------|---------:|--------|------------:|----------------------|--------|")
        for d in sorted(os.listdir(e7)):
            tt = times(f"{e7}/{d}/times.tsv")
            for lab, q in tt.items():
                P(f"| {lab} | {med([x[1] for x in q.values()]):.2f} | "
                  f"{', '.join('%.2f' % x[1] for _, x in sorted(q.items()))} | "
                  f"{max(x[2] for x in q.values()) / 1024:.0f} | "
                  f"{', '.join(x[3] for _, x in sorted(q.items()))} | "
                  f"{','.join(str(x[0]) for _, x in sorted(q.items()))} |")


if __name__ == "__main__":
    main()
