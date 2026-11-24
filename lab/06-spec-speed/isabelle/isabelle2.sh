#!/bin/bash
# Experiment #6 milestone 2, Isabelle/HOL on S2.
#   RUN=<n> isabelle2.sh <phase> <run-id>
# phases: tspec (clean check, export_code and ocamlopt of Spec2.thy;
#                timed; the parent session E06T2 holds the stub table
#                theory isabelle/stub/Tables.thy, built untimed and kept,
#                so that T_spec is the semantics alone)
#         full  (session with the generated tables and cases, export_code
#                driver, verdicts; untimed)
#         thr   (export_code throughput; timed, REPS passes)
#         cal   (value [code] on one pass; untimed)
#         inp   (Q0, then value [code]; timed)
# Sessions are built with `isabelle build -c` (clean), so each timed run
# rebuilds the selected session only; parent heaps are kept.  Check time
# is isabelle-check minus isabelle-check-base, as in milestone 1.
. "$(dirname "$0")/../common.sh"
M2=$EXP/m2; G=$M2/gen/p
export OUT=$M2/out/$RID/isabelle; . "$L/tm.sh"
I=$BENCH_WORKDIR/cache/isabelle/bin/isabelle
roots() {
  mkdir -p tables base spec specx full x q0 qv
  cat > ROOT <<R
session E06T2 in "tables" = HOL +
  sessions "HOL-Library"
  theories Tables
session E06Base2 in "base" = E06T2 +
  theories Base2
session E06Spec2 in "spec" = E06T2 +
  theories Spec2
session E06SpecX2 in "specx" = E06Spec2 +
  theories SpecX2
session E06Full2 in "full" = HOL +
  sessions "HOL-Library"
  theories Tables Spec2 Cases
session E06X2 in "x" = E06Full2 +
  theories X2
session E06Q02 in "q0" = E06Full2 +
  theories Q02
session E06QV2 in "qv" = E06Full2 +
  theories QV2
R
  cp "$L/isabelle/stub/Tables.thy" tables/
  sed 's/imports Tables/imports E06T2.Tables/' "$L/isabelle/Spec2.thy" > spec/Spec2.thy
  cp "$L/isabelle/Spec2.thy" full/
  printf 'theory Base2 imports E06T2.Tables begin\nend\n' > base/Base2.thy
  printf 'theory SpecX2 imports E06Spec2.Spec2 begin\nexport_code run_case passes fuel0 integer_of_nat nat_of_integer in OCaml module_name Spec file_prefix spec\nend\n' > specx/SpecX2.thy
  printf 'theory X2 imports E06Full2.Cases begin\nexport_code cases run_case passes fuel0 integer_of_nat nat_of_integer in OCaml module_name Full file_prefix full\nend\n' > x/X2.thy
  printf 'theory Q02 imports E06Full2.Cases begin\nend\n' > q0/Q02.thy
  printf 'theory QV2 imports E06Full2.Cases begin\nvalue [code] "passes %s cases 0"\nend\n' "${REPS_VALUE:-1}" > qv/QV2.thy
}
case $PHASE in
tspec)
  B=$M2/build/isabelle/tspec.$RUN; rm -rf "$B"; mkdir -p "$B"; cd "$B"; roots
  $I version > "$OUT/version.txt" 2>&1
  $I build -d . E06T2 > "$OUT/build-stub.$RUN.log" 2>&1
  tm isabelle-check-base $I build -c -d . E06Base2
  tm isabelle-check $I build -c -d . E06Spec2
  tm isabelle-export-code $I build -c -d . E06SpecX2
  $I export -d . -O xo -x "*:code/**" E06SpecX2 > /dev/null && cp xo/E06SpecX2.SpecX2/code/spec.ocaml spec.ml
  tm isabelle-ocamlopt $X ocamlfind ocamlopt -package zarith -c spec.ml ;;
full)
  B=$M2/build/isabelle/full; rm -rf "$B"; mkdir -p "$B"; cd "$B"; roots
  cp "$G/restricted/Tables.thy" "$G/Cases.thy" full/; cp "$L/isabelle/main2.ml" .
  $I build -d . E06X2 > "$OUT/build-full.log" 2>&1 &&
  $I export -d . -O xo -x "*:code/**" E06X2 > /dev/null && cp xo/E06X2.X2/code/full.ocaml full.ml &&
  $X ocamlfind ocamlopt -O3 -package zarith,unix -linkpkg full.ml main2.ml -o isabelle_e06m2 > "$OUT/ocamlopt-full.log" 2>&1 ||
  $X ocamlfind ocamlopt -package zarith,unix -linkpkg full.ml main2.ml -o isabelle_e06m2 >> "$OUT/ocamlopt-full.log" 2>&1
  ./isabelle_e06m2 0 > "$OUT/verdicts.txt" ;;
thr)
  cd "$M2/build/isabelle/full"; tm isabelle-export-code-exe ./isabelle_e06m2 "${REPS:?}" ;;
cal)
  cd "$M2/build/isabelle/full"; roots
  TCPUS=${TCPUS:-0-3} tm isabelle-CQ0 $I build -c -d . E06Q02
  TCPUS=${TCPUS:-0-3} tm isabelle-CQV $I build -c -d . E06QV2
  $I build_log -T E06QV2.QV2 E06QV2 2>/dev/null | grep -A1 '^"' > "$OUT/cqv.txt" ;;
inp)
  cd "$M2/build/isabelle/full"; roots
  tm isabelle-Q0 $I build -c -d . E06Q02
  tm isabelle-QV $I build -c -d . E06QV2
  $I build_log -T E06QV2.QV2 E06QV2 2>/dev/null | grep -A1 '^"' > "$OUT/qv.$RUN.txt" ;;
esac
