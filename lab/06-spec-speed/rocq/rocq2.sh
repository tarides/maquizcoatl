#!/bin/bash
# Experiment #6 milestone 2, Rocq on S2.  RUN=<n> rocq2.sh <phase> <run-id>
# phases: tspec (clean check, extraction and compile of Spec2.v; timed;
#                the table module is checked, extracted and compiled
#                first, untimed, and kept)
#         full  (extracted OCaml driver, verdicts; untimed)
#         thr   (extracted throughput; timed, REPS passes)
#         cal   (vm_compute / native_compute on one pass; untimed)
#         inp   (Q0, then vm_compute and native_compute; timed)
. "$(dirname "$0")/../common.sh"
M2=$EXP/m2; G=$M2/gen/p
export OUT=$M2/out/$RID/rocq; . "$L/tm.sh"
RC="$X rocq compile -R . S"
case $PHASE in
tspec)
  B=$M2/build/rocq/tspec.$RUN; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/rocq/Spec2.v" "$L/rocq/ExtractSpec2.v" "$L/rocq/ExtractTables.v" "$G/restricted/Tables.v" .
  $X rocq --version > "$OUT/version.txt" 2>&1
  $RC Tables.v && $RC ExtractTables.v && $X ocamlfind ocamlopt -c tables.mli tables.ml
  tm rocq-check $RC Spec2.v
  tm rocq-extract $RC ExtractSpec2.v
  tm rocq-ocamlopt $X ocamlfind ocamlopt -c spec2.mli spec2.ml ;;
full)
  B=$M2/build/rocq/full; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/rocq/Spec2.v" "$L/rocq/ExtractFull2.v" "$L/rocq/main2.ml" "$G/Cases.v" "$G/restricted/Tables.v" .
  { $RC -native-compiler yes Tables.v && $RC -native-compiler yes Spec2.v &&
    $RC -native-compiler yes Cases.v && $RC ExtractFull2.v &&
    $X ocamlfind ocamlopt -O3 -package unix -linkpkg full2.mli full2.ml main2.ml -o rocq_e06m2 ||
    $X ocamlfind ocamlopt -package unix -linkpkg full2.mli full2.ml main2.ml -o rocq_e06m2; } > "$OUT/build.log" 2>&1 &&
  ./rocq_e06m2 0 > "$OUT/verdicts.txt" ;;
thr)
  cd "$M2/build/rocq/full"; tm rocq-extracted ./rocq_e06m2 "${REPS:?}" ;;
cal)
  cd "$M2/build/rocq/full"
  q() { printf 'From Stdlib Require Import List NArith.\nFrom S Require Import Tables Spec2 Cases.\n%s\n' "$2" > "$1.v"; TCPUS=${TCPUS:-0-3} tm "rocq-$1" $RC "$1.v"; }
  q CQ0 ''
  q CV1 "Eval vm_compute in passes 1 cases 0."
  q CN1 "Eval native_compute in passes 1 cases 0." ;;
inp)
  cd "$M2/build/rocq/full"
  q() { printf 'From Stdlib Require Import List NArith.\nFrom S Require Import Tables Spec2 Cases.\n%s\n' "$2" > "$1.v"; tm "rocq-$1" $RC "$1.v"; }
  q Q0 ''
  q QV "Eval vm_compute in passes ${REPS_VM:?} cases 0."
  q QN "Eval native_compute in passes ${REPS_NATIVE:?} cases 0." ;;
esac
