#!/usr/bin/env python3
# Repetition counts for the VS Code workload (experiment #1, follow-up for
# #11; added after #11 started).
# Usage: freq_profile.py FREQ_LOG DATA_DIR [FULL_OUT_DIR]
#
# FREQ_LOG is the output of freq_vscode.js.  Writes to DATA_DIR:
#   vscode.frequency.jsonl         one line per line of DATA_DIR/vscode.jsonl, same
#                                  order: {line, scanner, start, count}, with line
#                                  the 0-based line number in vscode.jsonl and count
#                                  how many times vscode-textmate issued that search
#   vscode.frequency-summary.json  totals and the count distribution of the complete
#                                  set (473,134 distinct searches)
# With FULL_OUT_DIR (e.g. $WORKDIR/out/workloads-full), also writes
# FULL_OUT_DIR/vscode.frequency.jsonl aligned with the complete vscode.jsonl there.
import json, sys, pathlib, hashlib, collections

def key(scanner, start, options, sha1):
    return (scanner, start, options, sha1)

def align(freq, wl, out):
    n = 0
    with open(wl, encoding='utf-8') as fi, open(out, 'w', encoding='utf-8') as fo:
        for i, l in enumerate(fi):
            r = json.loads(l)
            k = key(r['scanner'], r['start'], r['search_options'],
                    hashlib.sha1(r['subject'].encode('utf-8')).hexdigest())
            fo.write(json.dumps({'line': i, 'scanner': r['scanner'], 'start': r['start'],
                                 'count': freq[k]}) + '\n')
            n += 1
    return n

def main():
    log, data = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    freq, stats = {}, None
    for l in open(log, encoding='utf-8'):
        r = json.loads(l)
        if r.get('t') == 'stats':
            stats = r
            continue
        freq[key(r['scanner'], r['start'], r['options'], r['subject_sha1'])] = r['count']
    counts = list(freq.values())
    assert stats and sum(counts) == stats['calls'] and len(counts) == stats['searches']
    buckets = [(1, 1), (2, 2), (3, 4), (5, 9), (10, 99), (100, 999), (1000, None)]
    hist = {}
    for lo, hi in buckets:
        sel = [c for c in counts if c >= lo and (hi is None or c <= hi)]
        hist[f'{lo}' if lo == hi else f'{lo}+' if hi is None else f'{lo}-{hi}'] = \
            {'searches': len(sel), 'calls': sum(sel)}
    per_scanner = collections.Counter()
    for (s, _, _, _), c in freq.items(): per_scanner[s] += c
    summ = {'calls': stats['calls'], 'distinct_searches': stats['searches'],
            'scanners': stats['scanners'], 'max_count': max(counts),
            'count_distribution': hist,
            'top_scanners_by_calls': [{'scanner': s, 'calls': c} for s, c in per_scanner.most_common(10)]}
    summ['committed_lines'] = align(freq, data / 'vscode.jsonl', data / 'vscode.frequency.jsonl')
    if len(sys.argv) > 3:
        full = pathlib.Path(sys.argv[3])
        summ['full_lines'] = align(freq, full / 'vscode.jsonl', full / 'vscode.frequency.jsonl')
    (data / 'vscode.frequency-summary.json').write_text(json.dumps(summ, indent=1) + '\n')
    print(json.dumps(summ, indent=1))

main()
