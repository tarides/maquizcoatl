#!/bin/bash
# Issue #34, run 5: the supplementary Verus timing without the cases file,
# as run 3 did by hand (entry 7): timed.sh verus conditions (fresh copy,
# taskset -c 24-27,56-59, /usr/bin/time -v, 16G cgroup, --num-threads 7,
# load average before each check), with "pub mod cases;" removed from
# lib.rs and cases.rs not copied.  Starts after drive-r5.sh (waits for its
# pid), with the precheck of drive-r5.sh before each of the three checks.
#   BENCH_WORKDIR=<bench-workdir> timed-nocases-r5.sh <drive-pid>
set -uo pipefail
: "${BENCH_WORKDIR:?}"
EXP=$BENCH_WORKDIR/exp/08-discriminating-lemmas; cd "$EXP" || exit 2
while kill -0 "${1:?pid}" 2>/dev/null; do sleep 20; done
L=$EXP/repo/lab/08-discriminating-lemmas
OUT=$EXP/out/r5/verus-nocases; mkdir -p "$OUT"; P=$EXP/out/r5/precheck.txt
eval "$(sed -n '/^ME=/,/^cell()/p' drive-r5.sh | sed '$d')"
. "$BENCH_WORKDIR/cache/env.sh"; . "$BENCH_WORKDIR/cache/verus-env.sh"
chk() { verus --crate-type=lib --num-threads 7 lib.rs; }; export -f chk
for r in 1 2 3; do
  B=$EXP/build/verus/r5-nocases-t$r; mkdir "$B" || exit 3
  cp "$L"/verus/{lib,fold,fold_proof,absent,desugar,absent_mono,absent_proof}.rs "$B/"
  sed -i '/^pub mod cases;$/d' "$B/lib.rs"; cd "$B"
  sha256sum *.rs > "$OUT/sha256.$r"
  precheck "nocases_$r"
  echo "$r lib $(cut -d' ' -f1-3 /proc/loadavg)" >> "$OUT/time.load"
  flock "$EXP/timed.lock" systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 \
    /usr/bin/time -v -o "$OUT/time.$r.lib" taskset -c 24-27,56-59 bash -c chk >> "$OUT/time.log" 2>&1
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$r" lib \
    "$(sed -n 's/.*Elapsed (wall clock) time (h:mm:ss or m:ss): //p' "$OUT/time.$r.lib")" \
    "$(sed -n 's/.*Maximum resident set size (kbytes): //p' "$OUT/time.$r.lib")" \
    "$(sed -n 's/.*User time (seconds): //p' "$OUT/time.$r.lib")" \
    "$(sed -n 's/.*System time (seconds): //p' "$OUT/time.$r.lib")" >> "$OUT/time.tsv"
done
sed -i "s|$BENCH_WORKDIR|<bench-workdir>|g; s|$HOME|~|g" "$OUT/time.log"
cat "$OUT/time.tsv"
