# Experiment #6: common settings, sourced by the per-tool scripts.
# Needs BENCH_WORKDIR (<bench-workdir>); EXP defaults to
# $BENCH_WORKDIR/exp/06-spec-speed.  Usage of a tool script:
#   RUN=<n> <tool>.sh <phase> <run-id>
# phases: tspec (clean spec build: check, extract, compile; timed)
#         full  (spec + cases, extracted driver, verdicts; untimed)
#         thr   (extracted/compiled throughput; timed, REPS passes)
#         inp   (in-prover throughput; timed, baseline Q0 then the modes)
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
L=$(cd "$(dirname "$0")/.." && pwd)
. "$BENCH_WORKDIR/cache/env.sh"
PHASE=$1; RID=$2
X="opam exec --switch=provers --"
GEN=$EXP/gen
