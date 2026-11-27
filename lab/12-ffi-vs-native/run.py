#!/usr/bin/env python3
"""Experiment #12 driver on the bench host (stdlib only, run with -I).

  EXP=<exp> python3 -I run.py prepare RUNID   untimed steps 5-8 (+ pattern pick)
  EXP=<exp> python3 -I run.py pilot RUNID     one run per cell, durations
  EXP=<exp> python3 -I run.py short RUNID [RUNS]
  EXP=<exp> python3 -I run.py large RUNID [RUNS] [NPAT]
  EXP=<exp> python3 -I run.py cata RUNID [RUNS]

Untimed jobs run under taskset -c 0-3,32-35 (at most 4 in parallel);
timed processes run one at a time under taskset -c 2.  Output goes to
<exp>/out/RUNID/ and never contains absolute paths or host names.
"""
import csv, os, random, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

EXP = os.environ["EXP"]
BIN = os.path.join(EXP, "bin")
REPO = os.path.join(EXP, "repo")
LAB = os.path.join(REPO, "lab", "12-ffi-vs-native")
DATA = os.path.join(REPO, "experiments", "01-pattern-inventory", "workloads", "data")
SUBJ = os.path.join(EXP, "subjects")
BUILDSET = ["taskset", "-c", "0-3,32-35"]
TIMED = ["taskset", "-c", "2"]
FAMILIES = ["jq", "php", "vscode"]

# engine name -> (binary, engine argument or None for the C driver)
ENGINES = {
    "c": ("cdriver", None),
    "stubs": ("main-ffi.exe", "stubs"),
    "ctypes": ("main-ffi.exe", "ctypes"),
    "vm": ("main-ffi.exe", "vm"),
    "vm-flambda": ("main-ffi-flambda.exe", "vm"),
    "re": ("main-ffi.exe", "re"),
    # review fix (run r2): the C driver against a libonig.so built with
    # -DONIG_DONT_OPTIMIZE (setup.sh cbuild-noopt); not in the default set
    "c-noopt": ("cdriver-noopt", None),
    # issue #22: the extracted VMs (lab/22-extracted-ocaml); not in the
    # default set
    "rocq": ("main-ffi.exe", "rocq"),
    "rocq-scan": ("main-ffi.exe", "rocq-scan"),
    "fstar": ("main-ffi.exe", "fstar"),
    "fstar-scan": ("main-ffi.exe", "fstar-scan"),
}
EXTRA = ["c-noopt", "rocq", "rocq-scan", "fstar", "fstar-scan"]
# ENGINES_ONLY=c,c-noopt,vm restricts a series to these engines; the
# default is every engine but those of EXTRA (the run r1 set).
if os.environ.get("ENGINES_ONLY"):
    ENGINES = {k: ENGINES[k] for k in os.environ["ENGINES_ONLY"].split(",")}
else:
    for k in EXTRA:
        del ENGINES[k]

CATA = [  # experiment #11's worst-case entry, one per family
    ("jq", 2, 256, "(a+)+$"),
    ("php", 1, 12, "(a|aa)+$"),
    ("vscode", 0, 256, r"(\w+\s?)+$"),
]
CATA_LENGTHS = [16 << k for k in range(9)]   # 16 .. 4096
CATA_LIMIT = 10_000_000


def out_dir(runid):
    d = os.path.join(EXP, "out", runid)
    os.makedirs(d, exist_ok=True)
    return d


def cmd(engine, sub, *args):
    b, e = ENGINES[engine]
    argv = [os.path.join(BIN, b), sub]
    if e is not None:
        argv.append(e)
    return argv + [str(a) for a in args]


def run(argv, prefix=BUILDSET, timeout=None, stdout=None):
    full = prefix + (["timeout", str(timeout)] if timeout else []) + argv
    return subprocess.run(full, stdout=stdout or subprocess.PIPE, stderr=subprocess.PIPE,
                          text=True)


def parse_kv(line):
    return dict(f.split("=", 1) for f in line.split() if "=" in f)


def others_running():
    """Other experiments running on the host, by experiment number only."""
    try:
        ps = subprocess.run(["ps", "-eo", "args"], capture_output=True, text=True).stdout
    except Exception:
        return "?"
    found = set()
    import re
    for m in re.finditer(r"exp/(\d\d)-", ps):
        if m.group(1) != "12":
            found.add(int(m.group(1)))
    for m in re.finditer(r"(?:^|[/_ -])e(\d\d)(?:[/_ -]|$)", ps, re.M):
        if m.group(1) != "12":
            found.add(int(m.group(1)))
    return ",".join(f"#{n}" for n in sorted(found)) or "none-detected"


def conditions(tag):
    la = open("/proc/loadavg").read().split()[:3]
    try:
        gov = open("/sys/devices/system/cpu/cpu2/cpufreq/scaling_governor").read().strip()
    except OSError:
        gov = "?"
    return {"tag": tag, "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "load1": la[0], "load5": la[1], "load15": la[2], "cpu2_governor": gov,
            "others": others_running()}


def log_conditions(d, tag):
    c = conditions(tag)
    path = os.path.join(d, "conditions.csv")
    new = not os.path.exists(path)
    with open(path, "a", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(c))
        if new:
            w.writeheader()
        w.writerow(c)
    print("conditions", c, flush=True)
    return c


# ---------------------------------------------------------------- prepare

def prepare(runid):
    d = out_dir(runid)
    wd = os.path.join(d, "work")
    os.makedirs(wd, exist_ok=True)
    py = ["python3", "-I"]
    r = run(py + [os.path.join(LAB, "prep.py"), DATA, wd])
    assert r.returncode == 0, r.stderr
    vm = os.path.join(BIN, "main-ffi.exe")
    for fam in FAMILIES + ["longphp"]:
        r = run([vm, "classify", f"{wd}/{fam}.all.work", f"{wd}/{fam}.work",
                 f"{wd}/{fam}.coverage.tsv"])
        assert r.returncode == 0, r.stderr
    # criterion 1: test_utf8.c cases
    with open(os.path.join(d, "tests.cases"), "w") as f:
        r = run(py + [os.path.join(LAB, "subset", "select_tests.py"),
                      os.path.join(REPO, "upstream")], stdout=f)
    with open(os.path.join(d, "tests.out"), "w") as f:
        run([vm, "tests", os.path.join(d, "tests.cases")], stdout=f)
    # criterion 7: agreement (4 jobs in parallel)
    ag = os.path.join(d, "agree")
    os.makedirs(ag, exist_ok=True)
    jobs = []
    for fam in FAMILIES + ["longphp"]:
        for eng in ["c", "stubs", "ctypes", "vm", "vm-flambda", "re"]:
            jobs.append((fam, eng))

    def one(j):
        fam, eng = j
        with open(os.path.join(ag, f"{fam}.{eng}"), "w") as f:
            run(cmd(eng, "agree", f"{wd}/{fam}.work"), stdout=f)
    with ThreadPoolExecutor(4) as ex:
        list(ex.map(one, jobs))
    # agreed subsets for timing: drop cases where the VM disagrees with C
    for fam in FAMILIES + ["longphp"]:
        ref = dict(l.split(" ", 1) for l in open(os.path.join(ag, f"{fam}.c")))
        vm_ = dict(l.split(" ", 1) for l in open(os.path.join(ag, f"{fam}.vm")))
        bad = {k for k in ref if vm_.get(k) != ref[k]}
        with open(os.path.join(wd, f"{fam}.agreed.work"), "w") as w:
            for l in open(os.path.join(wd, f"{fam}.work")):
                if l.startswith("C ") and l.split()[1] in bad:
                    continue
                w.write(l)
    # step 8: allocation check, both switches + stubs + ctypes
    with open(os.path.join(d, "alloc.txt"), "w") as f:
        for eng in ["vm", "vm-flambda", "stubs", "ctypes"]:
            r = run(cmd(eng, "alloc", 1_000_000))
            f.write(r.stdout)
    # large-subject pattern candidates
    r = run(py + [os.path.join(LAB, "pick_large.py"), "cand", wd])
    assert r.returncode == 0, r.stderr
    for src in ["log", "src"]:
        with open(os.path.join(wd, f"largeok.{src}"), "w") as f:
            run([vm, "largeok", os.path.join(SUBJ, f"{src}-16m"), f"{wd}/cand.work"], stdout=f)
    r = run(py + [os.path.join(LAB, "pick_large.py"), "pick", wd, "16"])
    assert r.returncode == 0, r.stderr
    print("prepared", d)


# ---------------------------------------------------------------- cells

def short_cells():
    # longphp: experiment #1's long-subject PHP sample, the labelled
    # synthetic row of the large-subject shape (timed per call)
    return [(e, f) for e in ENGINES for f in FAMILIES + ["longphp"]]


def large_cells(npat):
    rows = [l.split() for l in open(os.path.join(EXP_OUT, "work", "large.list"))][1:]
    cells = []
    for src, rank, pid, fam, calls, hx in rows:
        if int(rank) > npat:
            continue
        for size in ["1m", "16m"]:
            for e in ENGINES:
                cells.append((e, src, size, int(pid), int(rank)))
    # the synthetic long-subject PHP row: one cell per engine (whole work file)
    return cells


def cata_cells():
    return [(e, fam, n) for e in ENGINES for (fam, _, _, _) in CATA for n in CATA_LENGTHS]


EXP_OUT = None


def run_short(eng, fam, minsec=0.5):
    wd = os.path.join(EXP_OUT, "work")
    t0 = time.time()
    r = run(cmd(eng, "time", f"{wd}/{fam}.agreed.work", minsec), prefix=TIMED, timeout=120)
    kv = parse_kv(r.stdout.strip()) if r.returncode == 0 else {}
    return kv, r.returncode, time.time() - t0


def run_large(eng, src, size, pid, minsec=0.0):
    wd = os.path.join(EXP_OUT, "work")
    t0 = time.time()
    r = run(cmd(eng, "scan", os.path.join(SUBJ, f"{src}-{size}"), f"{wd}/large.work", pid, minsec),
            prefix=TIMED, timeout=120)
    kv = parse_kv(r.stdout.strip()) if r.returncode == 0 else {}
    return kv, r.returncode, time.time() - t0


def run_cata(eng, fam, n):
    _, syn, opt, pat = next(c for c in CATA if c[0] == fam)
    t0 = time.time()
    r = run(cmd(eng, "cata", syn, opt, pat.encode().hex(), n, CATA_LIMIT), prefix=TIMED, timeout=60)
    if r.returncode == 124:
        kv = {"outcome": "cap", "sec": "60"}
    else:
        kv = parse_kv(r.stdout.strip()) if r.returncode == 0 else {}
    return kv, r.returncode, time.time() - t0


def series(kind, runs, cells, fn, keys, extra_cols, prefilter=None):
    d = EXP_OUT
    path = os.path.join(d, f"{kind}.csv")
    cols = ["run", "seed", "order"] + extra_cols + ["rc", "wall"] + keys
    new = not os.path.exists(path)
    f = open(path, "a", newline="")
    w = csv.writer(f)
    if new:
        w.writerow(cols)
    log_conditions(d, f"{kind}-start")
    capped = set()
    for r in range(1, runs + 1):
        order = list(cells)
        random.Random(r).shuffle(order)
        for i, cell in enumerate(order):
            if prefilter and not prefilter(cell, capped):
                continue
            kv, rc, wall = fn(*cell)
            if kind == "cata" and kv.get("outcome") == "cap":
                capped.add(cell)
            w.writerow([r, r, i] + list(cell) + [rc, f"{wall:.3f}"] + [kv.get(k, "") for k in keys])
            f.flush()
        log_conditions(d, f"{kind}-run{r}")
    log_conditions(d, f"{kind}-end")
    f.close()


def main():
    global EXP_OUT
    what, runid = sys.argv[1], sys.argv[2]
    EXP_OUT = out_dir(runid)
    runs = int(sys.argv[3]) if len(sys.argv) > 3 else 10
    if what == "prepare":
        prepare(runid)
    elif what == "pilot":
        log_conditions(EXP_OUT, "pilot-start")
        with open(os.path.join(EXP_OUT, "pilot.txt"), "w") as f:
            tot = {"short": 0, "large": 0, "cata": 0}
            for c in short_cells():
                kv, rc, wall = run_short(*c)
                tot["short"] += wall
                f.write(f"short {c} rc={rc} wall={wall:.2f} {kv.get('ns_per_call')}\n")
            for c in large_cells(16):
                kv, rc, wall = run_large(*c[:4])
                tot["large"] += wall
                f.write(f"large {c} rc={rc} wall={wall:.2f} {kv.get('bytes_per_sec')} m={kv.get('matches')}\n")
            for c in cata_cells():
                kv, rc, wall = run_cata(*c)
                tot["cata"] += wall
                f.write(f"cata {c} rc={rc} wall={wall:.2f} {kv.get('outcome')} {kv.get('sec')}\n")
            f.write(f"TOTAL one run per cell (s): {tot}\n")
        print(open(os.path.join(EXP_OUT, "pilot.txt")).read().splitlines()[-1])
    elif what == "short":
        series("short", runs, short_cells(), run_short,
               ["cases", "skipped", "calls_per_pass", "passes", "sec", "ns_per_call",
                "minor_per_call", "major_per_call"], ["engine", "family"])
    elif what == "large":
        npat = int(sys.argv[4]) if len(sys.argv) > 4 else 16
        series("large", runs, [c[:4] for c in large_cells(npat)], run_large,
               ["bytes", "matches", "err", "scans", "sec_per_scan", "bytes_per_sec",
                "minor_per_match", "major_per_match"], ["engine", "source", "size", "pid"])
    elif what == "cata":
        def pre(cell, capped):
            e, fam, n = cell
            return not any(c[0] == e and c[1] == fam and c[2] < n for c in capped)
        series("cata", runs, cata_cells(), run_cata, ["n", "result", "outcome", "sec"],
               ["engine", "family", "len"], prefilter=pre)


if __name__ == "__main__":
    main()
