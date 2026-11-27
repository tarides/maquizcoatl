#!/bin/bash
# Run 5 (issue #34): one interactive Rocq compile of one file, logged.
#   BENCH_WORKDIR=<bench-workdir> rchk.sh <File>     (File.v in build/rocq/r5-dev)
# Untimed: nice -n 10, taskset -c 8-11.
set -uo pipefail
: "${BENCH_WORKDIR:?}"
EXP=$BENCH_WORKDIR/exp/08-discriminating-lemmas
B=$EXP/build/rocq/r5-dev; OUT=$EXP/out/r5; mkdir -p "$OUT"
F=${1:?file}
. "$BENCH_WORKDIR/cache/env.sh"
cd "$B"
LOG=$OUT/inv-$(date -u +%H%M%S).log
start=$(date -u +%Y-%m-%dT%H:%M:%SZ)
nice -n 10 taskset -c 8-11 opam exec --switch provers -- rocq compile -R . S "$F.v" > "$LOG" 2>&1
rc=$?
sed -i "s|$BENCH_WORKDIR|<bench-workdir>|g; s|$HOME|~|g" "$LOG"
hf=$(sha256sum "$F.v" | cut -d" " -f1)
ha=$(cat $(ls *.v | sort) | sha256sum | cut -d" " -f1)
if [ $rc = 0 ]; then sum=ok; else sum=$(grep -m1 -E "^Error" "$LOG"); [ -z "$sum" ] && sum=$(tail -1 "$LOG"); fi
[ -f "$OUT/invocations.tsv" ] || printf "utc\ttarget\trc\tsha256_target_file\tsha256_all_sources\tsummary\n" > "$OUT/invocations.tsv"
printf "%s\t%s\trc=%s\t%s\t%s\t%s\n" "$start" "$F" "$rc" "$hf" "$ha" "$sum" >> "$OUT/invocations.tsv"
cat "$LOG"
echo "== rc=$rc"
