#!/usr/bin/env python3
"""Experiment #6: extract the test cases of the seven upstream suites.

Extends experiment #12's select_tests.py (test_utf8 only) to every
suite, multi-line calls included.  One line per case, tab-separated:

  suite line kind enc syntax options dir pat_hex sub_hex a b c

kind: x2 (a=from b=to), x3 (a=from b=to c=mem), n, e (a=error code),
      rx2/rx3/rn/rnzero for test_regset (pattern-array name in pat_hex
      field as text, subject hex).
enc: UTF8, EUC_JP, UTF16_BE.  syntax: ONIGURUMA (= ONIG_SYNTAX_DEFAULT)
or the test_syntax flavour.  options: integer.  dir: fwd or back.

usage: python3 -I extract.py UPSTREAM_DIR > all.tsv   (counts on stderr)
"""
import re, sys

EXPECTED = {"test_utf8": 1554, "test_back": 1225, "testc": 785,
            "testu": 720, "test_syntax": 221, "test_options": 47,
            "test_regset": 13}


def c_string_body(s):
    out = bytearray()
    i = 0
    while i < len(s):
        ch = s[i]
        if ch != "\\":
            out += ch.encode("latin-1")
            i += 1
            continue
        i += 1
        e = s[i]
        if e == "x":
            j = i + 1
            while j < len(s) and s[j] in "0123456789abcdefABCDEF":
                j += 1
            out.append(int(s[i + 1:j], 16) & 0xFF)
            i = j
        elif e in "uU":
            k = 4 if e == "u" else 8
            out += chr(int(s[i + 1:i + 1 + k], 16)).encode("utf-8")
            i += 1 + k
        elif e in "01234567":
            j = i
            while j < len(s) and j < i + 3 and s[j] in "01234567":
                j += 1
            out.append(int(s[i:j], 8) & 0xFF)
            i = j
        else:
            out += {"n": b"\n", "t": b"\t", "r": b"\r", "f": b"\f", "v": b"\v",
                    "a": b"\a", "b": b"\b", "e": b"\x1b", "\\": b"\\", '"': b'"',
                    "'": b"'", "?": b"?"}[e]
            i += 1
    return bytes(out)


TOK = re.compile(r'\s*(?:(//[^\n]*|/\*.*?\*/)|("(?:[^"\\]|\\.)*")|([A-Za-z_0-9]+)|(.))',
                 re.S)


def parse_args(text, pos):
    """text[pos] is just after '('.  Returns (args, endpos) where each
    arg is ('s', bytes) | ('i', int-or-name-list)."""
    args, cur, depth = [], [], 0
    while True:
        m = TOK.match(text, pos)
        if m is None:
            raise ValueError("eof in call")
        pos = m.end()
        if m.group(1):
            continue
        if m.group(2):
            cur.append(("s", c_string_body(m.group(2)[1:-1])))
        elif m.group(3):
            cur.append(("w", m.group(3)))
        else:
            c = m.group(4)
            if c == "(":
                depth += 1
                cur.append(("p", c))
            elif c == ")" and depth > 0:
                depth -= 1
                cur.append(("p", c))
            elif c in ",)" and depth == 0:
                args.append(cur)
                cur = []
                if c == ")":
                    return args, pos
            else:
                cur.append(("p", c))


def arg_value(toks, consts):
    if toks and all(t[0] == "s" for t in toks):
        return b"".join(t[1] for t in toks)
    v = 0
    neg = False
    for kind, t in toks:
        if kind == "p" and t == "-":
            neg = True
        elif kind == "p" and t in "|()":
            continue
        elif kind == "w":
            if re.fullmatch(r"\d+", t):
                x = int(t)
            elif t in consts:
                x = consts[t]
            else:
                raise KeyError(t)
            v = v | (-x if neg else x)
            neg = False
        else:
            raise ValueError(toks)
    return v


def load_consts(up):
    consts = {}
    for l in open(up + "/src/oniguruma.h", encoding="latin-1"):
        m = re.match(r"#define\s+(ONIG(?:ERR|_OPTION)_\w+)\s+(.*)", l)
        if m:
            consts[m.group(1)] = m.group(2).split("/*")[0].strip()
    out = {}
    def ev(name, seen=()):
        if name in out:
            return out[name]
        e = consts[name]
        e = re.sub(r"\b(ONIG_OPTION_\w+)\b", lambda m: str(ev(m.group(1))), e)
        e = e.replace("U", "") if re.fullmatch(r"[\d\sU<()|+-]+", e) else e
        v = int(eval(e, {"__builtins__": {}}))
        out[name] = v
        return v
    for k in consts:
        try:
            ev(k)
        except Exception:
            pass
    out["ONIG_OPTION_NONE"] = 0
    out["OIA"] = out["ONIG_OPTION_IGNORECASE"] | out["ONIG_OPTION_IGNORECASE_IS_ASCII"]
    return out


CALL = re.compile(r"(?m)(?<![A-Za-z_0-9])(x2|x3|n|e|X2|X3|N|NZERO)\s*\(")
FUNHDR = re.compile(r"(?m)^(?:static\s+|extern\s+)?(?:int|void)\s*\n?\s*([A-Za-z_]\w*)\s*\([^;{]*\)\s*\{")


def strip_ifdefs(text, drop):
    """Remove #if 0 blocks and blocks guarded by macros in `drop`
    (kept: #else branches).  Line numbers are preserved."""
    out, stack = [], []
    for l in text.split("\n"):
        s = l.strip()
        if re.match(r"#\s*if", s):
            active = not (re.match(r"#\s*if\s+0\b", s) or
                          any(re.match(r"#\s*ifdef\s+" + d + r"\b", s) for d in drop))
            stack.append(active)
            out.append("")
            continue
        if re.match(r"#\s*else", s) and stack:
            stack[-1] = not stack[-1]
            out.append("")
            continue
        if re.match(r"#\s*endif", s) and stack:
            stack.pop()
            out.append("")
            continue
        out.append(l if all(stack) else "")
    return "\n".join(out)


def calls(text):
    """Yield (func, name, line, args-token-lists) for statement calls."""
    funcs = [(m.start(), m.group(1)) for m in FUNHDR.finditer(text)]
    for m in CALL.finditer(text):
        before = text[:m.start()].rstrip(" \t")
        if before and before[-1] not in "\n;{}":
            continue
        line_start = text.rfind("\n", 0, m.start()) + 1
        if text[line_start:m.start()].strip().startswith("#"):
            continue
        args, end = parse_args(text, m.end())
        if any(t[0] == "w" and t[1] in ("char", "int", "OnigOptionType")
               for a in args for t in a):
            continue  # a definition
        rest = text[end:end + 3].lstrip()
        if not rest.startswith(";"):
            continue
        func = None
        for st, name in funcs:
            if st < m.start():
                func = name
        yield func, m.group(1), text.count("\n", 0, m.start()) + 1, args


def emit(rows, suite, line, kind, enc, syn, opt, d, pat, sub, nums):
    nums = list(nums) + [0] * (3 - len(nums))
    rows.append((suite, line, kind, enc, syn, opt, d,
                 pat.hex() if isinstance(pat, bytes) else pat,
                 sub.hex(), *nums[:3]))


def simple_suite(up, consts, suite, fname, enc, d, with_opt=False):
    text = strip_ifdefs(open(up + "/test/" + fname, encoding="latin-1").read(),
                        ["POSIX_TEST", "_WIN32", "__TRUSTINSOFT_ANALYZER__"])
    rows = []
    for func, kind, line, args in calls(text):
        if kind not in ("x2", "x3", "n", "e"):
            continue
        vals = [arg_value(a, consts) for a in args]
        opt = 0
        if with_opt:
            opt, vals = vals[0], vals[1:]
        emit(rows, suite, line, kind, enc, "ONIGURUMA", opt, d, vals[0], vals[1], vals[2:])
    return rows


def syntax_suite(up, consts):
    text = strip_ifdefs(open(up + "/test/test_syntax.c", encoding="latin-1").read(),
                        ["POSIX_TEST", "_WIN32", "__TRUSTINSOFT_ANALYZER__"])
    per_func = {}
    for func, kind, line, args in calls(text):
        if kind not in ("x2", "x3", "n", "e"):
            continue
        vals = [arg_value(a, consts) for a in args]
        per_func.setdefault(func, []).append((line, kind, vals))
    # walk main: Syntax assignments, helper calls, direct cases (by line)
    mstart = text.index("extern int main(")
    body = text[mstart:]
    base = text.count("\n", 0, mstart)
    events = []
    for m in re.finditer(r"Syntax\s*=\s*ONIG_SYNTAX_(\w+)\s*;", body):
        events.append((base + body.count("\n", 0, m.start()) + 1, "syn", m.group(1)))
    for m in re.finditer(r"(?m)^\s*(test_\w+)\s*\(\s*\)\s*;", body):
        events.append((base + body.count("\n", 0, m.start()) + 1, "call", m.group(1)))
    for line, kind, vals in per_func.get("main", []):
        events.append((line, "case", (kind, vals)))
    events.sort(key=lambda e: e[0])
    rows, syn = [], None
    for line, ev, x in events:
        if ev == "syn":
            syn = x
        elif ev == "call":
            for l2, kind, vals in per_func.get(x, []):
                emit(rows, "test_syntax", l2, kind, "UTF8", syn, 0, "fwd",
                     vals[0], vals[1], vals[2:])
        else:
            kind, vals = x
            emit(rows, "test_syntax", line, kind, "UTF8", syn, 0, "fwd",
                 vals[0], vals[1], vals[2:])
    return rows


def regset_suite(up, consts):
    text = strip_ifdefs(open(up + "/test/test_regset.c", encoding="latin-1").read(),
                        ["_WIN32_XX"])
    mstart = text.index("main(int argc")
    rows = []
    for func, kind, line, args in calls(text):
        if text.count("\n", 0, mstart) + 1 > line or kind not in ("X2", "X3", "N", "NZERO"):
            continue
        if any(t == ("w", "s") for a in args for t in a):
            continue  # file-based cases, only when TEXT_PATH exists
        if kind == "NZERO":
            emit(rows, "test_regset", line, "rnzero", "UTF8", "ONIGURUMA", 0, "fwd",
                 "-", arg_value(args[0], consts), [])
            continue
        name = args[0][0][1]
        vals = [arg_value(a, consts) for a in args[1:]]
        emit(rows, "test_regset", line, "r" + kind.lower(), "UTF8", "ONIGURUMA", 0,
             "fwd", name, vals[0], vals[1:])
    return rows


def main():
    up = sys.argv[1]
    consts = load_consts(up)
    rows = []
    rows += simple_suite(up, consts, "test_utf8", "test_utf8.c", "UTF8", "fwd")
    rows += simple_suite(up, consts, "test_back", "test_back.c", "UTF8", "back")
    rows += simple_suite(up, consts, "testc", "testc.c", "EUC_JP", "fwd")
    rows += simple_suite(up, consts, "testu", "testu.c", "UTF16_BE", "fwd")
    rows += syntax_suite(up, consts)
    rows += simple_suite(up, consts, "test_options", "test_options.c", "UTF8", "fwd",
                         with_opt=True)
    rows += regset_suite(up, consts)
    for r in rows:
        print("\t".join(str(x) for x in r))
    ok = True
    for s, exp in EXPECTED.items():
        got = sum(1 for r in rows if r[0] == s)
        ok &= got == exp
        print(f"{s}\t{got}\texpected {exp}\t{'ok' if got == exp else 'MISMATCH'}",
              file=sys.stderr)
    print(f"total\t{len(rows)}\texpected 4565\t{'ok' if len(rows) == 4565 else 'MISMATCH'}",
          file=sys.stderr)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
