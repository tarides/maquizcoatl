#!/bin/bash
# Experiment #11, step 5 on the bench host: fetch #1's workloads by git
# at a recorded commit and convert them once.
# Usage: prepare_bench.sh <commit-of-exp/01-pattern-inventory>
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/env.sh"
REPO=$(cd "$HERE/../.." && pwd)
D="$BENCH/workloads"
mkdir -p "$D"
git -C "$REPO" fetch -q origin exp/01-pattern-inventory
git -C "$REPO" archive "$1" experiments/01-pattern-inventory/workloads/data | tar -x -C "$D"
echo "$1" > "$D/COMMIT"
rm -rf "$D/prepared"
python3 -I "$HERE/prep_workloads.py" "$D/experiments/01-pattern-inventory/workloads/data" "$D/prepared"
