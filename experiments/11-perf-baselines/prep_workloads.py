#!/usr/bin/env python3
"""Experiment #11, step 5: convert #1's JSONL workloads into the flat
format read by every harness.

Usage: python3 -I prep_workloads.py <data-dir-of-#1> <out-dir>

Output, one directory per workload under <out-dir>:
  patterns.tsv  pid  triple-id  syntax  options  encoding  pattern-hex
  subjects.tsv  sid  subject-hex
  pairs.tsv     pid  sid             (distinct (pattern, subject) pairs)
  calls.tsv     kind pids sid start range exp-result exp-from exp-to match-param
                (the original calls, for the Oniguruma cross-check)
and <out-dir>/prep-summary.json with the counts.

Workloads:
  jq            jq.jsonl (all UTF-8, PERL_NG)
  php           php.jsonl, UTF-8 rows in RUBY syntax
  php-legacy    php.jsonl, non-UTF-8 encodings or other syntaxes (Oniguruma-only)
  vscode        vscode.jsonl members, triples without host substitution
  vscode-subst  vscode.jsonl members whose triple was host-substituted
                (contains U+FFFF, vscode-textmate's \\A/\\G replacement)
"""
import json, os, sys

src, out = sys.argv[1], sys.argv[2]

class W:
    def __init__(self, name):
        self.name = name; self.pats = {}; self.subs = {}; self.pairs = set(); self.calls = []
        self.nondefault_mp = 0
    def pid(self, t):
        key = (t['syntax'], t['options'], t['encoding'], pat_bytes(t))
        if key not in self.pats:
            self.pats[key] = (len(self.pats), t['id'])
        return self.pats[key][0]
    def sid(self, b):
        if b not in self.subs:
            self.subs[b] = len(self.subs)
        return self.subs[b]
    def write(self):
        d = os.path.join(out, self.name); os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, 'patterns.tsv'), 'w') as f:
            for (syn, opt, enc, pat), (pid, tid) in sorted(self.pats.items(), key=lambda kv: kv[1][0]):
                f.write('%d\t%s\t%s\t%d\t%s\t%s\n' % (pid, tid, syn, opt, enc, pat.hex()))
        with open(os.path.join(d, 'subjects.tsv'), 'w') as f:
            for b, sid in sorted(self.subs.items(), key=lambda kv: kv[1]):
                f.write('%d\t%s\n' % (sid, b.hex()))
        with open(os.path.join(d, 'pairs.tsv'), 'w') as f:
            for p, s in sorted(self.pairs):
                f.write('%d\t%d\n' % (p, s))
        with open(os.path.join(d, 'calls.tsv'), 'w') as f:
            for c in self.calls:
                f.write('\t'.join(str(x) for x in c) + '\n')
        return {'patterns': len(self.pats), 'subjects': len(self.subs), 'pairs': len(self.pairs),
                'calls': len(self.calls),
                'subject_bytes_per_pass': sum(len(sub_by_id(self, s)) for _, s in self.pairs),
                'calls_with_nondefault_match_param': self.nondefault_mp}

def sub_by_id(w, s):
    if not hasattr(w, '_inv'):
        w._inv = {v: k for k, v in w.subs.items()}
    return w._inv[s]

# #1 stores the host's bytes as text when they are valid UTF-8, and as
# hex (pattern_hex / subject_hex) otherwise.
def pat_bytes(t):
    if t.get('pattern_hex') is not None:
        return bytes.fromhex(t['pattern_hex'])
    return t['pattern'].encode('utf-8')

def subj_bytes(r, enc=None):
    if r.get('subject_hex') is not None:
        return bytes.fromhex(r['subject_hex'])
    return r['subject'].encode('utf-8')

def mp(r):
    m = r.get('match_param')
    return '-' if m is None else '%d,%d' % (m['retry_limit_in_match'], m['match_stack_limit'])

def exp3(e):
    m = e.get('match') or [-1, -1]
    return e.get('result', e.get('index')), m[0], m[1]

ws = {n: W(n) for n in ['jq', 'php', 'php-legacy', 'vscode', 'vscode-subst']}
skipped = {}

for name in ['jq', 'php']:
    for line in open(os.path.join(src, name + '.jsonl'), encoding='utf-8'):
        r = json.loads(line); t = r['triple']
        w = ws[name]
        if name == 'php' and (t['encoding'] != 'UTF-8' or t['syntax'] != 'RUBY'):
            w = ws['php-legacy']
        try:
            b = subj_bytes(r); pid = w.pid(t)
        except (UnicodeError, KeyError, ValueError):
            skipped[name] = skipped.get(name, 0) + 1; continue
        sid = w.sid(b)
        w.pairs.add((pid, sid))
        if r.get('match_param') is not None: w.nondefault_mp += 1
        rng = -1 if r['range'] is None else r['range']
        w.calls.append((r['kind'], pid, sid, r['start'], rng, *exp3(r['expected']), mp(r)))

triples = {}
for line in open(os.path.join(src, 'vscode.triples.jsonl'), encoding='utf-8'):
    t = json.loads(line); triples[t['id']] = t
scanners = {}
for line in open(os.path.join(src, 'vscode.scanners.jsonl'), encoding='utf-8'):
    s = json.loads(line); scanners[s['scanner']] = s['members']
subst = lambda t: '￿' in t['pattern']
for line in open(os.path.join(src, 'vscode.jsonl'), encoding='utf-8'):
    r = json.loads(line)
    mem = [triples[i] for i in scanners[r['scanner']]]
    b = subj_bytes(r, 'UTF-8')
    for t in mem:
        w = ws['vscode-subst' if subst(t) else 'vscode']
        w.pairs.add((w.pid(t), w.sid(b)))
    # Cross-check calls go in 'vscode' with members resolved there; a
    # scanner with a substituted member keeps its calls in vscode-subst.
    w = ws['vscode-subst' if any(subst(t) for t in mem) else 'vscode']
    pids = ','.join(str(w.pid(t)) for t in mem)
    w.calls.append(('regset', pids, w.sid(b), r['start'], r['range'], *exp3(r['expected']), mp(r)))

summary = {n: w.write() for n, w in ws.items()}
summary['skipped_rows'] = skipped
with open(os.path.join(out, 'prep-summary.json'), 'w') as f:
    json.dump(summary, f, indent=1)
print(json.dumps(summary, indent=1))
