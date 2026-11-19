#!/usr/bin/env python3
"""Spread of timed repetitions, within one run or across runs.

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
        between_spread          (max - min) / median of the per-run medians
        ratio_median, ratio_min, ratio_max
                                speed ratio vs Oniguruma threaded on the
                                same subset (the reference cell of
                                summarise.py), computed run by run; none
                                for a cell with no subject byte, as in
                                summarise.py
        ref_between_spread      between_spread of that reference cell
        distinguishable_from_1  yes when every run's ratio is on the same
                                side of 1 and |ratio_median - 1| exceeds
                                both between-run spreads, no otherwise;
                                empty with fewer than two runs
A cell that run.sh repeated (spread over 10%) is taken from its repeat,
as summarise.py does.
"""
import csv, statistics, sys

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
    m = statistics.median(meds)
    return m, (max(meds) - min(meds)) / m

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
                   '%.4f' % max(s[2] for s in st), '%.4f' % max(s[3] for s in st), '%.4f' % bsp]
            paired = [r for r in have if rc in r]
            if nbytes and paired:
                ratios = [spread(r[rc][0])[0] / spread(r[c][0])[0] for r in paired]
                rbsp = between([spread(r[rc][0])[0] for r in paired])[1]
                rmed = statistics.median(ratios)
                same_side = all(x > 1 for x in ratios) or all(x < 1 for x in ratios)
                dist = '' if e == 'onig-threaded' or len(paired) < 2 else \
                    'yes' if same_side and abs(rmed - 1) > max(bsp, rbsp) else 'no'
                row += ['%.4f' % rmed, '%.4f' % min(ratios), '%.4f' % max(ratios), '%.4f' % rbsp, dist]
            else:
                row += ['', '', '', '', '']
            W.writerow(row)

if len(sys.argv) >= 3 and sys.argv[1] == '--runs': runs_table(sys.argv[2:])
elif len(sys.argv) == 2: one_file(sys.argv[1])
else: sys.exit(__doc__)
