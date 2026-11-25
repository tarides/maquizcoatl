"""Join the Debug and ASan outputs of probes/harness.c (or cases/nest.c)
per case id, as probes/compare.mjs does for its first two inputs:
columns id, pattern, subject, options, debug, asan, asan_same, sanitizer.
Usage: python3 -I join.py DEBUG.tsv ASAN.tsv ASAN.stderr > joined.tsv"""
import sys

def rows(f):
    with open(f, encoding="latin-1") as h:
        lines = [l.rstrip("\n").split("\t") for l in h if l.strip()]
    cols = lines[0]
    return [dict(zip(cols, l)) for l in lines[1:]]

dbg, asan, err = sys.argv[1:4]
a = {r["id"]: r for r in rows(asan)}
reports, cur = {}, None
for l in open(err, encoding="latin-1"):
    if l.startswith("@@probe "):
        cur = l.split()[1]
    elif cur and ("ERROR: AddressSanitizer" in l or "runtime error" in l
                  or "LeakSanitizer" in l):
        reports[cur] = "report"
print("\t".join(["id", "options", "pattern", "subject", "debug", "asan",
                 "asan_same", "sanitizer"]))
for r in rows(dbg):
    x = a.get(r["id"], {}).get("result", "?")
    print("\t".join([r["id"], r["options"], r["pattern"], r["subject"],
                     r["result"], x, "yes" if x == r["result"] else "NO",
                     reports.get(r["id"], "none")]))
