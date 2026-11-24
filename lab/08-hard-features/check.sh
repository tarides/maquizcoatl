#!/bin/bash
# Check one feature in one tool, timed, under a memory cap, with the
# assumption check of plans/08-hard-features.md step 4.
# Usage: check.sh <tool> <Feature> <run-id>
#   tool: rocq | lean | fstar | verus;  Feature: Calls | Absent | Longest | Fold
# Env: BENCH_WORKDIR (<bench-workdir>), CPUS (taskset list), MEM (cgroup cap).
# Output: <exp>/out/<run-id>/<tool>/<Feature>.{log,time,assume,load}; prints
# one summary line with no absolute paths.
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
T=$1 F=$2 RUN=$3
EXP=${EXP:-$BENCH_WORKDIR/exp/08-hard-features} CACHE=$BENCH_WORKDIR/cache
CPUS=${CPUS:-16-23,48-55} MEM=${MEM:-32G} TMO=${TMO:-1800}
L=$(cd "$(dirname "$0")" && pwd)
O=$EXP/out/$RUN/$T; B=$EXP/build/$T/$RUN; mkdir -p "$O" "$B"
. "$CACHE/env.sh"
case $T in
  rocq)  SRC=$F.v;   cp "$L/rocq/$SRC" "$B/"; CMD=(opam exec --switch=provers -- rocq compile "$SRC");;
  lean)  SRC=$F.lean; cp "$L/lean/$SRC" "$B/"; echo leanprover/lean4:v4.36.0 > "$B/lean-toolchain"; CMD=(lean "$SRC");;
  fstar) SRC=$F.fst; cp "$L/fstar/$SRC" "$B/"; CMD=(fstar.exe --cache_dir . "$SRC");;
  verus) . "$CACHE/verus-env.sh"; SRC=$(echo "$F" | tr A-Z a-z).rs; cp "$L/verus/$SRC" "$B/"; CMD=(verus "$SRC");;
  *) echo "unknown tool $T" >&2; exit 2;;
esac
cd "$B"
uptime | sed 's/.*load average/load average/' > "$O/$F.load"
S=$(date +%s.%N)
systemd-run --user --scope --quiet -p MemoryMax="$MEM" -p MemorySwapMax=0 \
  /usr/bin/time -v -o "$O/$F.time" nice -n 10 taskset -c "$CPUS" timeout "$TMO" "${CMD[@]}" > "$O/$F.log" 2>&1
RC=$?
E=$(date +%s.%N)
# assumption check: greps (comments included, so a hit is inspected by hand)
case $T in
  rocq)  P='Admitted|admit|Axiom|native_compute';;
  lean)  P='sorry|native_decide|ofReduceBool|axiom ';;
  fstar) P='assume|admit|assume_val|admit_smt_queries';;
  verus) P='assume|admit|external_body|external';;
esac
{ echo "grep -nE '$P' $SRC:"; grep -nE "$P" "$SRC" || echo "(no match)"
  case $T in
    rocq|lean) echo "kernel output (Print Assumptions / #print axioms):"
               grep -E "Closed under|depends on axioms|does not depend|Axioms:" "$O/$F.log" || echo "(none printed)";;
  esac; } > "$O/$F.assume"
RSS=$(sed -n 's/.*Maximum resident set size (kbytes): //p' "$O/$F.time")
printf '%s\t%s\t%s\trc=%s\twall=%.2fs\tmaxrss_kb=%s\n' "$RUN" "$T" "$F" "$RC" "$(echo "$E - $S" | bc)" "$RSS" | tee -a "$EXP/out/$RUN/summary.tsv"
