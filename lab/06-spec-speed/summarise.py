#!/usr/bin/env python3
"""Experiment #6: summarise milestone 1 (cases, agreement, throughput,
T_spec, experiment #7's idle rerun) as Markdown tables.

usage: python3 -I summarise.py DATA OUT
  DATA holds all.tsv, verdicts.tsv, in.tsv, in-ext.tsv, ids.txt, reps.env
  OUT holds g/, rocq/, lean/, why3/, fstar/, verus/, isabelle/ (each with
  times.tsv, throughput-lines.txt and, for the provers, verdicts.txt)
  and e07/ for experiment #7's idle rerun

Rerunning from the committed data (lab/results/2026-11-20-exp-06-raw/):
every input is committed except all.tsv, which is deterministic and is
regenerated first from the pinned submodule:

  R=lab/results/2026-11-20-exp-06-raw
  python3 -I lab/06-spec-speed/cases/extract.py upstream > <workdir>/all.tsv
  cp $R/verdicts.tsv $R/in.tsv $R/in-ext.tsv $R/ids.txt $R/reps.env <workdir>/
  python3 -I lab/06-spec-speed/summarise.py <workdir> $R

(4,565 cases, sha256 d0386ccf...ecc88f; verdicts.tsv, in.tsv and
in-ext.tsv can likewise be regenerated with `g classify`, see
g/g.ml.)  The search_cps, parse_cps and e2e_cps figures are read from
<tool>/throughput-lines.txt, the `grep cps=` condensation of the per-run
logs <label>.<run>.log (one line per run, prefixed "<label>.<run>.log:";
the per-run logs themselves are not committed).
"""
import sys, os, re, statistics
from collections import Counter, defaultdict

TOOLS = ["rocq", "lean", "why3", "fstar", "verus", "isabelle"]


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


def throughput_lines(path):
    """(label, run) -> the cps= lines of <label>.<run>.log, read from the
    committed condensation throughput-lines.txt ("<label>.<run>.log:<line>")"""
    t = defaultdict(list)
    if not os.path.exists(path):
        return t
    for l in open(path):
        m = re.match(r"(.+)\.(\d+)\.log:(.*)$", l.rstrip("\n"))
        if m and "cps=" in m.group(3):
            t[(m.group(1), m.group(2))].append(m.group(3))
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
            ("fstar", "fstar-extracted", "F*, extracted OCaml"),
            ("verus", "verus-compiled", "Verus, compiled Rust"),
            ("isabelle", "isabelle-export-code-exe", "Isabelle/HOL, export_code OCaml")]
    gparse = None
    for d, lab, name in labs:
        tt = times(f"{out}/{d}/times.tsv").get(lab, {})
        tl = throughput_lines(f"{out}/{d}/throughput-lines.txt")
        vals = defaultdict(list)
        for run in tt:
            for l in tl.get((lab, run), []):
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
        if d != "g" and gparse:
            ec = 1 / (1 / gparse + 1 / sc)   # stack G parse + prover search
        e6 = 1e6 / ec
        mode = {"g": "native", "verus": "compiled"}.get(d, "extracted")
        P(f"| {name} | {mode} | {reps} | "
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
           ("fstar", "fstar-QNc", "assert_norm (normaliser; extra mode)", "REPS_NORM"),
           ("isabelle", "isabelle-QV", "value [code] (fold under 10 s, see QVL)", "REPS_VALUE"),
           ("isabelle", "isabelle-QVL", "value [code]", "REPS_VALUE_L")]
    nc = len(ids)
    for d, lab, mode, rk in inp:
        tt = times(f"{out}/{d}/times.tsv")
        q = tt.get(lab, {})
        q0 = tt.get(f"{d}-Q0" + ("c" if lab.endswith("c") else "L" if lab.endswith("L") else ""), {})
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
             "fstar": ["fstar-check", "fstar-extract-ocaml", "fstar-ocamlopt"],
             "verus": ["verus-check", "verus-rustc"],
             "isabelle": ["isabelle-check-base", "isabelle-check", "isabelle-export-code",
                          "isabelle-ocamlopt"]}
    totals = {}
    for d, ls in steps.items():
        tt = times(f"{out}/{d}/times.tsv")
        tot = 0
        for lab in ls:
            q = {r: v for r, v in tt.get(lab, {}).items() if r in ("1", "2", "3")}
            if not q:
                continue
            m = med([x[1] for x in q.values()])
            if lab not in ("lean-check", "isabelle-check-base"):   # lean-emit-c re-elaborates: check is included in it
                tot += m
            P(f"| {d} | {lab} | {m:.2f} | {', '.join('%.2f' % x[1] for _, x in sorted(q.items()))} | "
              f"{max(x[2] for x in q.values()) / 1024:.0f} | {', '.join(x[3] for _, x in sorted(q.items()))} | "
              f"{','.join(str(x[0]) for _, x in sorted(q.items()))} |")
        totals[d] = tot
    P("\nT_spec (sum of medians; Lean: emit-c includes elaboration, as experiment #7 counted it; "
      "Why3: type check + extraction + compile, VC generation listed apart; Verus: verification "
      "+ rustc, no extraction step; Isabelle: session builds include JVM start and HOL-Library "
      "loading, isabelle-check-base is that overhead alone and is excluded from the sum):\n")
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




# ---- experiment #7's verdicts against milestone 1's T_spec -------------
# T_table per target as experiment #7 defined it
# (lab/results/2026-11-19-exp-07-extraction.md), loaded figures from there
E07_TARGETS = [
    ("Rocq -> OCaml", "rocq", ["rocq-check", "rocq-extract", "rocq-ocamlopt"], 85.97, "rocq"),
    ("Lean -> C -> native", "lean", ["lean-emit-c", "lean-cc", "lean-link"], 95.38, "lean"),
    ("Why3 -> OCaml", "why3", ["why3-typecheck", "why3-extract-ocaml", "why3-ocamlopt"], 24.45, "why3"),
    ("Why3 -> C (decision trees)", "why3", ["why3c-typecheck", "why3c-extract-c", "why3c-gcc"], 20.19, "why3"),
    ("F* -> OCaml", "fstar", ["fstar-check", "fstar-extract-ocaml", "fstar-ocamlopt"], 60.32, "fstar"),
    ("F* -> KaRaMeL C (decision trees)", "fstar",
     ["fstarc-check", "fstarc-extract-krml", "fstarc-krml", "fstarc-gcc-krml"], 73.99, "fstar"),
    ("F* -> direct C (decision trees)", "fstar", ["fstarc-check", "fstarc-extract-c", "fstarc-gcc-c"], 65.49, "fstar"),
    ("F*/Pulse -> KaRaMeL C (static arrays)", "pulse",
     ["pulse-check", "pulse-extract-krml", "pulse-krml", "pulse-gcc-krml"], 175.31, "fstar"),
    ("F*/Pulse -> direct C (static arrays)", "pulse", ["pulse-check", "pulse-extract-c", "pulse-gcc-c"], 172.78, "fstar"),
]
TSPEC_STEPS = {"rocq": ["rocq-check", "rocq-extract", "rocq-ocamlopt"],
               "lean": ["lean-emit-c", "lean-cc"],
               "why3": ["why3-typecheck", "why3-extract-ocaml", "why3-ocamlopt"],
               "fstar": ["fstar-check", "fstar-extract-ocaml", "fstar-ocamlopt"]}


def settle(out):
    P = print
    e7 = f"{out}/e07"
    P("## Experiment #7's T_table at idle against milestone 1's T_spec\n")
    P("| Target | T_table loaded s (#7) | T_table idle s (runs 11-13) | Idle / loaded | "
      "Load (1 min) idle runs | T_spec s (milestone 1) | T_table idle / T_spec | Verdict |")
    P("|--------|------:|------:|------:|------|------:|------:|------|")
    for name, d, labs, loaded, sp in E07_TARGETS:
        tt = times(f"{e7}/{d}/times.tsv")
        idle = sum(med([x[1] for r, x in tt.get(l, {}).items()]) for l in labs)
        loads = sorted({x[3] for l in labs for x in tt.get(l, {}).values()})
        ts = times(f"{out}/{sp}/times.tsv")
        tspec = sum(med([x[1] for r, x in ts.get(l, {}).items() if r in ("1", "2", "3")])
                    for l in TSPEC_STEPS[sp])
        verdict = "in-prover (settled)" if idle <= tspec else "open (#7's provisional verdict stands)"
        P(f"| {name} | {loaded:.2f} | {idle:.2f} | {idle / loaded:.2f} | {loads[0]}-{loads[-1]} | "
          f"{tspec:.2f} | {idle / tspec:.0f} | {verdict} |")


if __name__ == "__main__":
    main()
    if os.path.isdir(f"{sys.argv[2]}/e07"):
        print()
        settle(sys.argv[2])
