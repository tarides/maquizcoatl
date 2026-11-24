#!/bin/bash
# Experiment #6 milestone 2, run 1, work package D: milestone 1's
# Isabelle value [code] and Lean lake driver rerun on milestone 1's
# cases and semantics with more passes, so that each fold lasts at least
# 10 s (milestone 1: 6.9 s and 8.4 s).  One untimed calibration run
# (RUN=cal, on CPUs 0-3, outside the timing complex), then three pinned
# runs.  Labels isabelle-Q0L2/QVL2 and lean-lake-exe (run ids m2-*).
# Uses milestone 1's build tree in $EXP/build (built by series.sh and
# series2.sh); outputs go to $EXP/out/<run-id>.
#   series-m2-1d.sh <run-id>
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
L=$(cd "$(dirname "$0")" && pwd)
RID=$1
REPS_VALUE_L2=${REPS_VALUE_L2:-200000}
REPS_LEAN_L=${REPS_LEAN_L:-75000}
LOG=$EXP/out/$RID/series-m2-1d.log
mkdir -p "$EXP/out/$RID"
exec 9> "$EXP/timed.lock"; flock 9
check() {
  { date -u +%FT%TZ; echo "series: $1"; cut -d' ' -f1-3 /proc/loadavg
    echo "busy timing CPUs: $(ps -eLo user,psr,pcpu,comm --no-headers |
      awk '$2 ~ /^(28|29|30|31|60|61|62|63)$/ && $3 > 5 && $4 != "ps" {print $2, $3, $4}' | tr '\n' ';')"; } >> "$LOG"
}
check "calibration (untimed, CPUs 0-3)"
TCPUS=0-3 RUN=cal REPS=$REPS_LEAN_L "$L/lean/lean.sh" thr "$RID"
TCPUS=0-3 RUN=cal QSFX=L2 REPS_VALUE=$REPS_VALUE_L2 "$L/isabelle/isabelle.sh" inp "$RID"
export TCPUS=28-31,60-63
for r in 1 2 3; do
  check "lean lake run $r"
  RUN=$r REPS=$REPS_LEAN_L "$L/lean/lean.sh" thr "$RID"
  check "isabelle value run $r"
  RUN=$r QSFX=L2 REPS_VALUE=$REPS_VALUE_L2 "$L/isabelle/isabelle.sh" inp "$RID"
done
echo "done $(date -u +%FT%TZ)" >> "$LOG"
