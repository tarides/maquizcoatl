#!/usr/bin/env python3
"""Issue #22 driver on the bench host, built on experiment #12's run.py
(stdlib only, run with -I).

  EXP=<exp> python3 -I run22.py prepare RUNID   work files (experiment #12's
                                                prep.py, classify, pick_large;
                                                then prep22.py)
  EXP=<exp> python3 -I run22.py checks RUNID    plan step 6 (i)-(iii)
  EXP=<exp> python3 -I run22.py agree RUNID     plan step 7
  EXP=<exp> python3 -I run22.py conv RUNID [RUNS]   plan step 8
  EXP=<exp> python3 -I run22.py pilot RUNID     plan step 9 (writes pilot.json)
  EXP=<exp> python3 -I run22.py short RUNID [RUNS]
  EXP=<exp> python3 -I run22.py large RUNID [RUNS] [NPAT]   (NPAT: top ranks kept per source)
  EXP=<exp> python3 -I run22.py cata RUNID [RUNS]
  EXP=<exp> python3 -I run22.py catafuel RUNID [RUNS]
  EXP=<exp> python3 -I run22.py repeat RUNID short|large   noisy cells, 10 more runs

Untimed jobs: nice -n 10, taskset -c 0-3,32-35, at most 4 in parallel.
Timed processes: taskset -c 2, one at a time; before each timed series
the threads on CPU 2 are listed (ps -eLo user,psr,pcpu,comm) and the
series waits while another process uses it.  Output goes to
<exp>/out/RUNID/ and contains no absolute path or host name.
"""
import csv, hashlib, importlib.util, json, os, random, statistics, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

EXP = os.environ["EXP"]
REPO = os.path.join(EXP, "repo")
LAB12 = os.path.join(REPO, "lab", "12-ffi-vs-native")
LAB22 = os.path.join(REPO, "lab", "22-extracted-ocaml")
CASES = os.path.join(REPO, "lab", "09-representative-proof", "cases")
RES = os.path.join(REPO, "lab", "results")
DATA = os.path.join(REPO, "experiments", "01-pattern-inventory", "workloads", "data")
BIN = os.path.join(EXP, "bin")
SUBJ = os.path.join(EXP, "subjects")
UNTIMED = ["nice", "-n", "10", "taskset", "-c", "0-3,32-35"]

os.environ.pop("ENGINES_ONLY", None)
_spec = importlib.util.spec_from_file_location("run12", os.path.join(LAB12, "run.py"))
R = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(R)
R.BUILDSET = UNTIMED
R.BIN = BIN
R.SUBJ = SUBJ
ALL = ["c", "c-noopt", "stubs", "ctypes", "vm", "rocq", "rocq-scan", "fstar", "fstar-scan"]
R.ENGINES = {
    "c": ("cdriver", None), "c-noopt": ("cdriver-noopt", None),
    "stubs": ("main-ffi.exe", "stubs"), "ctypes": ("main-ffi.exe", "ctypes"),
    "vm": ("main-ffi.exe", "vm"),
    "rocq": ("main-ffi.exe", "rocq"), "rocq-scan": ("main-ffi.exe", "rocq-scan"),
    "fstar": ("main-ffi.exe", "fstar"), "fstar-scan": ("main-ffi.exe", "fstar-scan"),
}
# decision 3: the two catastrophic patterns inside the fragment
R.CATA = [("jq-frag", 2, 256, "(aa*)*b"), ("php-frag", 1, 12, "(a|aa)*b")]
FUEL = 10_000_000          # cata-fuel: fuel per start position
FAMILIES = ["jq", "php", "vscode", "longphp"]
BASE = ["c", "stubs", "ctypes", "vm"]
X22 = os.path.join(BIN, "x22.exe")
REF = {  # experiment #9's reference verdicts (plan, "Decisions folded in")
    ("rocq", "fragment"): "2026-11-25-exp-09-correction-1-raw/rocq/fragment.verdicts.txt",
    ("rocq", "extra"): "2026-11-25-exp-09-raw/rocq/extra.verdicts.txt",
    ("fstar", "fragment"): "2026-11-25-exp-09-fstar-m1-raw/fstar/fragment.verdicts.txt",
    ("fstar", "extra"): "2026-11-25-exp-09-fstar-m1-raw/fstar/extra.verdicts.txt",
}


def out(runid, *p):
    d = os.path.join(EXP, "out", runid)
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, *p)


def sh(argv, prefix=UNTIMED, stdout=None, timeout=None):
    return R.run([str(a) for a in argv], prefix=prefix, stdout=stdout, timeout=timeout)


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


# ---------------------------------------------------------------- prepare

def prepare(runid):
    w12 = out(runid, "work12")
    os.makedirs(w12, exist_ok=True)
    py = ["python3", "-I"]
    main = os.path.join(BIN, "main-ffi.exe")
    r = sh(py + [os.path.join(LAB12, "prep.py"), DATA, w12])
    assert r.returncode == 0, r.stderr
    for fam in FAMILIES:
        r = sh([main, "classify", f"{w12}/{fam}.all.work", f"{w12}/{fam}.work",
                f"{w12}/{fam}.coverage.tsv"])
        assert r.returncode == 0, r.stderr
    r = sh(py + [os.path.join(LAB12, "pick_large.py"), "cand", w12])
    assert r.returncode == 0, r.stderr
    for src in ["log", "src"]:
        with open(os.path.join(w12, f"largeok.{src}"), "w") as f:
            sh([main, "largeok", os.path.join(SUBJ, f"{src}-16m"), f"{w12}/cand.work"], stdout=f)
    r = sh(py + [os.path.join(LAB12, "pick_large.py"), "pick", w12, "16"])
    assert r.returncode == 0, r.stderr
    # experiment #12's work files are reproduced byte for byte
    ref = dict(reversed(l.split()) for l in
               open(os.path.join(RES, "2026-11-19-exp-12-raw", "work", "work-files.sha256")))
    lines = []
    for name, h in sorted(ref.items()):
        if "agreed" in name:
            continue
        got = sha(os.path.join(w12, name))
        lines.append(f"{name} {'same' if got == h else 'DIFFERENT ' + got}")
    same_list = open(os.path.join(w12, "large.list")).read() == \
        open(os.path.join(RES, "2026-11-19-exp-12-raw", "work", "large.list")).read()
    lines.append(f"large.list {'same' if same_list else 'DIFFERENT'}")
    open(out(runid, "work12-check.txt"), "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))
    r = sh(py + [os.path.join(LAB22, "prep22.py"), os.path.join(CASES, "select.py"), w12,
                 out(runid, "work")])
    print(r.stdout)
    assert r.returncode == 0, r.stderr


# ---------------------------------------------------------------- checks

def checks(runid):
    d = out(runid, "checks")
    os.makedirs(d, exist_ok=True)
    wd = out(runid, "work")
    ok = True
    res = []
    r = sh([X22, "astcheck", os.path.join(CASES, "fragment.tsv"), os.path.join(CASES, "extra.tsv")])
    open(os.path.join(d, "astcheck.txt"), "w").write(r.stdout)
    res.append(f"(i) astcheck rc={r.returncode} {r.stdout.strip().splitlines()[-1]}")
    ok &= r.returncode == 0
    for fam in FAMILIES + ["large"]:
        work = f"{wd}/{fam}.frag.work" if fam != "large" else f"{wd}/large.work"
        r = sh([X22, "astwork", work, f"{wd}/{fam}.ast.tsv"])
        open(os.path.join(d, f"astwork.{fam}.txt"), "w").write(r.stdout)
        res.append(f"(ii) astwork {fam} rc={r.returncode} {r.stdout.strip().splitlines()[-1]}")
        ok &= r.returncode == 0
    for eng in ["rocq", "fstar"]:
        for cs in ["fragment", "extra"]:
            r = sh([X22, "verdicts", eng, os.path.join(CASES, f"{cs}.tsv")])
            mine = r.stdout
            open(os.path.join(d, f"verdicts.{eng}.{cs}.txt"), "w").write(mine)
            ref = "".join(l for l in open(os.path.join(RES, REF[(eng, cs)])) if l.split("\t")[2] == "vm")
            same = r.returncode == 0 and mine == ref
            res.append(f"(iii) verdicts {eng} {cs}: {len(mine.splitlines())} vm lines, reference "
                       f"{len(ref.splitlines())} lines ({REF[(eng, cs)].split('/')[0]}): "
                       f"{'identical' if same else 'DIFFERENT'}")
            ok &= same
    res.append("CHECKS " + ("PASS" if ok else "FAIL"))
    open(os.path.join(d, "summary.txt"), "w").write("\n".join(res) + "\n")
    print("\n".join(res))
    sys.exit(0 if ok else 1)


# ---------------------------------------------------------------- agreement

def agree(runid):
    wd = out(runid, "work")
    ag = out(runid, "agree")
    os.makedirs(ag, exist_ok=True)
    engines = BASE + ["rocq", "fstar"]
    jobs = [(fam, e) for fam in FAMILIES for e in engines] + \
        [("longphp", "rocq-scan"), ("longphp", "fstar-scan")]

    def one(j):
        fam, eng = j
        with open(os.path.join(ag, f"{fam}.{eng}"), "w") as f:
            r = sh(R.cmd(eng, "agree", f"{wd}/{fam}.frag.work"), stdout=f)
        return fam, eng, r.returncode
    with ThreadPoolExecutor(4) as ex:
        rcs = list(ex.map(one, jobs))
    lines = [f"agree {fam} {eng} rc={rc}" for fam, eng, rc in rcs]
    for fam in FAMILIES:
        rd = lambda e: dict(l.rstrip("\n").split(" ", 1) for l in open(os.path.join(ag, f"{fam}.{e}")))
        c = rd("c")
        others = {e: rd(e) for e in engines if e != "c"}
        if fam == "longphp":
            others.update({e: rd(e) for e in ["rocq-scan", "fstar-scan"]})
        limit = {k for k, v in c.items() if v.split()[0] in ("-15", "-17", "-18")}
        bad = {e: {k for k in c if o.get(k) != c[k]} for e, o in others.items()}
        drop = limit.union(*bad.values())
        n = 0
        with open(os.path.join(wd, f"{fam}.agreed.work"), "w") as w:
            for l in open(os.path.join(wd, f"{fam}.frag.work")):
                if l.startswith("C ") and l.split()[1] in drop:
                    continue
                n += l.startswith("C ")
                w.write(l)
        lines.append(f"{fam}: calls {len(c)}, C limit code {len(limit)}, "
                     + ", ".join(f"{e} != C {len(b)}" for e, b in bad.items())
                     + f", agreed {n}")
    open(out(runid, "agree.txt"), "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))


# ---------------------------------------------------------------- CPU 2 check

def cpu2_util(sec=2.0):
    """Utilisation of CPU 2 over sec seconds (/proc/stat), in percent."""
    def read():
        for l in open("/proc/stat"):
            if l.startswith("cpu2 "):
                v = [int(x) for x in l.split()[1:]]
                return sum(v), v[3] + v[4]
    t0, i0 = read()
    time.sleep(sec)
    t1, i1 = read()
    return 100.0 * (1 - (i1 - i0) / max(1, t1 - t0))


def cpu2_busy():
    """Threads on CPU 2 (ps -eLo user,psr,pcpu,comm) with a CPU share of
    5% or more, and the measured utilisation of CPU 2.  Other accounts'
    threads are counted, never named."""
    ps = subprocess.run(["ps", "-eLo", "user,psr,pcpu,comm"], capture_output=True, text=True).stdout
    mine, other = [], 0
    for l in ps.splitlines()[1:]:
        f = l.split(None, 3)
        if len(f) == 4 and f[1] == "2" and float(f[2]) >= 5.0:
            if f[0] == os.environ.get("USER"):
                mine.append(f"{f[3]}:{f[2]}")
            else:
                other += 1
    return mine, other, cpu2_util()


def wait_cpu2(d, tag):
    """Wait (up to 30 minutes) until CPU 2 is idle; log each check."""
    t0 = time.time()
    while True:
        mine, other, util = cpu2_busy()
        # ps's pcpu is a lifetime share: a thread listed there is busy
        # only when CPU 2 is also measured in use
        busy = util > 20.0 or ((other > 0 or bool(mine)) and util > 5.0)
        with open(os.path.join(d, "cpu2.log"), "a") as f:
            f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} {tag} "
                    f"load={' '.join(open('/proc/loadavg').read().split()[:3])} "
                    f"cpu2_util={util:.1f}% own_threads={mine} other_account_threads={other} "
                    f"{'BUSY' if busy else 'idle'}\n")
        if not busy or time.time() - t0 > 1800:
            return
        time.sleep(30)


def series22(kind, runs, cells, fn, keys, extra_cols, prefilter=None):
    """run.py's series, with capped rows stopped for any catastrophic kind."""
    d = R.EXP_OUT
    path = os.path.join(d, f"{kind}.csv")
    new = not os.path.exists(path)
    f = open(path, "a", newline="")
    w = csv.writer(f)
    if new:
        w.writerow(["run", "seed", "order"] + extra_cols + ["rc", "wall"] + keys)
    R.log_conditions(d, f"{kind}-start")
    capped = set()
    for r in range(1, runs + 1):
        order = list(cells)
        random.Random(r).shuffle(order)
        for i, cell in enumerate(order):
            if prefilter and not prefilter(cell, capped):
                continue
            kv, rc, wall = fn(*cell)
            if kv.get("outcome") == "cap":
                capped.add(cell)
            w.writerow([r, r, i] + list(cell) + [rc, f"{wall:.3f}"] + [kv.get(k, "") for k in keys])
            f.flush()
        R.log_conditions(d, f"{kind}-run{r}")
    R.log_conditions(d, f"{kind}-end")
    f.close()


# ---------------------------------------------------------------- conversion cost

def run_conv(eng, fam, minsec=0.5):
    t0 = time.time()
    r = sh([X22, "conv", eng, f"{R.EXP_OUT}/work/{fam}.agreed.work", minsec], prefix=R.TIMED, timeout=120)
    kv = R.parse_kv(r.stdout.strip()) if r.returncode == 0 else {}
    return kv, r.returncode, time.time() - t0


def conv(runid, runs):
    d = out(runid)
    wait_cpu2(d, "conv")
    cells = [(e, f) for e in ["rocq", "fstar"] for f in FAMILIES]
    R.series("conv", runs, cells, run_conv,
             ["cases", "calls_per_pass", "bytes_per_pass", "passes", "sec", "ns_per_call",
              "ns_per_byte", "minor_per_call", "major_per_call"], ["engine", "family"])
    with open(out(runid, "conv-subject.txt"), "w") as f:
        for eng in ["rocq", "fstar"]:
            for s in ["log-1m", "src-1m", "log-16m", "src-16m"]:
                r = sh([X22, "conv-subject", eng, os.path.join(SUBJ, s)], prefix=R.TIMED, timeout=120)
                f.write(f"subject={s} rc={r.returncode} {r.stdout.strip()}\n")
    print(open(out(runid, "conv-subject.txt")).read())


# ---------------------------------------------------------------- cells

def short_cells():
    cells = []
    for e in BASE + ["rocq", "fstar"]:
        for f in FAMILIES:
            # long PHP: the large shape's labelled synthetic row, scan mode
            cells.append((e + "-scan" if f == "longphp" and e in ("rocq", "fstar") else e, f))
    return cells


def large_cells(fallback, npat=None):
    """npat: experiment #12's reduction rule (patterns removed from the
    bottom of each source's ranking, rank kept), when the whole run
    projects over its 4 hours."""
    rows = [l.split() for l in open(os.path.join(R.EXP_OUT, "work", "large.list"))][1:]
    cells = []
    for src, rank, pid, fam, calls, hx in rows:
        if npat is not None and int(rank) > npat:
            continue
        for size in ["1m", "16m"]:
            for e in BASE + ["rocq-scan", "fstar-scan"]:
                if fallback and size == "16m" and e.endswith("-scan"):
                    continue
                cells.append((e, src, size, int(pid)))
    return cells


LENGTHS = R.CATA_LENGTHS


def cata_cells(comparable):
    cells = [(e, fam, n) for e in ["c", "c-noopt"] + BASE[1:] for (fam, _, _, _) in R.CATA for n in LENGTHS]
    for e in ["rocq", "fstar"]:
        for (fam, _, _, _) in R.CATA:
            for n in [16] + [n for (f, n) in comparable if f == fam]:
                cells.append((e, fam, n))
    return cells


def catafuel_cells(comparable):
    return [(e, fam, n) for e in ["rocq", "fstar"] for (fam, _, _, _) in R.CATA
            for n in LENGTHS if n >= 32 and (fam, n) not in comparable]


def run_catafuel(eng, fam, n):
    _, syn, opt, pat = next(c for c in R.CATA if c[0] == fam)
    t0 = time.time()
    r = sh([X22, "cata-fuel", eng, syn, opt, pat.encode().hex(), n, FUEL], prefix=R.TIMED, timeout=60)
    if r.returncode == 124:
        kv = {"outcome": "cap", "sec": "60"}
    else:
        kv = R.parse_kv(r.stdout.strip()) if r.returncode == 0 else {}
    return kv, r.returncode, time.time() - t0


def cata_prefilter(cell, capped):
    e, fam, n = cell
    return not any(c[0] == e and c[1] == fam and c[2] < n for c in capped)


def load_pilot():
    p = json.load(open(os.path.join(R.EXP_OUT, "pilot.json")))
    return p["fallback"], {tuple(x) for x in p["comparable"]}


# ---------------------------------------------------------------- pilot

def pilot(runid):
    d = R.EXP_OUT
    wait_cpu2(d, "pilot")
    R.log_conditions(d, "pilot-start")
    tot = {"short": 0.0, "large": 0.0, "cata": 0.0, "catafuel": 0.0}
    f = open(os.path.join(d, "pilot.txt"), "w")

    def log(s):
        f.write(s + "\n")
        f.flush()
        print(s, flush=True)
    for c in short_cells():
        kv, rc, wall = R.run_short(*c)
        tot["short"] += wall
        log(f"short {c} rc={rc} wall={wall:.2f} ns_per_call={kv.get('ns_per_call')}")
    # large: every 1 MiB cell and the baselines' 16 MiB cells first
    one_m = {}
    deferred = []
    for c in large_cells(False):
        e, src, size, pid = c
        if size == "16m" and e.endswith("-scan"):
            deferred.append(c)
            continue
        kv, rc, wall = R.run_large(*c)
        tot["large"] += wall
        if size == "1m":
            one_m[(e, src, pid)] = (wall, rc)
        log(f"large {c} rc={rc} wall={wall:.2f} Bps={kv.get('bytes_per_sec')} m={kv.get('matches')}")
    proj16 = {c: 16 * one_m[(c[0], c[1], c[3])][0] for c in deferred}
    large_proj = 10 * (tot["large"] + sum(proj16.values())) * 1.1
    log(f"projection: extracted 16 MiB cells, 16 x 1 MiB wall: {sum(proj16.values()):.0f} s in all, "
        f"max {max(proj16.values()):.0f} s; large series 10 x pilot x 1.1 = {large_proj / 60:.1f} min")
    fallback = large_proj > 90 * 60
    if fallback:
        log("decision 4 applies: extracted columns at 1 MiB only (projection over 90 minutes)")
    else:
        for c in deferred:
            if proj16[c] >= 120:
                log(f"large {c} not run in the pilot: projected {proj16[c]:.0f} s >= 120 s timeout")
                continue
            kv, rc, wall = R.run_large(*c)
            tot["large"] += wall
            log(f"large {c} rc={rc} wall={wall:.2f} Bps={kv.get('bytes_per_sec')} m={kv.get('matches')}")
    # catastrophic: baselines and the n = 16 extracted cells; decision 6
    # lengths from c-noopt (deterministic retry count)
    capped = set()
    noopt = {}
    for c in cata_cells(set()):
        if not cata_prefilter(c, capped):
            continue
        kv, rc, wall = R.run_cata(*c)
        tot["cata"] += wall
        if kv.get("outcome") == "cap":
            capped.add(c)
        if c[0] == "c-noopt":
            noopt[(c[1], c[2])] = kv.get("outcome")
        log(f"cata {c} rc={rc} wall={wall:.2f} {kv.get('outcome')} {kv.get('sec')}")
    comparable = sorted((fam, n) for (fam, n), o in noopt.items() if n >= 32 and o in ("nomatch", "match"))
    log(f"decision 6: c-noopt completes under its budget at n >= 32 for {comparable}")
    for c in cata_cells(set(comparable)):
        if c[0] in ("rocq", "fstar") and c[2] >= 32:
            kv, rc, wall = R.run_cata(*c)
            tot["cata"] += wall
            log(f"cata {c} rc={rc} wall={wall:.2f} {kv.get('outcome')} {kv.get('sec')}")
    capped = set()
    for c in catafuel_cells(set(comparable)):
        if not cata_prefilter(c, capped):
            continue
        kv, rc, wall = run_catafuel(*c)
        tot["catafuel"] += wall
        if kv.get("outcome") == "cap":
            capped.add(c)
        log(f"catafuel {c} rc={rc} wall={wall:.2f} {kv.get('outcome')} {kv.get('sec')}")
    proj = {k: 10 * v * 1.1 / 60 for k, v in tot.items()}
    if not fallback:
        proj["large"] = large_proj / 60
    log(f"TOTAL one run per cell (s): { {k: round(v, 1) for k, v in tot.items()} }")
    log(f"PROJECTION 10 runs + 10% (min): { {k: round(v, 1) for k, v in proj.items()} }; "
        f"total {sum(proj.values()):.1f} min")
    json.dump({"fallback": fallback, "comparable": comparable, "projection_min": proj},
              open(os.path.join(d, "pilot.json"), "w"))
    R.log_conditions(d, "pilot-end")


# ---------------------------------------------------------------- noisy cells

def repeat(runid, kind, runs=10):
    rows = list(csv.DictReader(open(os.path.join(R.EXP_OUT, f"{kind}.csv"))))
    key = ["engine", "family"] if kind == "short" else ["engine", "source", "size", "pid"]
    val = "ns_per_call" if kind == "short" else "bytes_per_sec"
    cells = {}
    for r in rows:
        if r["rc"] == "0" and r[val]:
            cells.setdefault(tuple(r[k] for k in key), []).append(float(r[val]))
    noisy = []
    for k, xs in cells.items():
        qs = statistics.quantiles(xs, n=4, method="inclusive")
        if qs[2] - qs[0] > 0.1 * statistics.median(xs):
            noisy.append(k if kind == "short" else (k[0], k[1], k[2], int(k[3])))
    print(f"{kind}: {len(noisy)} noisy cells: {noisy}")
    if not noisy:
        return
    wait_cpu2(R.EXP_OUT, f"{kind}-repeat")
    fn = R.run_short if kind == "short" else R.run_large
    keys = (["cases", "skipped", "calls_per_pass", "passes", "sec", "ns_per_call", "minor_per_call",
             "major_per_call"] if kind == "short" else
            ["bytes", "matches", "err", "scans", "sec_per_scan", "bytes_per_sec", "minor_per_match",
             "major_per_match"])
    R.series(f"{kind}-repeat", runs, noisy, fn, keys, key)


def main():
    what, runid = sys.argv[1], sys.argv[2]
    R.EXP_OUT = out(runid)
    runs = int(sys.argv[3]) if len(sys.argv) > 3 and what != "repeat" else 10
    if what == "prepare":
        prepare(runid)
    elif what == "checks":
        checks(runid)
    elif what == "agree":
        agree(runid)
    elif what == "conv":
        conv(runid, runs)
    elif what == "pilot":
        pilot(runid)
    elif what == "short":
        wait_cpu2(R.EXP_OUT, "short")
        R.series("short", runs, short_cells(), R.run_short,
                 ["cases", "skipped", "calls_per_pass", "passes", "sec", "ns_per_call",
                  "minor_per_call", "major_per_call"], ["engine", "family"])
    elif what == "large":
        fallback, _ = load_pilot()
        wait_cpu2(R.EXP_OUT, "large")
        npat = int(sys.argv[4]) if len(sys.argv) > 4 else None
        R.series("large", runs, large_cells(fallback, npat), R.run_large,
                 ["bytes", "matches", "err", "scans", "sec_per_scan", "bytes_per_sec",
                  "minor_per_match", "major_per_match"], ["engine", "source", "size", "pid"])
    elif what == "cata":
        _, comparable = load_pilot()
        wait_cpu2(R.EXP_OUT, "cata")
        R.series("cata", runs, cata_cells(comparable), R.run_cata, ["n", "result", "outcome", "sec"],
                 ["engine", "family", "len"], prefilter=cata_prefilter)
    elif what == "catafuel":
        _, comparable = load_pilot()
        wait_cpu2(R.EXP_OUT, "catafuel")
        series22("catafuel", runs, catafuel_cells(comparable), run_catafuel,
                 ["n", "fuel", "result", "outcome", "sec"], ["engine", "family", "len"],
                 prefilter=cata_prefilter)
    elif what == "repeat":
        repeat(runid, sys.argv[3])


if __name__ == "__main__":
    main()
