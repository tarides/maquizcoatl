#!/bin/bash
# Experiment #6, Why3.  RUN=<n> why3.sh <phase> <run-id>  (see common.sh)
. "$(dirname "$0")/../common.sh"
export OUT=$EXP/out/$RID/why3; . "$L/tm.sh"
case $PHASE in
tspec)
  B=$EXP/build/why3/tspec.$RUN; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/why3/spec.mlw" .
  $X why3 --version > "$OUT/version.txt" 2>&1
  tm why3-typecheck $X why3 prove -L . --type-only spec.mlw
  tm why3-vcgen     $X why3 prove -L . spec.mlw
  tm why3-extract-ocaml $X why3 extract -D ocaml64 -L . spec.Spec -o spec.ml
  tm why3-ocamlopt  $X ocamlfind ocamlopt -package zarith -c spec.ml ;;
full)
  B=$EXP/build/why3/full; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/why3/spec.mlw" "$L/why3/main.ml" "$GEN/cases.mlw" .
  $X why3 extract -D ocaml64 -L . --recursive cases.Cases -o full.ml &&
  $X ocamlfind ocamlopt -package zarith,unix -linkpkg full.ml main.ml -o why3_e06 &&
  ./why3_e06 0 > "$OUT/verdicts.txt" ;;
thr)
  cd "$EXP/build/why3/full"; tm why3-extracted ./why3_e06 "${REPS:?}" ;;
inp)
  cd "$EXP/build/why3/full"
  q() { tm "why3-$1" $X why3 execute -L . cases.mlw --use=Cases --rac-timelimit=1150 "$2"; }
  q Q0 "0"
  q QX "passes ${REPS_EXEC:?} 0" ;;
esac
