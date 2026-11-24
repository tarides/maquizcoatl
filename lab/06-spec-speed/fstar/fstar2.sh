#!/bin/bash
# Experiment #6 milestone 2, F* on S2.  RUN=<n> fstar2.sh <phase> <run-id>
# phases: tspec (clean check, extraction and compile of Spec2.fst; timed;
#                the table module is checked first, untimed, and its
#                checked file kept)
#         full  (extracted OCaml driver, verdicts; untimed)
#         thr   (extracted throughput; timed, REPS passes)
#         cal   (normaliser on a prefix of PREFIX cases; untimed)
#         inp   (normaliser: Q0 then QN with REPS_NORM passes, checked
#                files of Q0/QN removed first; timed)
#         spot  (full-table spot check on the heavy cases: Q0F, QNF; timed)
# NAGREE: number of emitted cases whose verdict equals the C library's.
. "$(dirname "$0")/../common.sh"
M2=$EXP/m2; G=$M2/gen/p
export OUT=$M2/out/$RID/fstar; . "$L/tm.sh"
CACHE=$BENCH_WORKDIR/cache
F="fstar.exe --cache_checked_modules --cache_dir cache --z3version 5.3.0"
PRIMS=$CACHE/fstar/lib/fstar/lib/app/Prims.ml
OPK=zarith,yojson,ppx_deriving.show,ppx_deriving_yojson
case $PHASE in
tspec)
  B=$M2/build/fstar/tspec.$RUN; rm -rf "$B"; mkdir -p "$B/cache"; cd "$B"
  cp "$L/fstar/Spec2.fst" "$G/restricted/Tables.fst" .
  fstar.exe --version > "$OUT/version.txt"
  tm fstar-check-tables $F Tables.fst
  tm fstar-check $F Spec2.fst
  tm fstar-extract-ocaml $F --codegen OCaml --custard_entry Spec2.run_case --custard_entry Spec2.passes Spec2.fst --odir ml
  cp "$PRIMS" ml/; cd ml
  tm fstar-ocamlopt $X ocamlfind ocamlopt -package $OPK -c Prims.ml Custard.ml ;;
full)
  B=$M2/build/fstar/full; rm -rf "$B"; mkdir -p "$B/cache"; cd "$B"
  cp "$L/fstar/Spec2.fst" "$L/fstar/main2.ml" "$G/Cases.fst" "$G/restricted/Tables.fst" .
  { $F Tables.fst && $F Spec2.fst && $F Cases.fst &&
    $F --codegen OCaml --custard_entry Spec2.run_case --custard_entry Spec2.passes \
       --custard_entry Spec2.fuel0 --custard_entry Cases.cases Cases.fst --odir ml; } > "$OUT/build.log" 2>&1 &&
  cp "$PRIMS" main2.ml ml/ && cd ml &&
  $X ocamlfind ocamlopt -package $OPK,unix -linkpkg Prims.ml Custard.ml main2.ml -o fstar_e06 >> "$OUT/build.log" 2>&1 &&
  ./fstar_e06 0 > "$OUT/verdicts.txt" ;;
thr)
  cd "$M2/build/fstar/full/ml"; tm fstar-extracted ./fstar_e06 "${REPS:?}" ;;
cal)
  cd "$M2/build/fstar/full"
  printf 'module QC%s\nopen Spec2\nopen Cases\nlet _ = assert_norm (count fuel0 (take_cases %s cases) >= 0)\n' "$PREFIX" "$PREFIX" > "QC$PREFIX.fst"
  rm -f "cache/QC$PREFIX.fst.checked"
  TCPUS=${TCPUS:-0-3} tm "fstar-cal-$PREFIX" $F "QC$PREFIX.fst" ;;
inp)
  cd "$M2/build/fstar/full"
  q() { printf 'module %s\nopen Spec2\nopen Cases\n%s\n' "$1" "$2" > "$1.fst"
        rm -f "cache/$1.fst.checked"; tm "fstar-$1" $F "$1.fst"; }
  q Q0 ''
  q QN "let _ = assert_norm (passes ${REPS_NORM:?} cases 0 = $(( REPS_NORM * ${NAGREE:?} )))" ;;
spot)
  B=$M2/build/fstar/spot; rm -rf "$B"; mkdir -p "$B/cache"; cd "$B"
  cp "$L/fstar/Spec2.fst" "$G/heavy/Cases.fst" "$G/full/Tables.fst" .
  $F Tables.fst > "$OUT/spot-build.log" 2>&1 && $F Spec2.fst >> "$OUT/spot-build.log" 2>&1 &&
  $F Cases.fst >> "$OUT/spot-build.log" 2>&1
  q() { printf 'module %s\nopen Spec2\nopen Cases\n%s\n' "$1" "$2" > "$1.fst"
        rm -f "cache/$1.fst.checked"; tm "fstar-$1" $F "$1.fst"; }
  q Q0F ''
  q QNF "let _ = assert_norm (passes ${REPS_NORM_SPOT:-1} cases 0 >= 0)" ;;
esac
