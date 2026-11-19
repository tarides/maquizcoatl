#!/usr/bin/env python3
"""Prints 'median iqr spread' of the T lines of one `time` output."""
import statistics, sys
ts = sorted(float(l.split('\t')[2]) for l in open(sys.argv[1]) if l.startswith('T\t'))
if len(ts) < 2: print('nan nan nan'); sys.exit(0)
q = statistics.quantiles(ts, n=4, method='inclusive')
med = statistics.median(ts)
print('%.9g %.9g %.4f' % (med, q[2] - q[0], (q[2] - q[0]) / med))
