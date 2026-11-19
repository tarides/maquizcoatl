#!/usr/bin/env python3
# Package the long-subject PHP calls captured by shim_long.c (experiment #1,
# follow-up for #12; added after #11 started).
# Usage: long_subjects.py SHIM_DIR OUT_DIR [MAX_CALLS [MAX_STORED_BYTES]]
#
# Reads the per-process logs <SHIM_DIR>/<pid>.tsv and writes to OUT_DIR:
#   php.long-subjects.jsonl           one onig_search/onig_match call per line
#   php.long-subjects.subjects.jsonl  each distinct subject once
#   php.long-subjects.summary.json    counts, caps, calls not kept
# Hard caps on the committed files: at most MAX_CALLS calls (default 100)
# and MAX_STORED_BYTES bytes of stored subject text (default 1 MiB).  The
# shim already keeps at most the first 5 long calls of each process (one
# process per test).  A subject that is one short unit (at most 16 bytes)
# repeated is stored as {"repeat": {"unit", "count"}} instead of in full.
import json, sys, pathlib, hashlib, collections

def tid(syn, opt, enc, hx):  # same id as build_workloads.py
    return hashlib.sha1(f'{syn}\t{opt}\t{enc}\t{hx}'.encode()).hexdigest()[:12]

def text(b):
    try:
        return b.decode('utf-8'), None
    except UnicodeDecodeError:
        return None, b.hex()

def compact(b):
    for k in range(1, 17):
        if len(b) % k == 0 and b[:k] * (len(b) // k) == b:
            u, uh = text(b[:k])
            r = {'unit': u, 'count': len(b) // k}
            if uh: r['unit_hex'] = uh
            return r, k
    return None, len(b)

def main():
    sdir, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    max_calls = int(sys.argv[3]) if len(sys.argv) > 3 else 100
    max_bytes = int(sys.argv[4]) if len(sys.argv) > 4 else 1 << 20
    calls, subjects, not_logged = [], {}, collections.Counter()
    for f in sorted(sdir.glob('*.tsv'), key=lambda p: int(p.stem)):
        script, reg, local = None, {}, {}
        for line in open(f, encoding='utf-8'):
            x = line.rstrip('\n').split('\t')
            if x[0] == 'P':
                script = x[1]
                i = script.find('ext/mbstring/tests/')
                script = script[i:] if i >= 0 else pathlib.Path(script).name
            elif x[0] == 'N':
                t = {'pattern_hex': x[5], 'syntax': x[2], 'options': int(x[3]), 'encoding': x[4]}
                t['id'] = tid(t['syntax'], t['options'], t['encoding'], t['pattern_hex'])
                p, ph = text(bytes.fromhex(x[5]))
                if p is not None:
                    t['pattern'] = p; del t['pattern_hex']
                else:
                    t['pattern'] = None
                if x[1] != '(nil)': reg[x[1]] = t
            elif x[0] == 'D':
                b = bytes.fromhex(x[3])
                assert len(b) == int(x[2])
                sid = hashlib.sha1(b).hexdigest()[:16]
                local[x[1]] = sid
                subjects.setdefault(sid, b)
            elif x[0] in 'SM':
                calls.append({'source': 'php', 'kind': 'search' if x[0] == 'S' else 'match',
                              'triple': reg.get(x[1]), 'subject_id': local[x[2]],
                              'start': int(x[3]), 'range': None if x[4] == '-' else int(x[4]),
                              'search_options': int(x[5]),
                              'match_param': None if x[9] == '-' else
                                  {'retry_limit_in_match': int(x[9]), 'match_stack_limit': int(x[10])},
                              'expected': {'result': int(x[6]),
                                           'match': None if x[7] == '-' else [int(x[7]), int(x[8])]},
                              'origin': script})
            elif x[0] == 'L':
                not_logged[script] += int(x[1])
    calls.sort(key=lambda c: c['origin'] or '')  # stable: keeps call order within a test
    kept, stored, used, dropped = [], 0, {}, 0
    for c in calls:
        sid = c['subject_id']
        if sid not in used:
            rep, cost = compact(subjects[sid])
            if len(kept) >= max_calls or stored + cost > max_bytes:
                dropped += 1
                continue
            used[sid] = rep; stored += cost
        elif len(kept) >= max_calls:
            dropped += 1
            continue
        kept.append(c)
    out.mkdir(parents=True, exist_ok=True)
    with open(out / 'php.long-subjects.jsonl', 'w', encoding='utf-8') as fo:
        for c in kept: fo.write(json.dumps(c, ensure_ascii=False) + '\n')
    with open(out / 'php.long-subjects.subjects.jsonl', 'w', encoding='utf-8') as fo:
        for sid, rep in used.items():
            b = subjects[sid]
            r = {'subject_id': sid, 'bytes': len(b), 'sha1': hashlib.sha1(b).hexdigest()}
            if rep:
                r['repeat'] = rep
            else:
                r['subject'], r['subject_hex'] = text(b)
            fo.write(json.dumps(r, ensure_ascii=False) + '\n')
    summ = {'calls_logged': len(calls), 'calls_kept': len(kept), 'calls_dropped_by_caps': dropped,
            'distinct_subjects': len(used), 'stored_subject_bytes': stored,
            'caps': {'per_process': 'first 5 long calls (shim_long.c)', 'max_calls': max_calls,
                     'max_stored_bytes': max_bytes},
            'calls_per_test': dict(collections.Counter(c['origin'] for c in kept)),
            'long_calls_not_logged_per_test': dict(not_logged)}
    (out / 'php.long-subjects.summary.json').write_text(json.dumps(summ, indent=1) + '\n')
    print(json.dumps(summ, indent=1))

main()
