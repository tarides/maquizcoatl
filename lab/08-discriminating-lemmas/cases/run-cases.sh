#!/bin/bash
# Run absent case files on the Debug and ASan/UBSan builds and join per id.
# Adapted from experiment #8's lab/08-hard-features/cases/run-cases.sh
# (issue #34, plan plans/08-discriminating-lemmas.md): the case files are
# arguments (paths to TSV files in experiment #2's eight-column format,
# probes/README.md) instead of the five hard-coded names; the two C builds
# are arguments instead of being derived from EXP (experiment #8's
# builds are reused read-only); the harness is built under
# <exp>/build/harness; the nest-limit harness (nest.c) is not built, no
# case file here needs it.  join.py is experiment #8's, unchanged.
# Usage: run-cases.sh <out-dir> <onig-debug-build> <onig-asan-build> <cases.tsv>...
#   (EXP: <bench-workdir>/exp/08-discriminating-lemmas)
set -euo pipefail
: "${EXP:?set EXP to <bench-workdir>/exp/08-discriminating-lemmas}"
C=$(cd "$(dirname "$0")" && pwd); R=$(cd "$C/../../.." && pwd); O=$1; H=$EXP/build/harness
BD=$(cd "$2" && pwd); BA=$(cd "$3" && pwd); shift 3
mkdir -p "$O" "$H"
export ASAN_OPTIONS=detect_leaks=1:abort_on_error=0 UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=0
for v in debug asan; do
  B=$BD; [ $v = asan ] && B=$BA
  make -s -C "$R/probes" BUILD="$B" OUT="$H" harness > /dev/null
done
for f in "$@"; do
  a=$(basename "$f" .tsv)
  for v in debug asan; do "$H/harness-$v" "$f" > "$O/$a.$v.tsv" 2> "$O/$a.$v.stderr" || true; done
  python3 -I "$R/lab/08-hard-features/cases/join.py" "$O/$a.debug.tsv" "$O/$a.asan.tsv" "$O/$a.asan.stderr" > "$O/$a.joined.tsv"
done
