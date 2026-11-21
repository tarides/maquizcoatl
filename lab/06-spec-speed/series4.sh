#!/bin/bash
# Experiment #6: rerun of Isabelle's value [code] with REPS_VALUE_L passes
# (the 8,000 of series2.sh folded in about 2 s, under the 10 s floor);
# labels isabelle-Q0L/QVL.  Same lock, pinning and CPU check.
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
L=$(cd "$(dirname "$0")" && pwd)
RID=$1
. "$L/reps.env"
export TCPUS=28-31,60-63
LOG=$EXP/out/$RID/series4.log
exec 9> "$EXP/timed.lock"; flock 9
for r in 1 2 3; do
  { date -u +%FT%TZ; echo "series: isabelle value run $r"; cut -d' ' -f1-3 /proc/loadavg
    echo "busy timing CPUs: $(ps -eLo user,psr,pcpu,comm --no-headers |
      awk '$2 ~ /^(28|29|30|31|60|61|62|63)$/ && $3 > 5 && $4 != "ps" {print $2, $3, $4}' | tr '\n' ';')"; } >> "$LOG"
  RUN=$r QSFX=L REPS_VALUE=$REPS_VALUE_L "$L/isabelle/isabelle.sh" inp "$RID"
done
echo "done $(date -u +%FT%TZ)" >> "$LOG"
