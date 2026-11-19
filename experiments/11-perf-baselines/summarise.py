#!/usr/bin/env python3
"""Experiment #11, step 11: engine x workload tables from a run directory.

Usage: python3 -I summarise.py <run-dir> <out-prefix>
Writes <out-prefix>-throughput.csv, <out-prefix>-compile.csv and prints
a Markdown summary. A cell is valid when the spread (IQR / median of the
repetition times) is at most 10%, on the first run or on its single
repeat; otherwise it is reported as invalid with its data.
Ratios are speed ratios: Oniguruma-threaded time / engine time on the
same pattern subset (> 1 means the engine is faster).
passes_per_rep is the smallest number of passes in a repetition (each
repetition repeats passes until it has lasted the minimum time).
"""
import csv, os, statistics, sys

run, prefix = sys.argv[1], sys.argv[2]
ENGINES = ['onig-threaded', 'onig-switch', 'pcre2-interp', 'pcre2-jit', 're2', 'rust-regex', 'ocaml-re']
WORKLOADS = ['jq', 'php', 'php-legacy', 'vscode', 'vscode-subst']

def parse(path):
    d = {'T': [], 'C': []}
    for l in open(path):
        f = l.rstrip('\n').split('\t')
        if f[0] == 'T':
            n = int(f[3]); d['T'].append(float(f[2])); d['npass'] = min(d.get('npass', n), n)
        elif f[0] == 'C': d['C'].append((int(f[1]), float(f[2]), int(f[3])))
        elif f[0] == 'S':
            for kv in f[1:]:
                k, v = kv.split('='); d[k] = float(v)
    return d

def stats(ts):
    ts = sorted(ts)
    q = statistics.quantiles(ts, n=4, method='inclusive')
    med = statistics.median(ts)
    return med, ts[0], ts[-1], q[2] - q[0], (q[2] - q[0]) / med

def cell(name):
    """Returns (data, stats, used, valid) or None."""
    p = os.path.join(run, 'time', name + '.txt')
    if not os.path.exists(p): return None
    d = parse(p)
    if len(d['T']) < 2: return None
    s = stats(d['T']); used = 'first'
    if s[4] > 0.10:
        r = os.path.join(run, 'time', name + '.repeat.txt')
        if os.path.exists(r):
            d2 = parse(r)
            if len(d2['T']) >= 2:
                s2 = stats(d2['T'])
                d2['C'] = d['C']  # compile times come from the first run
                d, s, used = d2, s2, 'repeat'
    return d, s, used, s[4] <= 0.10

rows, comp = [], []
for e in ENGINES:
    for w in WORKLOADS:
        c = cell('%s.%s' % (e, w))
        if not c: continue
        d, (med, mn, mx, iqr, sp), used, valid = c
        ct = [x[1] for x in d['C']]
        ref = c if e == 'onig-threaded' else cell('onig-threaded@%s.%s' % (e, w))
        if e == 'onig-switch': ref = cell('onig-threaded.%s' % w)
        ratio = ''
        ref_med = ''
        if ref:
            ref_med = ref[1][0]
            ratio = ref_med / med if (valid and ref[3] and d.get('bytes_per_pass', 0) > 0) else ''
        rows.append(dict(engine=e, workload=w, valid=valid, run_used=used, reps=len(d['T']), passes_per_rep=d.get('npass'),
                         median_pass_s=med, min_s=mn, max_s=mx, iqr_s=iqr, spread=sp,
                         bytes_per_pass=int(d.get('bytes_per_pass', 0)), bytes_per_s=d.get('bytes_per_pass', 0) / med,
                         matches_per_pass=int(d.get('matches_per_pass', 0)), timed_patterns=int(d.get('included_patterns', 0)),
                         onig_threaded_same_subset_s=ref_med, speed_ratio_vs_onig_threaded=ratio,
                         compile_patterns=len(ct), compile_median_of_medians_ns=statistics.median(ct) if ct else '',
                         compile_p90_ns=statistics.quantiles(ct, n=10)[8] if len(ct) > 1 else (ct[0] if ct else ''),
                         compile_sum_ms=sum(ct) / 1e6 if ct else ''))
        for pid, ns, n in d['C']:
            comp.append(dict(engine=e, workload=w, pid=pid, median_ns=ns, n=n))

with open(prefix + '-throughput.csv', 'w', newline='') as f:
    W = csv.DictWriter(f, fieldnames=list(rows[0].keys())); W.writeheader(); W.writerows(rows)
with open(prefix + '-compile.csv', 'w', newline='') as f:
    W = csv.DictWriter(f, fieldnames=['engine', 'workload', 'pid', 'median_ns', 'n']); W.writeheader(); W.writerows(comp)

def fmt_bps(x): return '%.0f MB/s' % (x / 1e6) if x >= 1e6 else '%.2f MB/s' % (x / 1e6)
by = {(r['engine'], r['workload']): r for r in rows}
print('Speed ratio vs Oniguruma threaded on the same pattern subset (>1: faster); indicative MB/s; spread; * invalid (spread > 10%)\n')
print('| engine | ' + ' | '.join(WORKLOADS) + ' |')
print('|---|' + '---:|' * len(WORKLOADS))
for e in ENGINES:
    cells = []
    for w in WORKLOADS:
        r = by.get((e, w))
        if not r: cells.append('n/a'); continue
        if r['bytes_per_pass'] == 0: cells.append('no pair (%d patterns compile-timed only)' % r['compile_patterns']); continue
        rt = r['speed_ratio_vs_onig_threaded']
        cells.append('%s%s, %s, %.1f%%' % ('×%.2f' % rt if rt != '' else '–', '' if r['valid'] else '*',
                                           fmt_bps(r['bytes_per_s']), 100 * r['spread']))
    print('| %s | %s |' % (e, ' | '.join(cells)))
print('\nCompile time, median over patterns of the per-pattern median (µs)\n')
print('| engine | ' + ' | '.join(WORKLOADS) + ' |')
print('|---|' + '---:|' * len(WORKLOADS))
for e in ENGINES:
    cells = []
    for w in WORKLOADS:
        r = by.get((e, w))
        cells.append('%.1f (%d)' % (r['compile_median_of_medians_ns'] / 1e3, r['compile_patterns']) if r and r['compile_patterns'] else 'n/a')
    print('| %s | %s |' % (e, ' | '.join(cells)))
