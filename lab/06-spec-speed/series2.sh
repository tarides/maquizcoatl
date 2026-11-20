#!/bin/bash
# Experiment #6: timed series of the Verus and Isabelle/HOL rows, added
# after the four planned provers because the budget left room.  Same
# lock, pinning and CPU check as series.sh (it waits for series.sh).
#   series2.sh <run-id>
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
L=$(cd "$(dirname "$0")" && pwd)
RID=$1
. "$L/reps.env"
export TCPUS=28-31,60-63
LOG=$EXP/out/$RID/series2.log
mkdir -p "$EXP/out/$RID"
exec 9> "$EXP/timed.lock"; flock 9
check() {
  local busy
  for i in $(seq 1 30); do
    busy=$(ps -eLo user,psr,pcpu,comm --no-headers |
           awk '$2 ~ /^(28|29|30|31|60|61|62|63)$/ && $3 > 5 {print $1, $2, $3, $4}' | sed 's/^[^ ]* /<user> /')
    { date -u +%FT%TZ; echo "series: $1"; cut -d' ' -f1-3 /proc/loadavg;
      echo "busy timing CPUs: ${busy:-none}"; } >> "$LOG"
    [ -z "$busy" ] && return 0
    sleep 60
  done
  echo "timing CPUs still busy, continuing (recorded)" >> "$LOG"
}
for r in 1 2 3; do
  check "thr run $r"
  RUN=$r REPS=$REPS_VERUS "$L/verus/verus.sh" thr "$RID"
  RUN=$r REPS=$REPS_ISA "$L/isabelle/isabelle.sh" thr "$RID"
done
for r in 1 2 3; do
  check "inp run $r"
  RUN=$r REPS_VALUE=$REPS_VALUE "$L/isabelle/isabelle.sh" inp "$RID"
done
for r in 1 2 3; do
  check "tspec run $r"
  RUN=$r "$L/verus/verus.sh" tspec "$RID"
  RUN=$r "$L/isabelle/isabelle.sh" tspec "$RID"
done
echo "done $(date -u +%FT%TZ)" >> "$LOG"
