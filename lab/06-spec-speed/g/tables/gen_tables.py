#!/usr/bin/env python3
"""Experiment #6 milestone 2: emit the case-fold and property tables of
Oniguruma f95747b, read as data from the upstream sources.

  python3 -I gen_tables.py UPSTREAM_DIR > tables.txt

Lines (tab-separated, all numbers hexadecimal):
  F <src> <f1>[,<f2>[,<f3>]]   full case fold of <src> (OnigUnicodeFolds1/2/3
                               up to FOLDSn_END_INDEX: the "LOCALE"
                               entries after FOLDSn_NORMAL_END_INDEX (I/i,
                               U+0130) apply when the Turkish/Azeri flag is
                               off, which is the default,
                               upstream/src/unicode.c:235-290)
  N <name> <ctype>             property name (lower case, without ' ',
                               '-', '_') to ctype, decimal
  R <ctype> <lo>-<hi>,...      code ranges of a ctype (decimal ctype);
                               for the standard ctypes (0..14) the part
                               below U+0100 is taken from
                               EncUNICODE_ISO_8859_1_CtypeTable, as
                               onigenc_unicode_is_code_ctype does
                               (upstream/src/unicode.c:1142-1146)
The data derive from Oniguruma (Copyright (c) 2002-2025 K.Kosako,
BSD-2-Clause) and the Unicode Character Database.
"""
import re, sys

up = sys.argv[1] + "/src/"

def body(text, start_pat, end_pat="};"):
    i = text.index(start_pat)
    j = text.index(end_pat, i)
    return text[i:j]

def nums(s):
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
    s = re.sub(r"(?m)^#.*$", "", s)
    return [int(x, 0) for x in re.findall(r"0x[0-9a-fA-F]+|\b\d+\b", s)]

fd = open(up + "unicode_fold_data.c").read()
def define(name):
    return int(re.search(r"#define %s\s+(\d+)" % name, fd).group(1))

fold = {}
def folds(arrname, k, end):
    a = nums(body(fd, "OnigUnicodeFolds%s[] = {" % arrname).split("{", 1)[1])
    i = 0
    while i < end:
        f = a[i:i + k]; n = a[i + k]; us = a[i + k + 1:i + k + 1 + n]
        for u in us:
            # a multi-character fold wins over a simple one
            if u not in fold or len(fold[u]) < k:
                fold[u] = f
        i += k + 1 + n
folds("1", 1, define("FOLDS1_END_INDEX"))
folds("2", 2, define("FOLDS2_END_INDEX"))
folds("3", 3, define("FOLDS3_END_INDEX"))
# a code point that is itself a fold target folds to itself unless listed
for u in sorted(fold):
    print("F\t%x\t%s" % (u, ",".join("%x" % c for c in fold[u])))

pd = open(up + "unicode_property_data.c").read()
# ranges of every CR_ array
crs = {}
for m in re.finditer(r"static const OnigCodePoint\s*\n(CR_\w+)\[\] = \{(.*?)\};", pd, re.S):
    a = nums(m.group(2))
    n = a[0]
    crs[m.group(1)] = [(a[1 + 2 * i], a[2 + 2 * i]) for i in range(n)]
for a, b in re.findall(r"#define (CR_\w+) (CR_\w+)", pd):
    crs[a] = crs[b]
order = re.findall(r"(CR_\w+)", body(pd, "CodeRanges[] = {"))
# property names: pool strings and the wordlist
pool = dict(re.findall(r'char unicode_prop_name_pool_str(\d+)\[sizeof\("([^"]*)"\)\];', pd))
for off, ct in re.findall(r"\{pool_offset\((\d+)\),\s*(\d+)\}", pd):
    print("N\t%s\t%s" % (pool[off], ct))

uc = open(up + "unicode.c").read()
iso = nums(body(uc, "EncUNICODE_ISO_8859_1_CtypeTable[256] = {").split("{", 1)[1])
assert len(iso) == 256, len(iso)
MAX_STD = 14

def to_ranges(cps):
    out = []
    for c in sorted(cps):
        if out and out[-1][1] + 1 == c:
            out[-1][1] = c
        else:
            out.append([c, c])
    return out

for ct, name in enumerate(order):
    rs = crs[name]
    if ct <= MAX_STD:
        low = [c for c in range(256) if iso[c] & (1 << ct)]
        high = [(max(lo, 256), hi) for lo, hi in rs if hi >= 256]
        rr = [tuple(r) for r in to_ranges(low)] + high
        # merge adjacent
        m = []
        for lo, hi in rr:
            if m and m[-1][1] + 1 >= lo:
                m[-1] = (m[-1][0], max(m[-1][1], hi))
            else:
                m.append((lo, hi))
        rs = m
    print("R\t%d\t%s" % (ct, ",".join("%x-%x" % r for r in rs)))
print("counts: folds=%d names=%d ctypes=%d" % (len(fold), len(pool), len(order)), file=sys.stderr)
