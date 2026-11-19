#!/usr/bin/env python3
"""Spread of timed repetitions, within one run or across runs; compile
and worst-case tables across runs.

Usage:
  python3 -I -S spread.py <time-file>
      prints 'median iqr spread' of the T lines of one `time` output.
  python3 -I -S spread.py --runs <raw-times.tsv>...
      prints a CSV with one row per (engine, workload) over the runs
      given, one raw-times.tsv per run (as written by run.sh):
        runs                    runs that have the cell
        median_s                median over runs of the per-run median
        mb_per_s                bytes per pass / median_s, in MB/s
        within_spread_max       largest per-run IQR / median
        within_range_max        largest per-run (max - min) / median
        between_spread          (max - min) / median of the per-run medians;
                                empty with fewer than two runs
        ratio_median, ratio_min, ratio_max
                                speed ratio vs Oniguruma threaded on the
                                same subset (the reference cell of
                                summarise.py), computed run by run; none
                                for a cell with no subject byte, as in
                                summarise.py
        ref_between_spread      between_spread of that reference cell
        distinguishable_from_1  yes when every run's ratio is on the same
                                side of 1 and |ln ratio_median| exceeds
                                the sum of the between-run spreads of the
                                cell and of its reference, both over the
                                runs that have the two (the relative
                                errors of the two medians add up in their
                                ratio), no otherwise; empty with fewer
                                than two runs with the reference cell
A cell that run.sh repeated (spread over 10%) is taken from its repeat,
as summarise.py does.
  python3 -I -S spread.py --compile <raw-times.tsv>...
      prints a CSV with one row per (engine, workload, pattern) compiled
      in the engine's own column, over the runs given: runs, median_ns
      (median over runs of the per-run median), min_ns and max_ns (of
      the per-run medians), n_min (smallest number of compilations).
  python3 -I -S spread.py --worst <worst.csv>...
      prints a CSV with one row per worst-case point (family, engine,
      length) over the runs given (one worst.csv per run): runs, outcome
      and code (the distinct values, joined by '|' when the runs
      disagree), median_s, min_s, max_s (empty for a point with no time).
"""
import csv, math, statistics, sys

ENGINES = ['onig-threaded', 'onig-switch', 'pcre2-interp', 'pcre2-jit', 're2', 'rust-regex', 'ocaml-re']
WORKLOADS = ['jq', 'php', 'php-legacy', 'vscode', 'vscode-subst']

def spread(ts):
    """(median, IQR, IQR / median, (max - min) / median)"""
    ts = sorted(ts)
    q = statistics.quantiles(ts, n=4, method='inclusive')
    med = statistics.median(ts)
    return med, q[2] - q[0], (q[2] - q[0]) / med, (ts[-1] - ts[0]) / med

def one_file(path):
    ts = [float(l.split('\t')[2]) for l in open(path) if l.startswith('T\t')]
    if len(ts) < 2: print('nan nan nan'); return
    med, iqr, sp, _ = spread(ts)
    print('%.9g %.9g %.4f' % (med, iqr, sp))

def load_run(path):
    """{cell: (times, bytes_per_pass)} of one raw-times.tsv."""
    t, b = {}, {}
    for l in open(path):
        if l.startswith('#'): continue
        f = l.rstrip('\n').split('\t')
        cell, kind = f[1], f[2]
        if kind == 'T': t.setdefault(cell, []).append(float(f[4]))
        elif kind == 'S': b[cell] = int(dict(kv.split('=') for kv in f[3:])['bytes_per_pass'])
    cells = {}
    for c, ts in t.items():
        if c.endswith('.repeat') or len(ts) < 2: continue
        r = t.get(c + '.repeat', [])
        cells[c] = (r if spread(ts)[2] > 0.10 and len(r) >= 2 else ts, b.get(c, 0))
    return cells

def ref_cell(e, w):
    return 'onig-threaded.%s' % w if e in ('onig-threaded', 'onig-switch') else 'onig-threaded@%s.%s' % (e, w)

def between(meds):
    """(median, (max - min) / median), the spread None for a single run"""
    m = statistics.median(meds)
    return m, (max(meds) - min(meds)) / m if len(meds) >= 2 else None

def fmt(x):
    return '' if x is None else '%.4f' % x

def runs_table(paths):
    runs = [load_run(p) for p in paths]
    W = csv.writer(sys.stdout)
    W.writerow(['engine', 'workload', 'runs', 'median_s', 'mb_per_s', 'within_spread_max', 'within_range_max',
                'between_spread', 'ratio_median', 'ratio_min', 'ratio_max', 'ref_between_spread',
                'distinguishable_from_1'])
    for e in ENGINES:
        for w in WORKLOADS:
            c, rc = '%s.%s' % (e, w), ref_cell(e, w)
            have = [r for r in runs if c in r]
            if not have: continue
            st = [spread(r[c][0]) for r in have]
            med, bsp = between([s[0] for s in st])
            nbytes = have[0][c][1]
            row = [e, w, len(have), '%.9g' % med, '%.6g' % (nbytes / med / 1e6) if nbytes else '',
                   '%.4f' % max(s[2] for s in st), '%.4f' % max(s[3] for s in st), fmt(bsp)]
            paired = [r for r in have if rc in r]
            if nbytes and paired:
                ratios = [spread(r[rc][0])[0] / spread(r[c][0])[0] for r in paired]
                rbsp = between([spread(r[rc][0])[0] for r in paired])[1]
                psp = between([spread(r[c][0])[0] for r in paired])[1]
                rmed = statistics.median(ratios)
                same_side = all(x > 1 for x in ratios) or all(x < 1 for x in ratios)
                dist = '' if e == 'onig-threaded' or len(paired) < 2 else \
                    'yes' if same_side and abs(math.log(rmed)) > psp + rbsp else 'no'
                row += ['%.4f' % rmed, '%.4f' % min(ratios), '%.4f' % max(ratios), fmt(rbsp), dist]
            else:
                row += ['', '', '', '', '']
            W.writerow(row)

def compile_table(paths):
    """Per-pattern compile medians of the own-column cells, over runs."""
    per = {}  # (engine, workload, pid) -> [(median_ns, n)], one per run
    for p in paths:
        seen = set()
        for l in open(p):
            if l.startswith('#'): continue
            f = l.rstrip('\n').split('\t')
            if f[2] != 'C' or f[1].endswith('.repeat') or '@' in f[1]: continue
            e, w = f[1].split('.', 1)
            key = (e, w, int(f[3]))
            if key in seen: sys.exit('%s: pattern %d of %s.%s listed twice' % (p, key[2], e, w))
            seen.add(key)
            per.setdefault(key, []).append((float(f[4]), int(f[5])))
    W = csv.writer(sys.stdout)
    W.writerow(['engine', 'workload', 'pid', 'runs', 'median_ns', 'min_ns', 'max_ns', 'n_min'])
    order = {c: i for i, c in enumerate((e, w) for e in ENGINES for w in WORKLOADS)}
    for (e, w, pid) in sorted(per, key=lambda k: (order[k[0], k[1]], k[2])):
        v = per[e, w, pid]
        ns = [x[0] for x in v]
        W.writerow([e, w, pid, len(v), '%.6g' % statistics.median(ns), '%.6g' % min(ns), '%.6g' % max(ns),
                    min(x[1] for x in v)])

def worst_table(paths):
    """Worst-case points over runs, in the order of the first file."""
    keys, per = [], {}
    for p in paths:
        for r in csv.DictReader(open(p)):
            k = tuple(r[c] for c in ('family', 'pattern', 'syntax', 'options', 'engine', 'length'))
            if k not in per: keys.append(k); per[k] = []
            per[k].append(r)
    W = csv.writer(sys.stdout)
    W.writerow(['family', 'pattern', 'syntax', 'options', 'engine', 'length', 'runs', 'outcome', 'code',
                'median_s', 'min_s', 'max_s'])
    distinct = lambda xs: '|'.join(sorted(set(xs)))
    for k in keys:
        rs = per[k]
        s = [float(r['seconds']) for r in rs if r['seconds']]
        W.writerow(list(k) + [len(rs), distinct(r['outcome'] for r in rs), distinct(r['code'] for r in rs)] +
                   (['%.6g' % statistics.median(s), '%.6g' % min(s), '%.6g' % max(s)] if s else ['', '', '']))

if len(sys.argv) >= 3 and sys.argv[1] == '--runs': runs_table(sys.argv[2:])
elif len(sys.argv) >= 3 and sys.argv[1] == '--compile': compile_table(sys.argv[2:])
elif len(sys.argv) >= 3 and sys.argv[1] == '--worst': worst_table(sys.argv[2:])
elif len(sys.argv) == 2: one_file(sys.argv[1])
else: sys.exit(__doc__)
