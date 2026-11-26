#!/bin/bash
# Run 3 (issue #34): one interactive Verus check of the crate, logged.
#   BENCH_WORKDIR=<bench-workdir> vchk.sh <target-module|all> [verus args...]
# Untimed: nice -n 10, taskset -c 8-11, --num-threads 4.
set -uo pipefail
: "${BENCH_WORKDIR:?}"
EXP=$BENCH_WORKDIR/exp/08-discriminating-lemmas
B=$EXP/build/verus/r3-dev; OUT=$EXP/out/r3; mkdir -p "$OUT"
T=${1:?target}; shift
. "$BENCH_WORKDIR/cache/verus-env.sh"
cd "$B"
LOG=$OUT/inv-$(date -u +%H%M%S).log
args=()
[ "$T" != all ] && args=(--verify-module "$T")
start=$(date -u +%Y-%m-%dT%H:%M:%SZ)
nice -n 10 taskset -c 8-11 verus --crate-type=lib --num-threads 4 lib.rs "${args[@]}" "$@" > "$LOG" 2>&1
rc=$?
sed -i "s|$BENCH_WORKDIR|<bench-workdir>|g; s|$HOME|~|g" "$LOG"
f=$T; [ "$T" = all ] && f=lib
hf=$(sha256sum "$f.rs" | cut -d' ' -f1)
ha=$(cat $(ls *.rs | sort) | sha256sum | cut -d' ' -f1)
if [ $rc = 0 ]; then sum=$(grep -m1 'verification results' "$LOG"); else sum=$(grep -m1 -E '^error' "$LOG"); [ -z "$sum" ] && sum=$(tail -1 "$LOG"); fi
[ -f "$OUT/invocations.tsv" ] || printf 'utc\ttarget\trc\tsha256_target_file\tsha256_all_sources\tsummary\n' > "$OUT/invocations.tsv"
printf '%s\t%s\trc=%s\t%s\t%s\t%s\n' "$start" "$T${*:+ $*}" "$rc" "$hf" "$ha" "$sum" >> "$OUT/invocations.tsv"
cat "$LOG"
echo "== rc=$rc"
