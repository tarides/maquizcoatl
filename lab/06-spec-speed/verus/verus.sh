#!/bin/bash
# Experiment #6, Verus (0.2026.11.02.8bf68ee, installed by experiment #8;
# not in experiment #7).  RUN=<n> verus.sh <phase> <run-id>  (see common.sh)
# Check = verification of the exec code (safety only, no functional
# spec); there is no extraction step (the code is Rust); compile =
# `verus --no-verify --compile` with rustc -C opt-level=3.
. "$(dirname "$0")/../common.sh"
. "$BENCH_WORKDIR/cache/verus-env.sh"
export OUT=$EXP/out/$RID/verus; . "$L/tm.sh"
V="verus --num-threads 4"
case $PHASE in
tspec)
  B=$EXP/build/verus/tspec.$RUN; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/verus/spec.rs" .
  verus --version > "$OUT/version.txt" 2>&1
  tm verus-check $V --crate-type=lib spec.rs
  tm verus-rustc $V --crate-type=lib --no-verify --compile spec.rs -- -C opt-level=3 ;;
full)
  B=$EXP/build/verus/full; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/verus/spec.rs" "$L/verus/main.rs" "$GEN/cases.rs" .
  $V main.rs --compile -- -C opt-level=3 -o verus_e06 > "$OUT/build-full.log" 2>&1 &&
  ./verus_e06 0 > "$OUT/verdicts.txt" ;;
thr)
  cd "$EXP/build/verus/full"; tm verus-compiled ./verus_e06 "${REPS:?}" ;;
esac
