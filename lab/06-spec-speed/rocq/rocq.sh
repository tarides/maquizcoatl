#!/bin/bash
# Experiment #6, Rocq.  RUN=<n> rocq.sh <phase> <run-id>  (see common.sh)
. "$(dirname "$0")/../common.sh"
export OUT=$EXP/out/$RID/rocq; . "$L/tm.sh"
RC="$X rocq compile -R . S"
case $PHASE in
tspec)
  B=$EXP/build/rocq/tspec.$RUN; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/rocq/Spec.v" "$L/rocq/ExtractSpec.v" .
  $X rocq --version > "$OUT/version.txt" 2>&1
  tm rocq-check $RC Spec.v
  tm rocq-extract $RC ExtractSpec.v
  tm rocq-ocamlopt $X ocamlfind ocamlopt -c spec.mli spec.ml ;;
full)
  B=$EXP/build/rocq/full; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/rocq/Spec.v" "$L/rocq/ExtractFull.v" "$L/rocq/main.ml" "$GEN/Cases.v" .
  $RC -native-compiler yes Spec.v && $RC -native-compiler yes Cases.v && $RC ExtractFull.v &&
  $X ocamlfind ocamlopt -package unix -linkpkg full.mli full.ml main.ml -o rocq_e06 &&
  ./rocq_e06 0 > "$OUT/verdicts.txt" ;;
thr)
  cd "$EXP/build/rocq/full"; tm rocq-extracted ./rocq_e06 "${REPS:?}" ;;
inp)
  cd "$EXP/build/rocq/full"
  q() { printf 'From Stdlib Require Import List NArith.\nFrom S Require Import Spec Cases.\n%s\n' "$2" > "$1.v"; tm "rocq-$1" $RC "$1.v"; }
  q Q0 ''
  q QV "Eval vm_compute in passes ${REPS_VM:?} cases 0."
  q QN1 "Eval native_compute in passes 1 cases 0."
  q QN "Eval native_compute in passes ${REPS_NATIVE:?} cases 0." ;;
esac
