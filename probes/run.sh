#!/bin/sh
# run.sh: run every probe file through the Debug harness, the ASan/UBSan
# harness and the Node.js oracle, then join the three outputs.
#
# Usage: probes/run.sh HARNESS_DIR OUT_DIR
#   HARNESS_DIR holds harness-debug and harness-asan (see probes/Makefile).
#   OUT_DIR receives <area>.debug.tsv, <area>.asan.tsv, <area>.asan.stderr,
#   <area>.js.tsv and the joined <area>.joined.tsv.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
H=$1
OUT=$2
mkdir -p "$OUT"
NODE_FLAGS="--js-regexp-modifiers --js-regexp-duplicate-named-groups"
ASAN_OPTIONS=detect_leaks=1:abort_on_error=0
UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=0
export ASAN_OPTIONS UBSAN_OPTIONS
for area in captures-in-loops backref-unset empty-iterations lookbehind case-folding; do
  f="$HERE/$area.tsv"
  "$H/harness-debug" "$f" > "$OUT/$area.debug.tsv" 2> "$OUT/$area.debug.stderr"
  "$H/harness-asan" "$f" > "$OUT/$area.asan.tsv" 2> "$OUT/$area.asan.stderr" || true
  # shellcheck disable=SC2086
  node $NODE_FLAGS "$HERE/oracle.mjs" "$f" > "$OUT/$area.js.tsv"
  node "$HERE/compare.mjs" "$OUT/$area.debug.tsv" "$OUT/$area.asan.tsv" \
       "$OUT/$area.asan.stderr" "$OUT/$area.js.tsv" > "$OUT/$area.joined.tsv"
done
