#!/usr/bin/env python3
# Build workload files from the dynamic captures (experiment #1).
# Usage: build_workloads.py PATTERNS_DIR OUT_DIR REPLAY_BIN VSCODE_LOG JQ_SHIM_LOG [SAMPLE_PER_SCANNER [PHP_SHIM_LOG]]
#
# Writes to OUT_DIR:
#   vscode.triples.jsonl   one line per distinct compiled triple (id, pattern, ...)
#   vscode.scanners.jsonl  one line per scanner: id and member triple ids, in order
#   vscode.jsonl           one line per (scanner, subject, start, options) search
#   jq.jsonl, php.jsonl    one line per onig_search/onig_match call (shim log)
#   summary.json           counts, dynamic-only triples, host-vs-stock disagreements
# With SAMPLE_PER_SCANNER = k > 0, vscode.jsonl keeps the first k searches of
# each scanner (in capture order) and vscode.scanners.jsonl only the scanners
# used by kept searches; jq.jsonl is always complete.
import json, sys, subprocess, hashlib, pathlib, collections

def tid(syn, opt, enc, hx):
    return hashlib.sha1(f'{syn}\t{opt}\t{enc}\t{hx}'.encode()).hexdigest()[:12]

def static_ids(pdir, names):
    ids = set()
    for n in names:
        for l in open(pdir / f'{n}.jsonl', encoding='utf-8'):
            ids.add(json.loads(l)['id'])
    return ids

def write_dyn(out, source, recs):
    with open(out / f'{source}.dynamic-only.jsonl', 'w', encoding='utf-8') as f:
        for r in recs:
            f.write(json.dumps(r, ensure_ascii=False) + '\n')

def vscode(pdir, out, replay, log, k):
    static = static_ids(pdir, ['vscode', 'vscode-grammar-text'])
    scanners, searches = {}, []
    for l in open(log, encoding='utf-8'):
        r = json.loads(l)
        if r['t'] == 'scanner': scanners[r['id']] = r['patterns']
        elif r['t'] == 'search': searches.append(r)
    member = {}
    dyn_only, dyn_rec = {}, {}
    for sid, pats in scanners.items():
        ms = []
        for p in pats:
            hx = p.encode('utf-8').hex()
            i = tid('ONIGURUMA', 256, 'UTF-8', hx)
            ms.append({'id': i, 'pattern': p, 'syntax': 'ONIGURUMA', 'options': 256, 'encoding': 'UTF-8'})
            if i not in static: dyn_only[i] = p
            if i not in static: dyn_rec[i] = ms[-1]
        member[sid] = ms
    inp = [f"S\t{sid}\t{','.join(p.encode('utf-8').hex() for p in pats)}\n" for sid, pats in scanners.items()]
    inp += [f"Q\t{q}\t{s['scanner']}\t{s['subject'].encode('utf-8').hex()}\t{s['start']}\t{s['options']}\n"
            for q, s in enumerate(searches)]
    res = subprocess.run([replay], input=''.join(inp), capture_output=True, text=True, check=True).stdout
    exp = {}
    for line in res.splitlines():
        q, idx, a, b = line.split('\t')
        exp[int(q)] = {'index': int(idx), 'match': None if a == '-' else [int(a), int(b)]}
    per = collections.Counter()
    disagree = []
    kept_scanners = set()
    with open(out / 'vscode.jsonl', 'w', encoding='utf-8') as f:
        for q, s in enumerate(searches):
            e = exp[q]
            host = {'index': s['index'], 'match': s['match']}
            if (e['index'], e['match']) != (host['index'], host['match']):
                disagree.append({'query': q, 'scanner': s['scanner'], 'origin': f"{s['file']}:{s['line']}",
                                 'subject': s['subject'][:200], 'start': s['start'], 'stock': e, 'vscode-oniguruma': host})
            per[s['scanner']] += 1
            if k and per[s['scanner']] > k: continue
            kept_scanners.add(s['scanner'])
            n = len(s['subject'].encode('utf-8'))
            f.write(json.dumps({
                'source': 'vscode', 'kind': 'regset', 'scanner': s['scanner'],
                'subject': s['subject'], 'start': s['start'], 'range': n,
                'search_options': s['options'],
                'lead': 'ONIG_REGSET_POSITION_LEAD' if n < 1000 else 'per-regex-leftmost',
                'match_param': None, 'expected': e, 'vscode_oniguruma_1_7_0': host,
                'origin': f"{s['file']}:{s['line']}"}, ensure_ascii=False) + '\n')
    write_dyn(out, 'vscode', dyn_rec.values())
    used = {}
    with open(out / 'vscode.scanners.jsonl', 'w', encoding='utf-8') as f:
        for sid in sorted(scanners):
            if k and sid not in kept_scanners: continue
            for m in member[sid]: used[m['id']] = m
            f.write(json.dumps({'scanner': sid, 'members': [m['id'] for m in member[sid]]}) + '\n')
    with open(out / 'vscode.triples.jsonl', 'w', encoding='utf-8') as f:
        for i in sorted(used):
            f.write(json.dumps(used[i], ensure_ascii=False) + '\n')
    return {'scanners': len(scanners), 'searches': len(searches),
            'searches_written': sum(min(v, k) if k else v for v in per.values()),
            'distinct_compiled_patterns': len({p for ps in scanners.values() for p in ps}),
            'dynamic_only_triples': len(dyn_only),
            'dynamic_only_examples': list(dyn_only.values())[:10],
            'stock_vs_vscode_oniguruma_disagreements': len(disagree),
            'disagreement_kinds': dict(collections.Counter(
                'stock-compile-error' if d['stock']['index'] == -2 else 'different-result' for d in disagree)),
            'disagreement_files': dict(collections.Counter(d['origin'].split(':')[0] for d in disagree)),
            'disagreement_examples': [d for d in disagree if d['stock']['index'] != -2][:20] + disagree[:5]}

def shim(pdir, out, log, source):
    static = static_ids(pdir, [source])
    reg = {}
    items, dyn_only, triples, truncated = [], {}, set(), 0
    for line in open(log, encoding='utf-8'):
        f = line.rstrip('\n').split('\t')
        if f[0] == 'N':
            t = {'pattern_hex': f[5], 'syntax': f[2], 'options': int(f[3]), 'encoding': f[4]}
            t['id'] = tid(t['syntax'], t['options'], t['encoding'], t['pattern_hex'])
            try:
                t['pattern'] = bytes.fromhex(t['pattern_hex']).decode('utf-8'); del t['pattern_hex']
            except UnicodeDecodeError:
                t['pattern'] = None
            triples.add(t['id'])
            if t['id'] not in static: dyn_only[t['id']] = t
            if f[1] != '(nil)': reg[f[1]] = t
        elif f[0] in 'SM':
            t = reg.get(f[1])
            if f[2].startswith('len:'):
                truncated += 1  # subject above the shim's size cap: not packaged
                continue
            subj = bytes.fromhex(f[2])
            try:
                s, shex = subj.decode('utf-8'), None
            except UnicodeDecodeError:
                s, shex = None, f[2]
            r = int(f[6])
            items.append({'source': source, 'kind': 'search' if f[0] == 'S' else 'match',
                          'triple': t, 'subject': s, 'subject_hex': shex,
                          'start': int(f[3]), 'range': None if f[4] == '-' else int(f[4]),
                          'search_options': int(f[5]), 'match_param': None if f[9] == '-' else {'retry_limit_in_match': int(f[9]), 'match_stack_limit': int(f[10])},
                          'expected': {'result': r, 'match': None if f[7] == '-' else [int(f[7]), int(f[8])]}})
    write_dyn(out, source, dyn_only.values())
    with open(out / f'{source}.jsonl', 'w', encoding='utf-8') as fo:
        for it in items: fo.write(json.dumps(it, ensure_ascii=False) + '\n')
    return {'calls': len(items), 'calls_with_subject_over_cap_skipped': truncated,
            'distinct_triples_compiled': len(triples),
            'dynamic_only_triples': len(dyn_only),
            'dynamic_only': [t.get('pattern') for t in dyn_only.values()]}

def main():
    pdir, out, replay, vlog, jlog = map(pathlib.Path, sys.argv[1:6])
    k = int(sys.argv[6]) if len(sys.argv) > 6 else 0
    out.mkdir(parents=True, exist_ok=True)
    summ = {'vscode': vscode(pdir, out, str(replay), vlog, k), 'jq': shim(pdir, out, jlog, 'jq'),
            'sample_per_scanner': k}
    if len(sys.argv) > 7:
        summ['php'] = shim(pdir, out, pathlib.Path(sys.argv[7]), 'php')
    (out / 'summary.json').write_text(json.dumps(summ, indent=1, ensure_ascii=False) + '\n')
    print(json.dumps({s: {a: b for a, b in v.items() if not isinstance(b, list)} if isinstance(v, dict) else v
                      for s, v in summ.items()}, indent=1))

main()
