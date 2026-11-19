#!/usr/bin/env python3
# Classify the triples seen only at run time (dynamic capture) and write
# patterns/<source>.dynamic-only.jsonl in the same format as patterns/<source>.jsonl.
# Usage: dynamic_only.py PATTERNS_DIR CLASSIFY WORKLOAD_DIR
import json, sys, subprocess, pathlib

COLS = ['captures', 'named_groups', 'backreferences', 'lookahead', 'lookbehind',
        'atomic_groups', 'possessive', 'bounded_repetition', 'subexp_calls',
        'absent', 'conditionals', 'callouts', 'unicode_properties',
        'case_insensitive', 'multichar_casefold']

pdir, clf, wdir = pathlib.Path(sys.argv[1]), sys.argv[2], pathlib.Path(sys.argv[3])
for src in ('vscode', 'jq', 'php'):
    f = wdir / f'{src}.dynamic-only.jsonl'
    if not f.exists():
        continue
    recs = [json.loads(l) for l in open(f, encoding='utf-8')]
    for r in recs:
        if r.get('pattern') is not None and 'pattern_hex' not in r:
            r['pattern_hex'] = r['pattern'].encode('utf-8').hex()
    inp = ''.join(f"{r['id']}\t{r['syntax']}\t{r['options']}\t{r['encoding']}\t{r['pattern_hex']}\n" for r in recs)
    out = subprocess.run([clf], input=inp, capture_output=True, text=True, check=True).stdout
    res = {}
    for line in out.splitlines():
        x = line.split('\t')
        res[x[0]] = {'status': x[1], 'code': int(x[2]),
                     'features': {c: int(v) for c, v in zip(COLS, x[3:18])},
                     'message': x[18] if len(x) > 18 else ''}
    with open(pdir / f'{src}.dynamic-only.jsonl', 'w', encoding='utf-8') as fo:
        for r in sorted(recs, key=lambda r: r['id']):
            t = {'id': r['id'], 'source': src, 'pattern': r.get('pattern'),
                 'syntax': r['syntax'], 'options': r['options'], 'encoding': r['encoding'],
                 'occurrences': 1, 'statuses': ['dynamic-only'], 'origins': ['dynamic'],
                 'files': [], 'first_seen': 'dynamic capture', 'compile': res[r['id']]}
            if r.get('pattern') is None:
                t['pattern_hex'] = r['pattern_hex']
                t['pattern'] = bytes.fromhex(r['pattern_hex']).decode('utf-8', 'replace')
            fo.write(json.dumps(t, ensure_ascii=False) + '\n')
    print(src, len(recs))
