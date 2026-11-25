#!/bin/bash
# Experiment #6 milestone 2, run 2 (work packages E and F, with the
# maintainer's decisions after run 1 applied): timed runs on the updated
# S2 cases, one at a time under milestone 1's lock, pinned to the timing
# complex (CPUs 28-31,60-63, L3 complex 7); CPU check and load average
# logged before each series.  Order: C and stack G throughput (3 runs);
# extracted throughput of Why3, F*, Rocq and Lean (3 runs); Rocq
# vm_compute and native_compute, Lean #eval (Q0 then one fold, 3 runs,
# 20-minute cap each, a run that times out is not repeated); T_spec of
# Rocq, Lean, Why3 and F* (3 clean runs each, one series, so that the
# settling of experiment #7 is like for like).
#   series-m2-2a.sh <run-id>
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
L=$(cd "$(dirname "$0")" && pwd)
RID=$1
. "$L/reps-m2.env"
export TCPUS=28-31,60-63
LOG=$EXP/m2/out/$RID/series-m2-2a.log
mkdir -p "$EXP/m2/out/$RID"
exec 9> "$EXP/timed.lock"; flock 9
check() {
  { date -u +%FT%TZ; echo "series: $1"; cut -d' ' -f1-3 /proc/loadavg
    echo "busy timing CPUs: $(ps -eLo user,psr,pcpu,comm --no-headers |
      awk '$2 ~ /^(28|29|30|31|60|61|62|63)$/ && $3 > 5 && $4 != "ps" {print $2, $3, $4}' | tr '\n' ';')"; } >> "$LOG"
}
timedout() { awk -F'\t' -v l="$1" '$1 == l && $3 == 124' "$EXP/m2/out/$RID/$2/times.tsv" 2>/dev/null | grep -q .; }
for r in 1 2 3; do
  check "C and stack G thr run $r"
  RUN=$r REPS=$REPS_G_M2 REPS_C=$REPS_C_M2 "$L/g/g2.sh" thr "$RID"
done
for r in 1 2 3; do
  check "extracted thr run $r"
  RUN=$r REPS=$REPS_WHY3_M2 "$L/why3/why3_2.sh" thr "$RID"
  RUN=$r REPS=$REPS_FSTAR_M2 "$L/fstar/fstar2.sh" thr "$RID"
  RUN=$r REPS=$REPS_ROCQ_M2 "$L/rocq/rocq2.sh" thr "$RID"
  RUN=$r REPS=$REPS_LEAN_M2 "$L/lean/lean2.sh" thr "$RID"
done
for r in 1 2 3; do
  check "in-prover run $r"
  timedout rocq-QV rocq || timedout rocq-QN rocq ||
    RUN=$r REPS_VM=$REPS_VM_M2 REPS_NATIVE=$REPS_NATIVE_M2 "$L/rocq/rocq2.sh" inp "$RID"
  timedout lean-QE lean || RUN=$r REPS_EVAL=$REPS_EVAL_M2 "$L/lean/lean2.sh" inp "$RID"
done
for r in 1 2 3; do
  check "tspec run $r"
  RUN=$r "$L/rocq/rocq2.sh" tspec "$RID"
  RUN=$r "$L/lean/lean2.sh" tspec "$RID"
  RUN=$r "$L/why3/why3_2.sh" tspec "$RID"
  RUN=$r "$L/fstar/fstar2.sh" tspec "$RID"
done
echo "done $(date -u +%FT%TZ)" >> "$LOG"
