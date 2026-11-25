#!/bin/bash
# Experiment #6 milestone 2, run 1, work packages B and C and the
# full-table spot check (decision 2 on issue #28): Why3 and F* on S2.
# Timed runs one at a time under milestone 1's lock, pinned to the
# timing complex (CPUs 28-31,60-63); CPU check and load average logged
# before each series.  Order: extracted throughput (3 runs), in-prover
# throughput (Q0 then one pass, 3 runs; 20-minute cap each, a run that
# times out is not repeated), T_spec (3 clean runs), then the spot check
# (one bounded run of the property-heavy cases with the full property
# table in why3 execute and the F* normaliser).
#   series-m2-1b.sh <run-id>
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
L=$(cd "$(dirname "$0")" && pwd)
RID=$1
. "$L/reps-m2.env"
export TCPUS=28-31,60-63
LOG=$EXP/m2/out/$RID/series-m2-1b.log
mkdir -p "$EXP/m2/out/$RID"
exec 9> "$EXP/timed.lock"; flock 9
check() {
  { date -u +%FT%TZ; echo "series: $1"; cut -d' ' -f1-3 /proc/loadavg
    echo "busy timing CPUs: $(ps -eLo user,psr,pcpu,comm --no-headers |
      awk '$2 ~ /^(28|29|30|31|60|61|62|63)$/ && $3 > 5 && $4 != "ps" {print $2, $3, $4}' | tr '\n' ';')"; } >> "$LOG"
}
timedout() { awk -F'\t' -v l="$1" '$1 == l && $3 == 124' "$EXP/m2/out/$RID/$2/times.tsv" 2>/dev/null | grep -q .; }
for r in 1 2 3; do
  check "extracted thr run $r"
  RUN=$r REPS=$REPS_WHY3_M2 "$L/why3/why3_2.sh" thr "$RID"
  RUN=$r REPS=$REPS_FSTAR_M2 "$L/fstar/fstar2.sh" thr "$RID"
done
for r in 1 2 3; do
  check "in-prover run $r"
  timedout why3-QX why3 || RUN=$r REPS_EXEC=$REPS_EXEC_M2 "$L/why3/why3_2.sh" inp "$RID"
  timedout fstar-QN fstar || RUN=$r REPS_NORM=$REPS_NORM_M2 NAGREE=$NAGREE_M2 "$L/fstar/fstar2.sh" inp "$RID"
done
for r in 1 2 3; do
  check "tspec run $r"
  RUN=$r "$L/why3/why3_2.sh" tspec "$RID"
  RUN=$r "$L/fstar/fstar2.sh" tspec "$RID"
done
check "full-table spot check"
RUN=1 "$L/why3/why3_2.sh" spot "$RID"
RUN=1 "$L/fstar/fstar2.sh" spot "$RID"
echo "done $(date -u +%FT%TZ)" >> "$LOG"
