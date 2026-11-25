#!/bin/bash
# Experiment #6 milestone 2, run 1, work package A: timed throughput of
# the C oracle and stack G on the S2 cases (parse, search, end to end),
# three runs, one at a time under milestone 1's lock, pinned to the
# timing complex (CPUs 28-31,60-63, L3 complex 7).  The CPU check and
# load average are logged before each run.
#   series-m2-1a.sh <run-id>
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
L=$(cd "$(dirname "$0")" && pwd)
RID=$1
. "$L/reps-m2.env"
export TCPUS=28-31,60-63
LOG=$EXP/m2/out/$RID/series-m2-1a.log
mkdir -p "$EXP/m2/out/$RID"
exec 9> "$EXP/timed.lock"; flock 9
check() {
  { date -u +%FT%TZ; echo "series: $1"; cut -d' ' -f1-3 /proc/loadavg
    echo "busy timing CPUs: $(ps -eLo user,psr,pcpu,comm --no-headers |
      awk '$2 ~ /^(28|29|30|31|60|61|62|63)$/ && $3 > 5 && $4 != "ps" {print $2, $3, $4}' | tr '\n' ';')"; } >> "$LOG"
}
for r in 1 2 3; do
  check "C and stack G thr run $r"
  RUN=$r REPS=$REPS_G_M2 REPS_C=$REPS_C_M2 "$L/g/g2.sh" thr "$RID"
done
echo "done $(date -u +%FT%TZ)" >> "$LOG"
