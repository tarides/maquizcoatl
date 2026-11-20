#!/bin/bash
# Experiment #6: rerun of F*'s normaliser mode with its checked-file
# cache cleared (labels fstar-Q0c/QNc); same lock, pinning and CPU check.
#   series3.sh <run-id>
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
L=$(cd "$(dirname "$0")" && pwd)
RID=$1
. "$L/reps.env"
export TCPUS=28-31,60-63
LOG=$EXP/out/$RID/series3.log
exec 9> "$EXP/timed.lock"; flock 9
for r in 1 2 3; do
  { date -u +%FT%TZ; echo "series: fstar inp run $r"; cut -d' ' -f1-3 /proc/loadavg
    echo "busy timing CPUs: $(ps -eLo user,psr,pcpu,comm --no-headers |
      awk '$2 ~ /^(28|29|30|31|60|61|62|63)$/ && $3 > 5 {print $2, $3, $4}' | tr '\n' ';')"; } >> "$LOG"
  RUN=$r REPS_NORM=$REPS_NORM "$L/fstar/fstar.sh" inp "$RID"
done
echo "done $(date -u +%FT%TZ)" >> "$LOG"
