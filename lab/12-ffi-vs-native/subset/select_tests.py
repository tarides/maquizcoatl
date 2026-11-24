#!/usr/bin/env python3
"""Experiment #12: extract every x2, x3, n and e case of
upstream/test/test_utf8.c (with its line number) into the case format
read by `main.exe tests`:  line kind hexpattern hexsubject a b c
(x2: a=from b=to; x3: a=from b=to c=mem; e: a=error code; n: unused).
The subset classifier runs inside `main.exe tests` (the VM's parser in
strict mode, ONIG_SYNTAX_ONIGURUMA = ONIG_SYNTAX_DEFAULT); this script
only extracts.  Cases whose arguments are not plain C string literals
and integer constants are listed on stderr and counted as "unparsed".

usage: python3 -I select_tests.py UPSTREAM_DIR > cases.txt
"""
import re, sys

TOKEN = re.compile(r'\s*("(?:[^"\\]|\\.)*"|[-A-Za-z_0-9]+)\s*')


def c_string(lit):
    s = lit[1:-1]
    out = bytearray()
    i = 0
    while i < len(s):
        ch = s[i]
        if ch != "\\":
            out += ch.encode("utf-8")
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


def main():
    src = sys.argv[1] + "/src/oniguruma.h"
    errs = {}
    for l in open(src, encoding="latin-1"):
        m = re.match(r"#define\s+(ONIGERR_\w+)\s+(-?\d+)", l)
        if m:
            errs[m.group(1)] = int(m.group(2))
    total = unparsed = 0
    path = sys.argv[1] + "/test/test_utf8.c"
    for no, l in enumerate(open(path, encoding="latin-1"), 1):
        m = re.match(r"\s*(x2|x3|n|e)\((.*)\);", l)
        if not m:
            continue
        total += 1
        kind, args = m.group(1), m.group(2)
        toks, pos = [], 0
        ok = True
        while pos < len(args):
            t = TOKEN.match(args, pos)
            if not t:
                ok = False
                break
            toks.append(t.group(1))
            pos = t.end()
            if pos < len(args):
                if args[pos] != ",":
                    ok = False
                    break
                pos += 1
        if not ok or not toks[0].startswith('"') or not toks[1].startswith('"'):
            unparsed += 1
            print(f"unparsed line {no}: {l.strip()}", file=sys.stderr)
            continue
        # latin-1 read: re-encode bytes faithfully
        pat = c_string(toks[0].encode("latin-1").decode("utf-8", "surrogateescape"))
        sub = c_string(toks[1].encode("latin-1").decode("utf-8", "surrogateescape"))
        nums = []
        for t in toks[2:]:
            nums.append(errs[t] if t in errs else int(t))
        nums += [0] * (3 - len(nums))
        print(no, kind, pat.hex(), sub.hex(), *nums[:3])
    print(f"extracted={total - unparsed} unparsed={unparsed}", file=sys.stderr)


if __name__ == "__main__":
    main()
