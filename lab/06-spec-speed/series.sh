#!/bin/bash
# Experiment #6: the timed series of milestone 1, one run at a time under
# a lock, pinned to the timing complex (CPUs 28-31,60-63, L3 complex 7).
# Before each series the timing CPUs are checked for other processes and
# the check is logged; tm.sh records the load average before every run.
#   series.sh <run-id> [e07]      (e07: also experiment #7's idle rerun)
# Reps per mode come from reps.env.
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
L=$(cd "$(dirname "$0")" && pwd)
RID=$1
. "$L/reps.env"
export TCPUS=28-31,60-63
LOG=$EXP/out/$RID/series.log
mkdir -p "$EXP/out/$RID"
exec 9> "$EXP/timed.lock"; flock 9
check() {
  # threads of other processes on the timing CPUs using > 5% CPU
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
  RUN=$r REPS=$REPS_G REPS_C=$REPS_C "$L/g/g.sh" thr "$RID"
  RUN=$r REPS=$REPS_ROCQ "$L/rocq/rocq.sh" thr "$RID"
  RUN=$r REPS=$REPS_LEAN "$L/lean/lean.sh" thr "$RID"
  RUN=$r REPS=$REPS_WHY3 "$L/why3/why3.sh" thr "$RID"
  RUN=$r REPS=$REPS_FSTAR "$L/fstar/fstar.sh" thr "$RID"
done
for r in 1 2 3; do
  check "inp run $r"
  RUN=$r REPS_VM=$REPS_VM REPS_NATIVE=$REPS_NATIVE "$L/rocq/rocq.sh" inp "$RID"
  RUN=$r REPS_EVAL=$REPS_EVAL "$L/lean/lean.sh" inp "$RID"
  RUN=$r REPS_EXEC=$REPS_EXEC "$L/why3/why3.sh" inp "$RID"
  RUN=$r REPS_NORM=$REPS_NORM "$L/fstar/fstar.sh" inp "$RID"
done
for r in 1 2 3; do
  check "tspec run $r"
  for t in rocq lean why3 fstar; do RUN=$r "$L/$t/$t.sh" tspec "$RID"; done
done
if [ "${2:-}" = e07 ]; then
  # experiment #7's T_table targets, rerun at idle with its own scripts
  # (copied from main to $EXP/e07src); RUN 11-13 skip its query and
  # sanity-lemma parts, which only run for RUN=1
  E7=$EXP/e07; mkdir -p "$E7"
  for d in emit emit-pulse sample; do
    [ -e "$E7/$d" ] || ln -s "$BENCH_WORKDIR/exp/07-large-tables/$d" "$E7/$d"
  done
  for r in 11 12 13; do
    check "e07 run $r"
    for t in lean rocq why3 fstar; do
      EXP=$E7 RUN=$r "$EXP/e07src/$t/$t.sh" "$RID"
    done
    EXP=$E7 RUN=$r "$EXP/e07src/fstar/pulse.sh" "$RID"
  done
fi
echo "done $(date -u +%FT%TZ)" >> "$LOG"
