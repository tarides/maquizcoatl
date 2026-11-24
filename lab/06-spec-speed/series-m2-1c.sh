#!/bin/bash
# Experiment #6 milestone 2, run 1: rerun of Why3's T_spec series (three
# clean runs), after the compile step of series-m2-1b.sh failed (the
# extracted spec2.ml needs `-open Tables`; fixed in why3_2.sh).  Same
# lock, pinning and CPU check.  Labels as in series-m2-1b.sh, RUN 4-6.
#   series-m2-1c.sh <run-id>
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
L=$(cd "$(dirname "$0")" && pwd)
RID=$1
export TCPUS=28-31,60-63
LOG=$EXP/m2/out/$RID/series-m2-1c.log
exec 9> "$EXP/timed.lock"; flock 9
for r in 4 5 6; do
  { date -u +%FT%TZ; echo "series: why3 tspec run $r"; cut -d' ' -f1-3 /proc/loadavg
    echo "busy timing CPUs: $(ps -eLo user,psr,pcpu,comm --no-headers |
      awk '$2 ~ /^(28|29|30|31|60|61|62|63)$/ && $3 > 5 && $4 != "ps" {print $2, $3, $4}' | tr '\n' ';')"; } >> "$LOG"
  RUN=$r "$L/why3/why3_2.sh" tspec "$RID"
done
echo "done $(date -u +%FT%TZ)" >> "$LOG"
