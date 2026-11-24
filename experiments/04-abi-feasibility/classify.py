#!/usr/bin/env python3
"""classify.py SRCDIR DEFAULT.nm POSIX.nm > symbols.tsv

Classifies every symbol exported by the oracle builds as public
(declared in an installed header: oniguruma.h, oniggnu.h, onigposix.h)
or internal (declared only in regenc.h, or nowhere). Output columns:
name, kind (F function / D data), class, header:line, builds.
"""
import re, sys
src, fdef, fpos = sys.argv[1:4]
PUBLIC = ["oniguruma.h", "oniggnu.h", "onigposix.h"]
INTERNAL = ["regenc.h", "regint.h", "regparse.h", "st.h"]
lines = {h: open(f"{src}/{h}", encoding="latin-1").read().split("\n")
         for h in PUBLIC + INTERNAL}

def decl(name):
    pat = re.compile(r"\b%s\b" % re.escape(name))
    for group in (PUBLIC, INTERNAL):
        for h in group:
            for i, l in enumerate(lines[h], 1):
                s = l.strip()
                if pat.search(l) and not s.startswith("#define") \
                   and not s.startswith("/*") and not s.startswith("*"):
                    return h, i
    return None, None

def load(f):
    d = {}
    for l in open(f):
        n, t = l.split()
        d[n] = "F" if t in "Tt" else "D"
    return d
dd, dp = load(fdef), load(fpos)
print("name\tkind\tclass\tdeclared\tbuilds")
for n in sorted(set(dd) | set(dp)):
    k = dd.get(n) or dp.get(n)
    h, i = decl(n)
    cls = "public" if h in PUBLIC else "internal"
    where = f"src/{h}:{i}" if h else "-"
    b = ",".join(x for x, d in (("default", dd), ("posix", dp)) if n in d)
    print(f"{n}\t{k}\t{cls}\t{where}\t{b}")
