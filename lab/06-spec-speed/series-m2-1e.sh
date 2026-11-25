#!/bin/bash
# Experiment #6 milestone 2, run 1: the property-heavy cases with the
# restricted table (labels Q0R/QXR, Q0R/QNR), the baseline against which
# series-m2-1b.sh's full-table spot check (Q0F/QXF, Q0F/QNF) is read.
# One run each, same lock, pinning and CPU check.
#   series-m2-1e.sh <run-id>
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
L=$(cd "$(dirname "$0")" && pwd)
RID=$1
export TCPUS=28-31,60-63
LOG=$EXP/m2/out/$RID/series-m2-1e.log
exec 9> "$EXP/timed.lock"; flock 9
{ date -u +%FT%TZ; echo "series: heavy cases, restricted table"; cut -d' ' -f1-3 /proc/loadavg
  echo "busy timing CPUs: $(ps -eLo user,psr,pcpu,comm --no-headers |
    awk '$2 ~ /^(28|29|30|31|60|61|62|63)$/ && $3 > 5 && $4 != "ps" {print $2, $3, $4}' | tr '\n' ';')"; } >> "$LOG"
RUN=1 SPOT_TABLE=restricted "$L/why3/why3_2.sh" spot "$RID"
RUN=1 SPOT_TABLE=restricted "$L/fstar/fstar2.sh" spot "$RID"
echo "done $(date -u +%FT%TZ)" >> "$LOG"
