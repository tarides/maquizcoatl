#!/usr/bin/env python3
# Extract mbregex patterns from php-src ext/mbstring/tests/*.phpt and the
# PHP manual (php/doc-en reference/mbstring) examples.
# Usage: extract_php.py PHP_TREE DOC_EN_TREE > patterns/php.occurrences.jsonl
#
# Host configuration (php-src ext/mbstring/php_mbregex.c): default syntax
# ONIG_SYNTAX_RUBY, default options MULTILINE|SINGLELINE, encoding from
# mb_regex_encoding() (default UTF-8, or the mbstring.internal_encoding INI
# value).  An explicit option string replaces the default options and
# selects the syntax (letters j u g c r z b d); mb_eregi* add IGNORECASE;
# mb_regex_set_options() replaces the defaults for the rest of the script.
#
# Files are processed as bytes (latin-1 round trip), so patterns keep the
# bytes of the source file whatever its encoding.  Control flow is ignored:
# mb_regex_encoding()/mb_regex_set_options() calls apply to the calls that
# follow them in the text.
import json, re, sys, pathlib

IGNORECASE, EXTEND, MULTILINE, SINGLELINE, FIND_LONGEST, FIND_NOT_EMPTY = 1, 2, 4, 8, 16, 32
OPT_LETTERS = {'i': IGNORECASE, 'x': EXTEND, 'm': MULTILINE, 's': SINGLELINE,
               'p': MULTILINE | SINGLELINE, 'l': FIND_LONGEST, 'n': FIND_NOT_EMPTY}
SYN_LETTERS = {'j': 'JAVA', 'u': 'GNU_REGEX', 'g': 'GREP', 'c': 'EMACS', 'r': 'RUBY',
               'z': 'PERL', 'b': 'POSIX_BASIC', 'd': 'POSIX_EXTENDED'}
# name -> (pattern arg index, option arg index or None, adds IGNORECASE)
FUNCS = {
    'mb_ereg': (0, None, False), 'mb_eregi': (0, None, True),
    'mb_ereg_replace': (0, 3, False), 'mb_eregi_replace': (0, 3, True),
    'mb_ereg_replace_callback': (0, 3, False), 'mb_split': (0, None, False),
    'mb_ereg_match': (0, 2, False), 'mb_ereg_search_init': (1, 2, False),
    'mb_ereg_search': (0, 1, False), 'mb_ereg_search_pos': (0, 1, False),
    'mb_ereg_search_regs': (0, 1, False),
}
ENC_ALIASES = {}
for canon, names in {
    'EUC-JP': 'EUC-JP EUCJP X-EUC-JP UJIS EUCJP-WIN', 'UTF-8': 'UTF-8 UTF8',
    'UTF-16BE': 'UTF-16 UTF-16BE', 'UTF-16LE': 'UTF-16LE',
    'UTF-32BE': 'UCS-4 UTF-32 UTF-32BE', 'UTF-32LE': 'UCS-4LE UTF-32LE',
    'SJIS': 'SJIS CP932 MS932 SHIFT_JIS SJIS-WIN WINDOWS-31J',
    'BIG5': 'BIG5 BIG-5 BIGFIVE CN-BIG5 BIG-FIVE',
    'EUC-CN': 'EUC-CN EUCCN EUC_CN GB-2312 GB2312', 'EUC-TW': 'EUC-TW EUCTW EUC_TW',
    'EUC-KR': 'EUC-KR EUCKR EUC_KR', 'KOI8-R': 'KOI8R KOI8-R KOI-8R',
    'CP1251': 'CP1251 WIN-1251 WINDOWS-1251', 'ASCII': 'ASCII US-ASCII',
    'GB18030': 'GB18030 GB-18030',
}.items():
    for n in names.split():
        ENC_ALIASES[n] = canon
for i in list(range(1, 12)) + [13, 14, 15, 16]:
    ENC_ALIASES[f'ISO-8859-{i}'] = ENC_ALIASES[f'ISO8859-{i}'] = f'ISO-8859-{i}'

# ---------------------------------------------------------------- lexer
def lex(src):
    """Tokens: (kind, value, offset).  kind: id var str istr punct."""
    toks, i, n = [], 0, len(src)
    in_php = False
    while i < n:
        if not in_php:
            j = src.find('<?php', i); k = src.find('<?=', i)
            cands = [x for x in (j, k) if x >= 0]
            if not cands: break
            i = min(cands); i += 5 if src.startswith('<?php', i) else 3
            in_php = True; continue
        c = src[i]
        if src.startswith('?>', i):
            in_php = False; i += 2; toks.append(('punct', ';', i)); continue
        if c in ' \t\r\n': i += 1; continue
        if src.startswith('//', i) or (c == '#' and not src.startswith('#[', i)):
            while i < n and src[i] != '\n' and not src.startswith('?>', i): i += 1
            continue
        if src.startswith('/*', i):
            e = src.find('*/', i + 2); i = n if e < 0 else e + 2; continue
        if c == "'":
            j, out = i + 1, []
            while j < n and src[j] != "'":
                if src[j] == '\\' and j + 1 < n and src[j + 1] in "\\'":
                    out.append(src[j + 1]); j += 2
                else:
                    out.append(src[j]); j += 1
            toks.append(('str', ''.join(out), i)); i = j + 1; continue
        if c == '"':
            j = i + 1
            while j < n and src[j] != '"':
                j += 2 if src[j] == '\\' else 1
            body = src[i + 1:j]
            v = dq_unescape(body, '"')
            toks.append(('str', v, i) if v is not None else ('istr', body, i)); i = j + 1; continue
        m = re.compile(r'<<<[ \t]*(["\']?)([A-Za-z_][A-Za-z0-9_]*)\1\r?\n').match(src, i)
        if m:
            q, ident = m.group(1), m.group(2)
            e = re.compile(r'\n([ \t]*)' + ident + r'\b').search(src, m.end() - 1)
            if not e:
                i = n; continue
            body, indent = src[m.end():e.start()], e.group(1)
            if indent:
                body = '\n'.join(l[len(indent):] if l.startswith(indent) else l for l in body.split('\n'))
            if q == "'":
                toks.append(('str', body, i))
            else:
                v = dq_unescape(body, None)
                toks.append(('str', v, i) if v is not None else ('istr', body, i))
            i = e.end(); continue
        m = re.compile(r'\$[A-Za-z_\x80-\xff][A-Za-z0-9_\x80-\xff]*').match(src, i)
        if m: toks.append(('var', m.group(0), i)); i = m.end(); continue
        m = re.compile(r'[A-Za-z_\x80-\xff\\][A-Za-z0-9_\x80-\xff\\]*').match(src, i)
        if m: toks.append(('id', m.group(0), i)); i = m.end(); continue
        m = re.compile(r'->|::|=>|\.\.\.|[0-9][0-9A-Za-z_.]*').match(src, i)
        if m: toks.append(('punct', m.group(0), i)); i = m.end(); continue
        toks.append(('punct', c, i)); i += 1
    return toks

def dq_unescape(s, quote):
    """Unescape a double-quoted / heredoc body; None if it interpolates."""
    out, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if c == '$' and i + 1 < n and (s[i + 1].isalpha() or s[i + 1] in '_{' or ord(s[i + 1]) >= 0x80):
            return None
        if c == '{' and i + 1 < n and s[i + 1] == '$':
            return None
        if c == '\\' and i + 1 < n:
            d = s[i + 1]
            simple = {'n': '\n', 't': '\t', 'r': '\r', 'v': '\v', 'e': '\x1b', 'f': '\f',
                      '\\': '\\', '$': '$'}
            if quote and d == quote: out.append(d); i += 2; continue
            if d in simple: out.append(simple[d]); i += 2; continue
            m = re.compile(r'[0-7]{1,3}').match(s, i + 1)
            if m: out.append(chr(int(m.group(0), 8) & 0xFF)); i = m.end(); continue
            m = re.compile(r'x([0-9A-Fa-f]{1,2})').match(s, i + 1)
            if m: out.append(chr(int(m.group(1), 16))); i = m.end(); continue
            m = re.compile(r'u\{([0-9A-Fa-f]+)\}').match(s, i + 1)
            if m:
                out.append(chr(int(m.group(1), 16)).encode('utf-8', 'surrogatepass').decode('latin-1')); i = m.end(); continue
            out.append('\\'); i += 1; continue
        out.append(c); i += 1
    return ''.join(out)

def args_of(toks, k):
    """toks[k] is '('.  Return list of token lists for each argument."""
    depth, args, cur = 0, [], []
    for j in range(k, len(toks)):
        t = toks[j]
        if t[0] == 'punct' and t[1] in '([{':
            depth += 1
            if depth == 1: continue
        elif t[0] == 'punct' and t[1] in ')]}':
            depth -= 1
            if depth == 0:
                if cur or args: args.append(cur)
                return args
        elif t[0] == 'punct' and t[1] == ',' and depth == 1:
            args.append(cur); cur = []; continue
        cur.append(t)
    return args

def lit(arg):
    if arg is None: return 'absent', None
    if len(arg) == 1 and arg[0][0] == 'str': return 'lit', arg[0][1]
    if len(arg) == 1 and arg[0][0] == 'id' and arg[0][1].lower() == 'null': return 'null', None
    return 'nonlit', None

def parse_opts(s):
    opts, syn, bad = 0, 'RUBY', False
    for c in s:
        if c in OPT_LETTERS: opts |= OPT_LETTERS[c]
        elif c in SYN_LETTERS: syn = SYN_LETTERS[c]
        else: bad = True
    return opts, syn, bad

def process(rel, src, ini_enc, emit, source):
    toks = lex(src)
    enc = ENC_ALIASES.get((ini_enc or 'UTF-8').upper(), 'UTF-8')
    enc_known = True
    dopts, dsyn = MULTILINE | SINGLELINE, 'RUBY'
    line_of = lambda off: src.count('\n', 0, off) + 1
    for k, t in enumerate(toks):
        if t[0] != 'id' or k + 1 >= len(toks) or toks[k + 1][1] != '(':
            continue
        if k > 0 and toks[k - 1][1] in ('function', '->', '::'):
            continue
        name = t[1].lstrip('\\').lower()
        args = None
        if name == 'mb_regex_encoding':
            args = args_of(toks, k + 1)
            if args:
                kind, v = lit(args[0])
                if kind == 'lit' and v.upper() in ENC_ALIASES:
                    enc, enc_known = ENC_ALIASES[v.upper()], True
                elif kind != 'absent':
                    enc_known = False
            continue
        if name == 'mb_regex_set_options':
            args = args_of(toks, k + 1)
            if args:
                kind, v = lit(args[0])
                if kind == 'lit':
                    o, s, bad = parse_opts(v)
                    if not bad: dopts, dsyn = o, s
            continue
        if name not in FUNCS: continue
        pi, oi, ci = FUNCS[name]
        args = args_of(toks, k + 1)
        parg = args[pi] if pi < len(args) else None
        oarg = args[oi] if oi is not None and oi < len(args) else None
        pk, pv = lit(parg)
        ok, ov = lit(oarg)
        if pk == 'absent':
            continue  # e.g. mb_ereg_search() reusing the init pattern
        status = 'literal'
        if pk != 'lit' or ok == 'nonlit':
            status = 'non-literal'
        if ok == 'lit':
            opts, syn, bad = parse_opts(ov)
            if bad: status = 'host-rejected-options'
        else:
            opts, syn = dopts, dsyn
        if ci: opts |= IGNORECASE
        rec = {'source': source, 'file': rel, 'line': line_of(t[2]), 'func': name,
               'pattern': None, 'pattern_hex': None, 'option_string': ov,
               'syntax': syn, 'options': opts, 'encoding': enc,
               'encoding_known': enc_known, 'status': status}
        if pk == 'lit':
            b = pv.encode('latin-1')
            rec['pattern_hex'] = b.hex()
            try:
                rec['pattern'] = b.decode('utf-8')
            except UnicodeDecodeError:
                rec['pattern'] = None
        emit(rec)

def phpt_sections(text):
    secs, cur, start = {}, None, {}
    for no, line in enumerate(text.split('\n'), 1):
        m = re.match(r'^--([A-Z_]+)--\s*$', line)
        if m: cur = m.group(1); secs[cur] = []; start[cur] = no; continue
        if cur: secs[cur].append(line)
    return {k: '\n'.join(v) for k, v in secs.items()}, start

def main():
    php, doc = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    emit = lambda r: print(json.dumps(r, ensure_ascii=False))
    for f in sorted((php / 'ext/mbstring/tests').glob('*.phpt')):
        text = f.read_bytes().decode('latin-1')
        secs, start = phpt_sections(text)
        sec = 'FILE' if 'FILE' in secs else 'FILEEOF'
        code = secs.get(sec)
        if code is None: continue
        def emit_abs(r, base=start[sec]):
            r['line'] += base
            emit(r)
        ini = secs.get('INI', '')
        m = re.search(r'mbstring\.internal_encoding\s*=\s*([^\s;]+)', ini) or \
            re.search(r'^\s*internal_encoding\s*=\s*([^\s;]+)', ini, re.M) or \
            re.search(r'default_charset\s*=\s*([^\s;]+)', ini)
        process(f.relative_to(php).as_posix(), code, m.group(1) if m else None, emit_abs, 'php-src')
    for f in sorted((doc / 'reference/mbstring').rglob('*.xml')):
        text = f.read_bytes().decode('latin-1')
        for m in re.finditer(r'<programlisting role="php">\s*<!\[CDATA\[(.*?)\]\]>', text, re.S):
            base = text.count('\n', 0, m.start(1))
            def emit_off(r, base=base):
                r['line'] += base
                emit(r)
            process(f.relative_to(doc).as_posix(), m.group(1), None, emit_off, 'php-doc')

main()
