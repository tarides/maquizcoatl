#!/usr/bin/env python3
"""Experiment #7 fidelity check.

fidelity.py <unicode_property_data.c> [<generator .gperf output>]
Checks the counts of the parsed table (612 arrays, 24,443 ranges, 629
CodeRanges entries, 886 names, CODE_RANGES_NUM, TOTAL_KEYWORDS), that
every array is sorted, disjoint and non-adjacent, and, if given, that
the CR_* arrays and the name list in the generator's output equal the
upstream file's.
"""
import importlib.util, os, re, sys
spec = importlib.util.spec_from_file_location("emit", os.path.join(os.path.dirname(os.path.abspath(__file__)), "emit.py"))
emit = importlib.util.module_from_spec(spec); spec.loader.exec_module(emit)

def arrays_of(text):
    out = {}
    for m in re.finditer(r"CR_(\w+)\[\]\s*=\s*\{\s*(\d+),(.*?)\};", text, re.S):
        nums = [int(x, 16) for x in re.findall(r"0x[0-9a-fA-F]+", re.sub(r"/\*.*?\*/", "", m.group(3), flags=re.S))]
        out[m.group(1)] = (int(m.group(2)), [(nums[i], nums[i + 1]) for i in range(0, len(nums), 2)])
    return out

t = emit.parse(sys.argv[1])
nranges = sum(len(v) for v in t["arrays"].values())
res = {"arrays": len(t["arrays"]), "ranges": nranges, "code_ranges": len(t["code_ranges"]),
       "CODE_RANGES_NUM": t["CODE_RANGES_NUM"], "aliases": len(t["aliases"]),
       "names": len(t["names"]), "TOTAL_KEYWORDS": t["TOTAL_KEYWORDS"],
       "distinct_name_ctypes": len(set(c for _, c in t["names"]))}
for k, v in res.items():
    print("%s\t%d" % (k, v))
ok = (res["arrays"], res["ranges"], res["code_ranges"], res["names"]) == (612, 24443, 629, 886) \
     and res["code_ranges"] == res["CODE_RANGES_NUM"] and res["names"] == res["TOTAL_KEYWORDS"]
bad = 0
for a, rs in t["arrays"].items():
    for i, (lo, hi) in enumerate(rs):
        if lo > hi or (i + 1 < len(rs) and not hi + 1 < rs[i + 1][0]):
            bad += 1
print("sorted_disjoint_nonadjacent_violations\t%d" % bad)
ok = ok and bad == 0
if len(sys.argv) > 2:
    g = open(sys.argv[2]).read()
    ga = arrays_of(g)
    up = arrays_of(open(sys.argv[1]).read())
    diff = sorted(set(ga) ^ set(up)) + [a for a in up if a in ga and ga[a] != up[a]]
    print("generator_arrays\t%d" % len(ga))
    print("generator_array_differences\t%d" % len(diff))
    for d in diff[:20]:
        print("  differs:", d)
    gn = sorted(re.findall(r"^([a-z0-9]+),\s*(\d+)$", g, re.M))
    gn = [(n, int(c)) for n, c in gn]
    print("generator_names\t%d" % len(gn))
    print("generator_name_differences\t%d" % len(set(gn) ^ set(t["names"])))
    ok = ok and not diff and set(gn) == set(t["names"])
print("fidelity\t%s" % ("OK" if ok else "FAIL"))
sys.exit(0 if ok else 1)
