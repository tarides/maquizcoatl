#!/usr/bin/env python3
# Experiment #9, run 14 (plan step 7, M3): the Verus side of brittle.sh.
# Reads one check's output (Verus --output-json on stdout, diagnostics on
# stderr) and prints, tab-separated, on one line:
#   verified errors smt_run_ms rlimit_run max_fn_rlimit max_fn failing
# and appends one row per verified function to <functions.tsv>:
#   version seed label module function mode time_ms rlimit success
# usage: brittle_verus.py <out.json> <err.txt> <srcdir> <functions.tsv> <version> <seed> <label>
# failing: one item per problem, "; "-separated, "-" when none:
#   failed:<function>               a function whose SMT run did not succeed
#                                   (JSON function breakdown, success false)
#   Error"<message>"@<file>:<line>(<fn>)  each "error:" diagnostic on
#                                   stderr with its first "-->" location and
#                                   the fn enclosing that line in the source
#   no-json:<first error line>      when no JSON was produced (for example
#                                   the solver-version refusal)
# Run with python3 -I.  Prints no absolute paths (file names only).
import json
import os
import re
import sys

out_json, err_txt, srcdir, fun_tsv, ver, seed, label = sys.argv[1:8]


def enclosing_fn(path, line):
    try:
        with open(os.path.join(srcdir, os.path.basename(path))) as f:
            lines = f.readlines()
    except OSError:
        return "?"
    for i in range(min(line, len(lines)) - 1, -1, -1):
        m = re.search(r'\bfn\s+([A-Za-z_][A-Za-z0-9_]*)', lines[i])
        if m:
            return m.group(1)
    return "?"


items = []
err = open(err_txt, errors="replace").read().splitlines()
first_error = None
i = 0
while i < len(err):
    m = re.match(r'^error(\[E\d+\])?: (.*)$', err[i])
    if m:
        msg = m.group(2).strip()
        if first_error is None:
            first_error = msg
        loc = None
        for j in range(i + 1, min(i + 6, len(err))):
            n = re.match(r'^\s*--> (.*):(\d+):(\d+)$', err[j])
            if n:
                loc = (os.path.basename(n.group(1)), int(n.group(2)))
                break
            if re.match(r'^(error|warning|note)', err[j]):
                break
        if loc and not msg.startswith("aborting due to"):
            items.append('Error"%s"@%s:%d(%s)' % (msg, loc[0], loc[1], enclosing_fn(loc[0], loc[1])))
        elif not msg.startswith("aborting due to"):
            items.append('Error"%s"' % msg)
    i += 1

try:
    d = json.load(open(out_json))
except (OSError, ValueError):
    d = None

if d is None:
    if not items:
        items.append("no-json:%s" % (first_error or (err[0] if err else "no output")))
    else:
        items.insert(0, "no-json")
    print("\t".join(["0", "0", "0", "0", "0", "-", "; ".join(items)]))
    sys.exit(0)

vr = d.get("verification-results", {})
smt = d.get("times-ms", {}).get("smt", {})
rows = []
for mt in smt.get("smt-run-module-times", []):
    for fb in mt.get("function-breakdown", []):
        rows.append((mt["module"], fb["function"], fb.get("mode:", fb.get("mode", "")),
                     fb.get("time", 0), fb.get("rlimit", 0), fb.get("success")))
with open(fun_tsv, "a") as f:
    for r in rows:
        f.write("\t".join([ver, seed, label] + [str(x) for x in r]) + "\n")
failed = ["failed:%s" % r[1] for r in rows if r[5] is not True]
items = failed + items
mx = max(rows, key=lambda r: r[4]) if rows else ("", "-", "", 0, 0, True)
print("\t".join([str(vr.get("verified", 0)), str(vr.get("errors", 0)),
                 str(smt.get("smt-run", 0)), str(smt.get("rlimit-run", 0)),
                 str(mx[4]), mx[1], "; ".join(items) or "-"]))
