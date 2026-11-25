#!/bin/bash
# Experiment #9, Verus M1.  BENCH_WORKDIR=<bench-workdir> verus/verus.sh build <run-id>
# build: verify the definitions (crate lib.rs: syntax, sem, compile, vm,
#        statement; `verus --crate-type=lib`), then verify and compile the
#        driver crate main.rs (the same modules, plus experiment #6's
#        spec2.rs, unchanged, over its stub table module tables2.rs) with
#        Verus's rustc, -C opt-level=3; run it on the fragment's cases
#        and the extra probes (untimed: nice -n 10, CPUs 4-7).  The timed
#        checks are timed.sh's.
# Prints no hostnames, addresses or absolute paths.
set -euo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory}"
PHASE=${1:?phase} RID=${2:?run-id}
CACHE=$BENCH_WORKDIR/cache; EXP=$BENCH_WORKDIR/exp/09-representative-proof
L=$EXP/repo/lab/09-representative-proof; E06=$EXP/repo/lab/06-spec-speed/verus
OUT=$EXP/out/$RID/verus; mkdir -p "$OUT"
. "$CACHE/verus-env.sh"
case $PHASE in
build)
  B=$EXP/build/verus/$RID; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L"/verus/*.rs "$E06/spec2.rs" "$E06/stub/tables2.rs" .
  U="nice -n 10 taskset -c 4-7"
  { verus --version; "${VERUS_Z3_PATH:-$(dirname "$(command -v verus)")/z3}" --version; } > "$OUT/version.txt" 2>&1
  { echo "== lib"; $U verus --crate-type=lib lib.rs
    echo "== driver"; $U verus main.rs --compile -- -C opt-level=3 -o verus_e09
  } > "$OUT/build.log" 2>&1
  sed -i "s|$BENCH_WORKDIR|<bench-workdir>|g" "$OUT/build.log"
  for c in fragment extra; do $U ./verus_e09 "$L/cases/$c.tsv" > "$OUT/$c.verdicts.txt"; done
  wc -l "$OUT"/*.verdicts.txt | sed 's|/.*/||' ;;
*) echo "unknown phase $PHASE" >&2; exit 2 ;;
esac
