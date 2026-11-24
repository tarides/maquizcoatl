#!/bin/bash
# Experiment #6 milestone 2, Why3 on S2.  RUN=<n> why3_2.sh <phase> <run-id>
# phases: tables (build the restricted and full table modules; untimed)
#         tspec  (clean build of spec2.mlw alone; timed; the table module
#                 is type-checked first, untimed, and kept)
#         full   (extracted OCaml driver, verdicts; untimed)
#         thr    (extracted throughput; timed, REPS passes)
#         cal    (why3 execute on a prefix of PREFIX cases; untimed)
#         inp    (why3 execute: Q0 then QX with REPS_EXEC passes; timed)
#         spot   (full-table spot check on the heavy cases: Q0F, QXF; timed)
. "$(dirname "$0")/../common.sh"
M2=$EXP/m2; G=$M2/gen/p
export OUT=$M2/out/$RID/why3; . "$L/tm.sh"
case $PHASE in
tspec)
  B=$M2/build/why3/tspec.$RUN; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/why3/spec2.mlw" . ; cp "$G/restricted/tables.mlw" .
  $X why3 --version > "$OUT/version.txt" 2>&1
  $X why3 prove -L . --type-only tables.mlw > /dev/null 2>&1
  tm why3-typecheck-tables $X why3 prove -L . --type-only tables.mlw
  tm why3-typecheck $X why3 prove -L . --type-only spec2.mlw
  tm why3-vcgen     $X why3 prove -L . spec2.mlw
  $X why3 extract -D ocaml64 -L . tables.Tables -o tables.ml
  $X ocamlfind ocamlopt -package zarith -c tables.ml
  tm why3-extract-ocaml $X why3 extract -D ocaml64 -L . spec2.Spec2 -o spec2.ml
  tm why3-ocamlopt  $X ocamlfind ocamlopt -package zarith -c spec2.ml ;;
full)
  B=$M2/build/why3/full; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/why3/spec2.mlw" "$L/why3/main2.ml" "$G/cases.mlw" "$G/restricted/tables.mlw" .
  $X why3 extract -D ocaml64 -L . --recursive cases.Cases2 -o full.ml > "$OUT/extract.log" 2>&1 &&
  $X ocamlfind ocamlopt -O3 -package zarith,unix -linkpkg full.ml main2.ml -o why3_e06 >> "$OUT/extract.log" 2>&1 ||
  $X ocamlfind ocamlopt -package zarith,unix -linkpkg full.ml main2.ml -o why3_e06 >> "$OUT/extract.log" 2>&1
  ./why3_e06 0 > "$OUT/verdicts.txt" ;;
thr)
  cd "$M2/build/why3/full"; tm why3-extracted ./why3_e06 "${REPS:?}" ;;
cal)
  cd "$M2/build/why3/full"
  TCPUS=${TCPUS:-0-3} tm why3-cal-$PREFIX $X why3 execute -L . cases.mlw --use=Cases2 \
    --rac-timelimit=1150 "count_prefix 10000000 0 $PREFIX 0" ;;
inp)
  cd "$M2/build/why3/full"
  q() { tm "why3-$1" $X why3 execute -L . cases.mlw --use=Cases2 --rac-timelimit=1150 "$2"; }
  q Q0 "0"
  q QX "passes ${REPS_EXEC:?} 0" ;;
spot)
  B=$M2/build/why3/spot; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  cp "$L/why3/spec2.mlw" "$G/heavy/cases.mlw" "$G/full/tables.mlw" .
  q() { tm "why3-$1" $X why3 execute -L . cases.mlw --use=Cases2 --rac-timelimit=1150 "$2"; }
  q Q0F "0"
  q QXF "passes ${REPS_EXEC_SPOT:-1} 0" ;;
esac
