#!/bin/bash
# Step 5: three timed runs of every (tool, feature) check, one after another
# (never concurrently), each through check.sh (memory cap, taskset, nice).
# Usage: timed.sh <run-prefix>   -> runs <prefix>-1, -2, -3; summary in
# <exp>/out/<prefix>-<r>/summary.tsv
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
L=$(cd "$(dirname "$0")" && pwd)
for r in 1 2 3; do
  for F in Calls Absent Longest Fold; do
    for T in rocq lean fstar verus; do "$L/check.sh" "$T" "$F" "$1-$r"; done
  done
done
