#!/bin/bash
# Experiment #6, Lean 4.  RUN=<n> lean.sh <phase> <run-id>  (see common.sh)
. "$(dirname "$0")/../common.sh"
export OUT=$EXP/out/$RID/lean; . "$L/tm.sh"
case $PHASE in
tspec)
  # as experiment #7: lean -c and leanc directly, not lake
  B=$EXP/build/lean/tspec.$RUN; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/lean/Spec.lean" .
  export LEAN_PATH=$B
  echo leanprover/lean4:v4.36.0 > lean-toolchain
  lean --version > "$OUT/version.txt"
  tm lean-check  lean -R . Spec.lean -o Spec.olean -i Spec.ilean
  tm lean-emit-c lean -R . Spec.lean -o Spec.olean -c Spec.c
  tm lean-cc     leanc -c -O3 -DNDEBUG Spec.c -o Spec.o ;;
full)
  B=$EXP/build/lean/full; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/lean/Spec.lean" "$L/lean/Main.lean" "$L/lean/lakefile.lean" "$GEN/Cases.lean" .
  echo leanprover/lean4:v4.36.0 > lean-toolchain
  lake build > "$OUT/lake-build.log" 2>&1 && ./.lake/build/bin/lean_e06 0 > "$OUT/verdicts.txt" ;;
thr)
  cd "$EXP/build/lean/full"; tm lean-lake-exe ./.lake/build/bin/lean_e06 "${REPS:?}" ;;
inp)
  cd "$EXP/build/lean/full"
  export LEAN_PATH=$PWD/.lake/build/lib/lean
  q() { printf 'import Cases\nopen Spec\n%s\n' "$2" > "$1.lean"; tm "lean-$1" lean "$1.lean"; }
  q Q0 ''
  q QE "#eval passes ${REPS_EVAL:?} cases 0" ;;
esac
