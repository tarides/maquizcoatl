#!/bin/bash
# Experiment #6 milestone 2, run 3: rerun of Isabelle's T_spec series
# after the fix of isabelle2.sh (stub session built with -b, untimed), as
# series-m2-3a.sh: one at a time under milestone 1's lock, pinned to CPUs
# 28-31,60-63, CPU check and load average logged.
#   series-m2-3b.sh <run-id>
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
L=$(cd "$(dirname "$0")" && pwd)
RID=$1
export TCPUS=28-31,60-63
LOG=$EXP/m2/out/$RID/series-m2-3b.log
mkdir -p "$EXP/m2/out/$RID"
exec 9> "$EXP/timed.lock"; flock 9
check() {
  { date -u +%FT%TZ; echo "series: $1"; cut -d' ' -f1-3 /proc/loadavg
    echo "busy timing CPUs: $(ps -eLo user,psr,pcpu,comm --no-headers |
      awk '$2 ~ /^(28|29|30|31|60|61|62|63)$/ && $3 > 5 && $4 != "ps" {print $2, $3, $4}' | tr '\n' ';')"; } >> "$LOG"
}
for r in 1 2 3; do
  check "isabelle tspec run $r"
  RUN=$r "$L/isabelle/isabelle2.sh" tspec "$RID"
done
echo "done $(date -u +%FT%TZ)" >> "$LOG"
