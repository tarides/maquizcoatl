#!/bin/bash
# Experiment #6 milestone 2, Lean 4 on S2.  RUN=<n> lean2.sh <phase> <run-id>
# phases: tspec (lean -c and leanc on Spec2.lean, as experiment #7 and
#                milestone 1; timed; Tables.lean is checked first,
#                untimed, and its .olean kept)
#         full  (lake build of the driver, verdicts; untimed)
#         thr   (lake-built driver throughput; timed, REPS passes)
#         cal   (#eval on one pass; untimed)
#         inp   (Q0, then #eval; timed)
. "$(dirname "$0")/../common.sh"
M2=$EXP/m2; G=$M2/gen/p
export OUT=$M2/out/$RID/lean; . "$L/tm.sh"
case $PHASE in
tspec)
  B=$M2/build/lean/tspec.$RUN; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/lean/Spec2.lean" "$G/restricted/Tables.lean" .
  export LEAN_PATH=$B
  echo leanprover/lean4:v4.36.0 > lean-toolchain
  lean --version > "$OUT/version.txt"
  lean -R . Tables.lean -o Tables.olean -i Tables.ilean
  tm lean-check  lean -R . Spec2.lean -o Spec2.olean -i Spec2.ilean
  tm lean-emit-c lean -R . Spec2.lean -o Spec2.olean -c Spec2.c
  tm lean-cc     leanc -c -O3 -DNDEBUG Spec2.c -o Spec2.o ;;
full)
  B=$M2/build/lean/full; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/lean/Spec2.lean" "$L/lean/Main2.lean" "$G/Cases.lean" "$G/restricted/Tables.lean" .
  cp "$L/lean/lakefile2.lean" lakefile.lean
  echo leanprover/lean4:v4.36.0 > lean-toolchain
  lake build > "$OUT/lake-build.log" 2>&1 && ./.lake/build/bin/lean_e06m2 0 > "$OUT/verdicts.txt" ;;
thr)
  cd "$M2/build/lean/full"; tm lean-lake-exe ./.lake/build/bin/lean_e06m2 "${REPS:?}" ;;
cal)
  cd "$M2/build/lean/full"
  export LEAN_PATH=$PWD/.lake/build/lib/lean
  q() { printf 'import Cases\nopen Spec2\n%s\n' "$2" > "$1.lean"; TCPUS=${TCPUS:-0-3} tm "lean-$1" lean "$1.lean"; }
  q CQ0 ''
  q CE1 "#eval passes 1 cases 0" ;;
inp)
  cd "$M2/build/lean/full"
  export LEAN_PATH=$PWD/.lake/build/lib/lean
  q() { printf 'import Cases\nopen Spec2\n%s\n' "$2" > "$1.lean"; tm "lean-$1" lean "$1.lean"; }
  q Q0 ''
  q QE "#eval passes ${REPS_EVAL:?} cases 0" ;;
esac
