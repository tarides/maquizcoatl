#!/bin/bash
# Experiment #9: build the C library (Release, out of tree) and the two
# oracles, then run them on the fragment's cases and the extra probes.
#   BENCH_WORKDIR=<bench-workdir> oracle/oracle.sh <run-id>
# Untimed: nice -n 10, 4 jobs, CPUs 4-7 (outside the timed complex).
# Prints no hostnames, addresses or absolute paths.
set -euo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory}"
EXP=$BENCH_WORKDIR/exp/09-representative-proof
L=$EXP/repo/lab/09-representative-proof
B=$EXP/build/onig; O=$EXP/build/oracle; RID=${1:?run-id}
OUT=$EXP/out/$RID/oracle; mkdir -p "$OUT" "$O"
RUNU="nice -n 10 taskset -c 4-7"
if [ ! -f "$B/libonig.a" ]; then
  cmake -S "$EXP/repo/upstream" -B "$B" -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF > "$O/cmake.log" 2>&1
  $RUNU make -C "$B" -j4 onig > "$O/make.log" 2>&1
fi
for o in oracle oracle_at; do
  $RUNU gcc -O2 -std=gnu99 -I"$EXP/repo/upstream/src" -I"$B" "$L/oracle/$o.c" \
        "$B/libonig.a" -o "$O/$o"
done
cd "$O"
for c in fragment extra; do
  ./oracle "$L/cases/$c.tsv" 1 > "$OUT/$c.search.txt" 2> "$OUT/$c.search.timing.txt"
  ./oracle_at "$L/cases/$c.tsv" > "$OUT/$c.at.txt"
done
grep -c . "$OUT"/*.txt | sed 's|.*/||'
grep -h "LIMIT\|ERR" "$OUT"/*.search.txt "$OUT"/*.at.txt > "$OUT/excluded.txt" || true
echo "excluded (retry limit or error): $(grep -c . "$OUT/excluded.txt" || true)"
