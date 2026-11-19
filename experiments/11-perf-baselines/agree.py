#!/usr/bin/env python3
"""Experiment #11, step 6: compare every engine's `check` output with
Oniguruma threaded (the reference).

Usage: python3 -I -S agree.py <out-dir> <workloads-dir>
Reads <out-dir>/check/<engine>.<workload>.txt, writes
  <out-dir>/agreement.csv      counts per (engine, workload)
  <out-dir>/disagreements.csv  one row per disagreeing pattern
  <out-dir>/only/<engine>.<workload>.txt  pattern ids timed for that engine
Exit status 1 if Oniguruma switch differs from Oniguruma threaded.
The classification of disagreements is a heuristic on the pattern text
and the subjects; rows it cannot explain are labelled 'unexplained'.
"""
import csv, os, re, sys

out, wl = sys.argv[1], sys.argv[2]
REF = 'onig-threaded'

def parse(path):
    st, m, passt = {}, {}, None
    for line in open(path, encoding='latin-1'):
        f = line.rstrip('\n').split('\t')
        if f[0] == 'P': st[int(f[1])] = (f[2], f[3] if len(f) > 3 else '')
        elif f[0] == 'M': m[(int(f[1]), int(f[2]))] = f[3].strip() if len(f) > 3 else ''
        elif f[0] == 'PASS': passt = float(f[1])
    return st, m, passt

def load_wl(name):
    d = os.path.join(wl, name)
    pats = {}
    for l in open(os.path.join(d, 'patterns.tsv')):
        f = l.rstrip('\n').split('\t')
        pats[int(f[0])] = {'id': f[1], 'syntax': f[2], 'options': int(f[3]), 'pat': bytes.fromhex(f[5])}
    subs = {}
    for l in open(os.path.join(d, 'subjects.tsv')):
        f = l.rstrip('\n').split('\t'); subs[int(f[0])] = bytes.fromhex(f[1])
    return pats, subs

POSIX_RE = re.compile(rb'\[:\^?[a-z]+:\]')   # [:alpha:], meaningful inside a bracket expression
# Syntax facts at f95747b (syntax definitions in upstream/src/regparse.c
# and upstream/src/regsyntax.c):
# ONIG_SYN_OP2_CCLASS_SET_OP: '[' opens a class inside a class
# (upstream/src/regparse.c:5542-5549).
CCLASS_SET_OP = ('ONIGURUMA', 'RUBY', 'JAVA')
# ONIG_SYN_ALLOW_INTERVAL_LOW_ABBREV: {,n} means {0,n}
# (upstream/src/regparse.c:4670-4677).
INTERVAL_LOW_ABBREV = ('ONIGURUMA', 'RUBY', 'PYTHON')

def outside_classes(pat, syntax):
    """(bare, posix): bare is the pattern without its bracket
    expressions, with every escape except \\z and \\Z replaced by the
    neutral text '_', so that a '^', '$' or '{' that is escaped or
    inside [...] is not taken for an operator; posix tells whether a
    POSIX bracket such as [:alpha:] appears inside a bracket expression.
    A heuristic: \\Q...\\E, (?#...) and extended-mode comments are read
    as ordinary pattern text."""
    out, depth, i, posix = bytearray(), 0, 0, False
    while i < len(pat):
        c = pat[i:i + 1]
        if c == b'\\':
            if depth == 0: out += pat[i:i + 2] if pat[i + 1:i + 2] in (b'z', b'Z') else b'_'
            i += 2; continue
        if depth:
            m = POSIX_RE.match(pat, i)
            if m: posix = True; i = m.end(); continue
        if c == b'[' and (depth == 0 or syntax in CCLASS_SET_OP):
            depth += 1; i += 1
            if pat.startswith(b'^', i): i += 1
            if pat.startswith(b']', i): i += 1   # a leading ']' is literal
            continue
        if c == b']' and depth: depth -= 1
        elif depth == 0: out += c
        i += 1
    return bytes(out), posix

def classify(engine, p, subj, ref, got):
    pat = p['pat']
    bare, posix = outside_classes(pat, p['syntax'])
    nonascii = any(b >= 0x80 for b in pat) or any(b >= 0x80 for b in subj)
    # Last match is an empty match at the very end of the subject.
    def ends_empty(r): return r.split()[-1:] == ['%d-%d' % (len(subj), len(subj))]
    if '!' in got: return 'search error (resource limit)'
    try: subj.decode('utf-8'); valid = True
    except UnicodeDecodeError: valid = False
    if not valid and engine != 'ocaml-re': return 'semantic: subject is not valid UTF-8'
    if re.search(rb'\\[<>]', pat): return 'syntax: \\< \\> are word anchors in Rust regex, literals in Oniguruma'
    if re.search(rb'&&', pat) and re.search(rb'\[', pat): return 'syntax: character-class intersection && is Oniguruma-only'
    if re.search(rb'\\[1-9][0-9]', pat): return 'syntax: \\NN is a backreference in Oniguruma, an octal escape elsewhere'
    if engine == 'ocaml-re' and nonascii: return 'semantic: ocaml-re matches bytes, not code points'
    if re.search(rb'\\[hH]', pat): return 'syntax: \\h is a hex digit in Oniguruma, horizontal space elsewhere'
    if engine == 're2' and p['syntax'] in INTERVAL_LOW_ABBREV and re.search(rb'\{,[0-9]+\}', bare):
        return 'syntax: {,n} is literal text in RE2, {0,n} in Oniguruma'
    if p['options'] & 1: return 'semantic: case folding differs'
    # Class and {,n} tests come before the anchor tests: a '$' or '^'
    # in the pattern says nothing when the difference is elsewhere.
    if engine == 're2' and nonascii and (re.search(rb'\\[wWbBdDsS]', pat) or posix):
        return 'semantic: RE2 \\w \\b \\d \\s and POSIX classes are ASCII-only'
    if engine == 'rust-regex' and nonascii and posix:
        return 'semantic: Rust regex POSIX classes are ASCII-only'
    if re.search(rb'\^', bare) and subj.endswith(b'\n') and ends_empty(got) and not ends_empty(ref):
        return 'semantic: ^ after a final newline (Oniguruma does not match there)'
    if re.search(rb'\\[zZ]|\$', bare) and subj.endswith(b'\n'):
        return 'semantic: end anchor before a final newline'
    if re.search(rb'\\G', pat): return 'semantic: \\G is the search start in Oniguruma'
    if re.search(rb'\\[pP]\{', pat) or posix:
        return 'semantic: property or POSIX class definitions differ'
    if re.search(rb'\(\?[a-z]*x', pat) or p['options'] & 2: return 'syntax: extended-mode details differ'
    if re.search(rb'\|', pat): return 'semantic: alternation or longest-match order'
    return 'unexplained'

engines = sorted({f.split('.')[0] for f in os.listdir(os.path.join(out, 'check'))})
workloads = sorted({f.split('.', 1)[1][:-4] for f in os.listdir(os.path.join(out, 'check'))})
os.makedirs(os.path.join(out, 'only'), exist_ok=True)
agr = open(os.path.join(out, 'agreement.csv'), 'w', newline='')
dis = open(os.path.join(out, 'disagreements.csv'), 'w', newline='')
A = csv.writer(agr); D = csv.writer(dis)
A.writerow(['engine', 'workload', 'patterns', 'accepted', 'rejected_as_reference', 'unsupported_syntax_or_feature',
            'unsupported_option_syntax_or_encoding', 'resource_limited', 'accepted_but_reference_rejects',
            'disagreeing_patterns', 'timed_patterns', 'pairs_compared', 'one_pass_seconds'])
D.writerow(['engine', 'workload', 'pid', 'triple_id', 'class', 'sid', 'reference', 'engine_result', 'pattern'])
bad_switch = 0
for w in workloads:
    rpath = os.path.join(out, 'check', '%s.%s.txt' % (REF, w))
    if not os.path.exists(rpath): continue
    rst, rm, _ = parse(rpath)
    pats, subs = load_wl(w)
    for e in engines:
        path = os.path.join(out, 'check', '%s.%s.txt' % (e, w))
        if not os.path.exists(path): continue
        st, m, passt = parse(path)
        c = dict(acc=0, rej=0, unsup_feat=0, unsup_opt=0, lim=0, acc_refrej=0)
        disagree = {}
        for pid, (s, why) in st.items():
            rok = rst[pid][0] == 'ok'
            if s == 'ok':
                c['acc'] += 1
                if not rok: c['acc_refrej'] += 1
            elif s == 'unsup': c['unsup_opt'] += 1
            elif s == 'limit': c['lim'] += 1
            elif rok: c['unsup_feat'] += 1
            else: c['rej'] += 1
        npairs = 0
        for k, ref in rm.items():
            if k not in m: continue
            npairs += 1
            if m[k] != ref and k[0] not in disagree:
                disagree[k[0]] = (k[1], ref, m[k])
        for pid, (sid, ref, got) in sorted(disagree.items()):
            p = pats[pid]
            D.writerow([e, w, pid, p['id'], classify(e, p, subs[sid], ref, got), sid, ref[:200], got[:200],
                        p['pat'][:160].decode('utf-8', 'backslashreplace')])
        if e == 'onig-switch' and (disagree or any(st[p][0] != rst[p][0] for p in st)):
            bad_switch += 1
        timed = [pid for pid, (s, _) in st.items() if s == 'ok' and rst[pid][0] == 'ok' and pid not in disagree]
        with open(os.path.join(out, 'only', '%s.%s.txt' % (e, w)), 'w') as f:
            f.write(''.join('%d\n' % p for p in sorted(timed)))
        A.writerow([e, w, len(st), c['acc'], c['rej'], c['unsup_feat'], c['unsup_opt'], c['lim'], c['acc_refrej'],
                    len(disagree), len(timed), npairs, passt])
agr.close(); dis.close()
print(open(os.path.join(out, 'agreement.csv')).read())
if bad_switch:
    print('Oniguruma switch build differs from threaded build', file=sys.stderr); sys.exit(1)
