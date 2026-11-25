#!/bin/bash
# Experiment #6 milestone 2, run 3 (work package G): timed runs of the
# Verus and Isabelle/HOL rows on the S2 cases, one at a time under
# milestone 1's lock, pinned to the timing complex (CPUs 28-31,60-63, L3
# complex 7); CPU check and load average logged before each series.
# Order: compiled throughput of Verus and Isabelle export_code (3 runs);
# Isabelle value [code] (Q0 then one fold, 3 runs, 20-minute cap each, a
# run that times out is not repeated); T_spec of Verus and Isabelle (3
# clean runs each).
#   series-m2-3a.sh <run-id>
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
L=$(cd "$(dirname "$0")" && pwd)
RID=$1
. "$L/reps-m2.env"
export TCPUS=28-31,60-63
LOG=$EXP/m2/out/$RID/series-m2-3a.log
mkdir -p "$EXP/m2/out/$RID"
exec 9> "$EXP/timed.lock"; flock 9
check() {
  { date -u +%FT%TZ; echo "series: $1"; cut -d' ' -f1-3 /proc/loadavg
    echo "busy timing CPUs: $(ps -eLo user,psr,pcpu,comm --no-headers |
      awk '$2 ~ /^(28|29|30|31|60|61|62|63)$/ && $3 > 5 && $4 != "ps" {print $2, $3, $4}' | tr '\n' ';')"; } >> "$LOG"
}
timedout() { awk -F'\t' -v l="$1" '$1 == l && $3 == 124' "$EXP/m2/out/$RID/$2/times.tsv" 2>/dev/null | grep -q .; }
for r in 1 2 3; do
  check "compiled thr run $r"
  RUN=$r REPS=$REPS_VERUS_M2 "$L/verus/verus2.sh" thr "$RID"
  RUN=$r REPS=$REPS_ISA_M2 "$L/isabelle/isabelle2.sh" thr "$RID"
done
for r in 1 2 3; do
  check "in-prover run $r"
  timedout isabelle-QV isabelle || RUN=$r REPS_VALUE=$REPS_VALUE_M2 "$L/isabelle/isabelle2.sh" inp "$RID"
done
for r in 1 2 3; do
  check "tspec run $r"
  RUN=$r "$L/verus/verus2.sh" tspec "$RID"
  RUN=$r "$L/isabelle/isabelle2.sh" tspec "$RID"
done
echo "done $(date -u +%FT%TZ)" >> "$LOG"
