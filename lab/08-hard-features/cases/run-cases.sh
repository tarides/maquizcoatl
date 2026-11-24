#!/bin/bash
# Run the case corpus on the Debug and ASan/UBSan builds and join per id.
# Usage: run-cases.sh <out-dir>   (EXP: <bench-workdir>/exp/08-hard-features)
set -euo pipefail
: "${EXP:?set EXP to <bench-workdir>/exp/08-hard-features}"
C=$(cd "$(dirname "$0")" && pwd); R=$(cd "$C/../../.." && pwd); O=$1; H=$EXP/build/harness
mkdir -p "$O" "$H"
export ASAN_OPTIONS=detect_leaks=1:abort_on_error=0 UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=0
for v in debug asan; do
  make -s -C "$R/probes" BUILD="$EXP/build/onig-$v" OUT="$H" harness > /dev/null
  X=; [ $v = asan ] && X="-fsanitize=address,undefined -fno-omit-frame-pointer"
  cc -g -O0 -Wall $X -DBUILD_TYPE="\"$v\"" -I"$R/upstream/src" -o "$H/nest-$v" "$C/nest.c" \
     -L"$EXP/build/onig-$v" -Wl,-rpath,"$EXP/build/onig-$v" -lonig
done
for a in calls absent find-longest iso-fold nest; do
  B=harness; [ $a = nest ] && B=nest
  for v in debug asan; do "$H/$B-$v" "$C/$a.tsv" > "$O/$a.$v.tsv" 2> "$O/$a.$v.stderr" || true; done
  python3 -I "$C/join.py" "$O/$a.debug.tsv" "$O/$a.asan.tsv" "$O/$a.asan.stderr" > "$O/$a.joined.tsv"
done
