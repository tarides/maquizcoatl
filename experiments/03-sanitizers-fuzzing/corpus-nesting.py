"""Deepest parenthesis nesting in a fuzzer-deep corpus.

Usage: python3 -I corpus-nesting.py <corpus-dir>

Depth is the running count of "(" minus ")" (never below 0), maximised
over each file and then over the corpus. Two conventions are printed:
  after-control  all bytes after the 8 control bytes (pattern and
                 subject together): the figure quoted in the campaign
                 entry ("36").
  pattern-only   the pattern field only, whose size is the 2-byte
                 control field modulo the remaining length, as in
                 base-deep.c (ignoring ADJUST_LEN, a no-op for UTF-8).
Character classes ("[") are not counted.
"""
import os, sys

def depth(b):
    d = m = 0
    for c in b:
        if c == 0x28:
            d += 1
            m = max(m, d)
        elif c == 0x29:
            d = max(d - 1, 0)
    return m

after = pattern = files = 0
for dp, _, fs in os.walk(sys.argv[1]):
    for f in fs:
        b = open(os.path.join(dp, f), "rb").read()
        files += 1
        if len(b) <= 8:
            continue
        after = max(after, depth(b[8:]))
        size = (b[5] | b[6] << 8) % (len(b) - 8)
        pattern = max(pattern, depth(b[8:8 + size]))
print("files\t%d\nafter-control\t%d\npattern-only\t%d" % (files, after, pattern))
