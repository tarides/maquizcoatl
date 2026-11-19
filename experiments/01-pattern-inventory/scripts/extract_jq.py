#!/usr/bin/env python3
# Extract regex arguments of jq's regex builtins from jq's own tests and manual.
# Usage: extract_jq.py JQ_TREE > patterns/jq.occurrences.jsonl
#
# Host configuration (jq src/builtin.c f_match): ONIG_SYNTAX_PERL_NG, UTF-8,
# base options ONIG_OPTION_CAPTURE_GROUP; flags i x m s p l n add
# IGNORECASE EXTEND MULTILINE SINGLELINE MULTILINE|SINGLELINE FIND_LONGEST
# FIND_NOT_EMPTY; g is a search-loop flag, not an Oniguruma option.
import json, re, sys, pathlib

OPT = {'i': 1, 'x': 2, 'm': 4, 's': 8, 'p': 4 | 8, 'l': 16, 'n': 32, 'g': 0}
CAPTURE_GROUP = 256
FUNCS = ('test', 'match', 'capture', 'scan', 'split', 'splits', 'sub', 'gsub')
FILES = ['tests/jq.test', 'tests/onig.test', 'tests/optional.test']
MANUAL = 'docs/content/manual/manual.yml'

def programs_from_test(text):
    """Yield (line, program) for each test block's program line."""
    lines = text.split('\n')
    i, n = 0, len(lines)
    while i < n:
        l = lines[i]
        if l.strip() == '' or l.startswith('#'):
            i += 1; continue
        if l.startswith('%%FAIL'):
            i += 1
            if i < n: yield i + 1, lines[i]
        else:
            yield i + 1, l
        # skip the rest of the block
        while i < n and lines[i].strip() != '':
            i += 1

def yaml_scalar(s):
    s = s.strip()
    if s.startswith("'") and s.endswith("'"):
        return s[1:-1].replace("''", "'")
    if s.startswith('"') and s.endswith('"'):
        return json.loads(s)
    return s

def programs_from_manual(text):
    for no, l in enumerate(text.split('\n'), 1):
        m = re.match(r"\s*-?\s*program:\s*(.*)$", l)
        if m:
            yield no, yaml_scalar(m.group(1))

def read_string(s, i):
    """s[i] == '"'. Return (end_index_after, value or None if interpolated)."""
    assert s[i] == '"'
    j, out, interp = i + 1, [], False
    while j < len(s):
        c = s[j]
        if c == '"':
            return j + 1, (None if interp else ''.join(out))
        if c == '\\':
            d = s[j + 1]
            if d == '(':
                interp = True
                depth, j = 1, j + 2
                while j < len(s) and depth:
                    if s[j] == '"':
                        j, _ = read_string(s, j); continue
                    depth += {'(': 1, ')': -1}.get(s[j], 0); j += 1
                continue
            if d == 'u':
                cp = int(s[j + 2:j + 6], 16); j += 6
                if 0xD800 <= cp < 0xDC00 and s[j:j + 2] == '\\u':
                    lo = int(s[j + 2:j + 6], 16); j += 6
                    cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00)
                out.append(chr(cp)); continue
            out.append({'n': '\n', 't': '\t', 'r': '\r', 'b': '\b', 'f': '\f',
                        '"': '"', '\\': '\\', '/': '/'}.get(d, '\\' + d))
            j += 2; continue
        out.append(c); j += 1
    raise ValueError('unterminated string')

def split_args(s, i):
    """s[i] == '('. Return (list of raw args, index after ')')."""
    depth, j, start, args = 0, i, i + 1, []
    while j < len(s):
        c = s[j]
        if c == '"':
            j, _ = read_string(s, j); continue
        if c in '([{': depth += 1
        elif c in ')]}':
            depth -= 1
            if depth == 0:
                args.append(s[start:j]); return args, j + 1
        elif c == ';' and depth == 1:
            args.append(s[start:j]); start = j + 1
        j += 1
    raise ValueError('unbalanced')

def literal(arg):
    """Return ('lit', value) / ('null', None) / ('nonlit', None)."""
    a = arg.strip()
    if a == 'null': return 'null', None
    if a.startswith('"'):
        try:
            end, v = read_string(a, 0)
        except Exception:
            return 'nonlit', None
        if end == len(a) and v is not None: return 'lit', v
    return 'nonlit', None

def array_literal(arg):
    a = arg.strip()
    if not (a.startswith('[') and a.endswith(']')): return None
    try:
        v = json.loads(a)
    except Exception:
        return None
    if isinstance(v, list) and 1 <= len(v) <= 2 and all(isinstance(x, (str, type(None))) for x in v) and isinstance(v[0], str):
        return v
    return None

CALL = re.compile(r'(?<![A-Za-z0-9_$.@])(' + '|'.join(FUNCS) + r')\s*\(')

def scan_program(prog):
    # mask out string contents so that calls inside strings are not matched
    masked, j = list(prog), 0
    while j < len(prog):
        if prog[j] == '"':
            try:
                e, _ = read_string(prog, j)
            except Exception:
                break
            for k in range(j + 1, e - 1): masked[k] = ' '
            j = e
        elif prog[j] == '#':
            while j < len(prog) and prog[j] != '\n': masked[j] = ' '; j += 1
        else:
            j += 1
    masked = ''.join(masked)
    for m in CALL.finditer(masked):
        name = m.group(1)
        if re.search(r'def\s*$', masked[:m.start()]): continue
        try:
            args, _ = split_args(prog, m.end() - 1)
        except Exception:
            yield name, None, None, 'non-literal'; continue
        if name == 'split' and len(args) == 1:
            continue  # split/1 is a plain string split, not a regex
        if name in ('sub', 'gsub'):
            re_arg, fl_arg = args[0], (args[2] if len(args) > 2 else None)
        else:
            re_arg, fl_arg = args[0], (args[1] if len(args) > 1 else None)
        flags = '' if fl_arg is None else None
        if fl_arg is not None:
            k, v = literal(fl_arg)
            flags = '' if k == 'null' else v if k == 'lit' else None
        k, v = literal(re_arg)
        if k != 'lit' and name in ('test', 'match', 'capture') and fl_arg is None:
            arr = array_literal(re_arg)
            if arr is not None:
                k, v = 'lit', arr[0]
                flags = (arr[1] or '') if len(arr) > 1 else ''
        if k != 'lit' or flags is None:
            yield name, (v if k == 'lit' else None), flags, 'non-literal'; continue
        yield name, v, flags, 'literal'

def main():
    root = pathlib.Path(sys.argv[1])
    srcs = [(f, programs_from_test) for f in FILES] + [(MANUAL, programs_from_manual)]
    for rel, fn in srcs:
        text = (root / rel).read_text(encoding='utf-8')
        for line, prog in fn(text):
            for name, pat, flags, status in scan_program(prog):
                opts = CAPTURE_GROUP
                bad = False
                for c in (flags or ''):
                    if c not in OPT: bad = True
                    else: opts |= OPT[c]
                rec = {'source': 'jq', 'file': rel, 'line': line, 'func': name,
                       'raw': prog, 'pattern': pat, 'flags': flags,
                       'syntax': 'PERL_NG', 'options': opts, 'encoding': 'UTF-8',
                       'status': 'host-rejected-flags' if bad and status == 'literal' else status}
                print(json.dumps(rec, ensure_ascii=False))

main()
