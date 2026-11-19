#!/usr/bin/env python3
# Deduplicate occurrences into (pattern, syntax, options, encoding) triples,
# compile and classify each with upstream f95747b, and write
# patterns/<source>.jsonl plus a stock-vs-instrumented consistency report.
# Usage: inventory.py OUT_PATTERNS_DIR CLASSIFY CLASSIFY_STOCK OCC.jsonl...
import json, sys, subprocess, hashlib, pathlib, collections

COLS = ['captures', 'named_groups', 'backreferences', 'lookahead', 'lookbehind',
        'atomic_groups', 'possessive', 'bounded_repetition', 'subexp_calls',
        'absent', 'conditionals', 'callouts', 'unicode_properties',
        'case_insensitive', 'multichar_casefold']
COMPILABLE = ('literal', 'host-substituted')

def tid(syn, opt, enc, hx):
    return hashlib.sha1(f'{syn}\t{opt}\t{enc}\t{hx}'.encode()).hexdigest()[:12]

def run(binary, triples):
    inp = ''.join(f"{t['id']}\t{t['syntax']}\t{t['options']}\t{t['encoding']}\t{t['pattern_hex']}\n"
                  for t in triples)
    p = subprocess.run([binary], input=inp, capture_output=True, text=True, check=True)
    res = {}
    for line in p.stdout.splitlines():
        f = line.split('\t')
        res[f[0]] = {'status': f[1], 'code': int(f[2]),
                     'features': {c: (None if v == '-' else int(v)) for c, v in zip(COLS, f[3:18])},
                     'message': f[18] if len(f) > 18 else ''}
    return res

def main():
    outdir = pathlib.Path(sys.argv[1]); clf, stock = sys.argv[2], sys.argv[3]
    by_source = collections.defaultdict(dict)
    occ_stats = collections.defaultdict(collections.Counter)
    for occ_file in sys.argv[4:]:
        for line in open(occ_file, encoding='utf-8'):
            r = json.loads(line)
            srcs = [r['source']]
            src = 'php' if r['source'].startswith('php') else r['source']
            occ_stats[src][r['status']] += 1
            if r['status'] not in COMPILABLE:
                continue
            hx = r.get('pattern_hex') or r['pattern'].encode('utf-8').hex()
            variants = [(src, hx)]
            if src == 'vscode':
                variants.append(('vscode-grammar-text', r['raw'].encode('utf-8').hex()))
            for s, h in variants:
                i = tid(r['syntax'], r['options'], r['encoding'], h)
                t = by_source[s].setdefault(i, {
                    'id': i, 'source': s, 'pattern': bytes.fromhex(h).decode('utf-8', 'replace'),
                    'pattern_hex': h, 'syntax': r['syntax'], 'options': r['options'],
                    'encoding': r['encoding'], 'occurrences': 0, 'statuses': [],
                    'origins': [], 'files': [], 'first_seen': None})
                if r['file'] not in t['files']: t['files'].append(r['file'])
                t['occurrences'] += 1
                if r['status'] not in t['statuses']: t['statuses'].append(r['status'])
                if r['source'] not in t['origins']: t['origins'].append(r['source'])
                if t['first_seen'] is None:
                    t['first_seen'] = f"{r['file']}:{r.get('line', r.get('loc'))}"
    report = {'occurrences': {k: dict(v) for k, v in occ_stats.items()}, 'sources': {}}
    for s, d in sorted(by_source.items()):
        triples = sorted(d.values(), key=lambda t: t['id'])
        a, b = run(clf, triples), run(stock, triples)
        mism = [t['id'] for t in triples
                if (a[t['id']]['status'], a[t['id']]['code']) != (b[t['id']]['status'], b[t['id']]['code'])]
        for t in triples:
            t.update({'compile': a[t['id']]})
            try:
                bytes.fromhex(t['pattern_hex']).decode('utf-8')
                del t['pattern_hex']  # recoverable from 'pattern'
            except UnicodeDecodeError:
                pass
        with open(outdir / f'{s}.jsonl', 'w', encoding='utf-8') as f:
            for t in triples:
                f.write(json.dumps(t, ensure_ascii=False) + '\n')
        st = collections.Counter(t['compile']['status'] for t in triples)
        report['sources'][s] = {'distinct_triples': len(triples),
                                'occurrences_compiled': sum(t['occurrences'] for t in triples),
                                'compile_status': dict(st),
                                'stock_vs_instrumented_mismatches': mism}
    json.dump(report, sys.stdout, indent=1)
    print()

main()
