#!/bin/bash
# Experiment #6, Isabelle/HOL (Isabelle2026, not in experiment #7).
# RUN=<n> isabelle.sh <phase> <run-id>  (see common.sh)
# Sessions are built with `isabelle build -c` (clean) so each timed run
# rebuilds its session; the HOL heap of the release is the parent.
. "$(dirname "$0")/../common.sh"
export OUT=$EXP/out/$RID/isabelle; . "$L/tm.sh"
I=$BENCH_WORKDIR/cache/isabelle/bin/isabelle
roots() {
  mkdir -p base spec specx full q0 qv x
  cat > ROOT <<R
session E06Base in "base" = HOL +
  sessions "HOL-Library"
  theories Base
session E06Spec in "spec" = HOL +
  sessions "HOL-Library"
  theories Spec
session E06SpecX in "specx" = E06Spec +
  theories SpecX
session E06 in "full" = HOL +
  sessions "HOL-Library"
  theories Spec Cases
session E06X in "x" = E06 +
  theories X
session E06Q0 in "q0" = E06 +
  theories Q0
session E06QV in "qv" = E06 +
  theories QV
R
  cp "$L/isabelle/Spec.thy" spec/; cp "$L/isabelle/Spec.thy" full/
  printf 'theory Base imports Main "HOL-Library.Code_Target_Numeral" begin\nend\n' > base/Base.thy
  printf 'theory SpecX imports E06Spec.Spec begin\nexport_code run_case passes fuel0 integer_of_nat nat_of_integer in OCaml module_name Spec file_prefix spec\nend\n' > specx/SpecX.thy
  printf 'theory X imports E06.Cases begin\nexport_code cases run_case passes fuel0 integer_of_nat nat_of_integer in OCaml module_name Full file_prefix full\nend\n' > x/X.thy
  printf 'theory Q0 imports E06.Cases begin\nend\n' > q0/Q0.thy
  printf 'theory QV imports E06.Cases begin\nvalue [code] "passes %s cases 0"\nend\n' "${REPS_VALUE:-1}" > qv/QV.thy
}
case $PHASE in
tspec)
  B=$EXP/build/isabelle/tspec.$RUN; rm -rf "$B"; mkdir -p "$B"; cd "$B"; roots
  $I version > "$OUT/version.txt" 2>&1
  # baseline: the same session with Spec's imports only (JVM, build
  # manager, HOL heap, HOL-Library theories): Spec's own check time is
  # isabelle-check minus isabelle-check-base
  tm isabelle-check-base $I build -c -d . E06Base
  tm isabelle-check $I build -c -d . E06Spec
  tm isabelle-export-code $I build -c -d . E06SpecX
  $I export -d . -O xo -x "*:code/**" E06SpecX > /dev/null && cp xo/E06SpecX.SpecX/code/spec.ocaml spec.ml
  tm isabelle-ocamlopt $X ocamlfind ocamlopt -package zarith -c spec.ml ;;
full)
  B=$EXP/build/isabelle/full; rm -rf "$B"; mkdir -p "$B"; cd "$B"; roots
  cp "$GEN/Cases.thy" full/; cp "$L/isabelle/main.ml" .
  $I build -c -d . E06X > "$OUT/build-full.log" 2>&1 &&
  $I export -d . -O xo -x "*:code/**" E06X > /dev/null && cp xo/E06X.X/code/full.ocaml full.ml &&
  $X ocamlfind ocamlopt -package zarith,unix -linkpkg full.ml main.ml -o isabelle_e06 &&
  ./isabelle_e06 0 > "$OUT/verdicts.txt" ;;
thr)
  cd "$EXP/build/isabelle/full"; tm isabelle-export-code-exe ./isabelle_e06 "${REPS:?}" ;;
inp)
  cd "$EXP/build/isabelle/full"; roots
  # QSFX distinguishes reruns with another REPS_VALUE (labels Q0L/QVL)
  tm "isabelle-Q0${QSFX:-}" $I build -c -d . E06Q0
  tm "isabelle-QV${QSFX:-}" $I build -c -d . E06QV
  $I build_log -T E06QV.QV E06QV 2>/dev/null | grep -A1 '^"' > "$OUT/qv${QSFX:-}.$RUN.txt" ;;
esac
