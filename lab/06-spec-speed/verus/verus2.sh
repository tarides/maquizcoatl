#!/bin/bash
# Experiment #6 milestone 2, Verus on S2.  RUN=<n> verus2.sh <phase> <run-id>
# phases: tspec (verification, then compile, of the S2 semantics with the
#                stub table module verus/stub/tables2.rs, so that T_spec
#                is the semantics alone; timed; no extraction step)
#         full  (driver with the generated table and case modules,
#                verdicts; untimed)
#         thr   (compiled throughput; timed, REPS passes)
#         cal   (calibration of REPS; untimed)
. "$(dirname "$0")/../common.sh"
. "$BENCH_WORKDIR/cache/verus-env.sh"
M2=$EXP/m2; G=$M2/gen/p
export OUT=$M2/out/$RID/verus; . "$L/tm.sh"
V="verus --num-threads 4"
case $PHASE in
tspec)
  B=$M2/build/verus/tspec.$RUN; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/verus/spec2.rs" "$L/verus/lib2.rs" "$L/verus/stub/tables2.rs" .
  verus --version > "$OUT/version.txt" 2>&1
  tm verus-check $V --crate-type=lib lib2.rs
  tm verus-rustc $V --crate-type=lib --no-verify --compile lib2.rs -- -C opt-level=3 ;;
full)
  B=$M2/build/verus/full; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/verus/spec2.rs" "$L/verus/main2.rs" "$G/cases2.rs" "$G/restricted/tables2.rs" .
  $V main2.rs --compile -- -C opt-level=3 -o verus_e06m2 > "$OUT/build-full.log" 2>&1 &&
  ./verus_e06m2 0 > "$OUT/verdicts.txt" ;;
thr)
  cd "$M2/build/verus/full"; tm verus-compiled ./verus_e06m2 "${REPS:?}" ;;
cal)
  cd "$M2/build/verus/full"; TCPUS=${TCPUS:-0-3} tm verus-cal ./verus_e06m2 "${REPS:-100}" ;;
esac
