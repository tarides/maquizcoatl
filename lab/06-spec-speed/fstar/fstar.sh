#!/bin/bash
# Experiment #6, F*.  RUN=<n> fstar.sh <phase> <run-id>  (see common.sh)
. "$(dirname "$0")/../common.sh"
export OUT=$EXP/out/$RID/fstar; . "$L/tm.sh"
CACHE=$BENCH_WORKDIR/cache
F="fstar.exe --cache_checked_modules --cache_dir cache --z3version 5.3.0"
# fstar.lib in the binary release is compiled by OCaml 5.3.0; as in
# experiment #7, Prims.ml is compiled from its shipped source in the switch
PRIMS=$CACHE/fstar/lib/fstar/lib/app/Prims.ml
case $PHASE in
tspec)
  B=$EXP/build/fstar/tspec.$RUN; rm -rf "$B"; mkdir -p "$B/cache"; cd "$B"
  cp "$L/fstar/Spec.fst" .
  fstar.exe --version > "$OUT/version.txt"
  tm fstar-check $F Spec.fst
  tm fstar-extract-ocaml $F --codegen OCaml --custard_entry Spec.run_case --custard_entry Spec.passes Spec.fst --odir ml
  cp "$PRIMS" ml/; cd ml
  tm fstar-ocamlopt $X ocamlfind ocamlopt -package zarith,yojson,ppx_deriving.show,ppx_deriving_yojson -c Prims.ml Custard.ml ;;
full)
  B=$EXP/build/fstar/full; rm -rf "$B"; mkdir -p "$B/cache"; cd "$B"
  cp "$L/fstar/Spec.fst" "$L/fstar/main.ml" "$GEN/Cases.fst" .
  $F Spec.fst && $F Cases.fst &&
  $F --codegen OCaml --custard_entry Spec.run_case --custard_entry Spec.passes \
     --custard_entry Spec.fuel0 --custard_entry Cases.cases Cases.fst --odir ml &&
  cp "$PRIMS" main.ml ml/ && cd ml &&
  $X ocamlfind ocamlopt -package zarith,unix,yojson,ppx_deriving.show,ppx_deriving_yojson -linkpkg Prims.ml Custard.ml main.ml -o fstar_e06 &&
  ./fstar_e06 0 > "$OUT/verdicts.txt" ;;
thr)
  cd "$EXP/build/fstar/full/ml"; tm fstar-extracted ./fstar_e06 "${REPS:?}" ;;
inp)
  # not in the plan (F*: extracted only); the normaliser is F*'s
  # in-prover evaluation, recorded as an extra mode
  cd "$EXP/build/fstar/full"
  # labels Q0c/QNc: the checked files of Q0 and QN are removed first, so
  # F* cannot reuse a cached check (labels Q0/QN of the first series
  # reused the calibration run's cache and measured nothing)
  q() { printf 'module %s\nopen Spec\nopen Cases\n%s\n' "$1" "$2" > "$1.fst"
        rm -f "cache/$1.fst.checked"; tm "fstar-${1}c" $F "$1.fst"; }
  q Q0 ''
  q QN "let _ = assert_norm (passes ${REPS_NORM:?} cases 0 = $(( REPS_NORM * ${NCASES:-149} )))" ;;
esac
