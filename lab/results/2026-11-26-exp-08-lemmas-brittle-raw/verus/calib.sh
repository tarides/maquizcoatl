#!/bin/bash
# Issue #34, run 4: recheck of Verus's rlimit unit (untimed, not in the
# matrix): nice -n 10, CPUs 8-11, after the matrix ended.
#   BENCH_WORKDIR=<bench-workdir> calib.sh <R>
set -uo pipefail
: "${BENCH_WORKDIR:?}"
E=$BENCH_WORKDIR/exp/08-discriminating-lemmas; R=${1:?rlimit}
B=$E/build/verus/r4-calib-$R; rm -rf "$B"; mkdir -p "$B" "$E/out/r4/calib"; cd "$B"
for m in lib fold fold_proof absent desugar absent_mono absent_proof cases; do cp "$E/repo/lab/08-discriminating-lemmas/verus/$m.rs" .; done
. "$BENCH_WORKDIR/cache/verus-env.sh"
nice -n 10 taskset -c 8-11 verus --crate-type=lib --num-threads 4 --output-json --time-expanded \
  --rlimit "$R" --verify-module absent_proof lib.rs > "$E/out/r4/calib/r$R.json" 2> "$E/out/r4/calib/r$R.err"
echo "rc=$?"
python3 -I - "$E/out/r4/calib/r$R.json" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
print("verification results:", d.get("verification-results"))
rows = [(fb.get("rlimit", 0), fb["function"], fb.get("success")) for mt in d["times-ms"]["smt"]["smt-run-module-times"] for fb in mt.get("function-breakdown", [])]
for r in sorted(rows, reverse=True)[:8]:
    print(*r)
EOF
rm -rf "$B"
