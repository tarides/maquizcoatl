#!/bin/bash
# Experiment #6 milestone 2, stack G and the C oracle on S2.
#   RUN=<n> g2.sh <phase> <run-id>
# phases: build (tables, oracle2, g2; untimed; reuses milestone 1's C
#               library build in $EXP/build/onig read only)
#         classify (all.tsv -> in-s2.tsv, verdicts of the classifier)
#         full  (verdicts of the oracle and of stack G)
#         gen   (prover case and table modules from the oracle's verdicts)
#         thr   (timed: REPS passes of parse, search and end to end)
. "$(dirname "$0")/../common.sh"
M2=$EXP/m2
export OUT=$M2/out/$RID/g; . "$L/tm.sh"
B=$M2/build/g
case $PHASE in
build)
  mkdir -p "$B" "$M2/build/oracle" "$M2/gen" &&
  python3 -I "$L/g/tables/gen_tables.py" "$EXP/upstream" > "$M2/gen/tables.txt" 2> "$OUT/tables.log" &&
  sha256sum "$M2/gen/tables.txt" | sed 's| .*/| |' > "$OUT/tables.sha256" &&
  cp "$M2/gen/tables.txt" "$B/tables.txt" &&
  gcc -O2 -I "$EXP/upstream/src" -o "$M2/build/oracle/oracle2" "$L/oracle/oracle2.c" \
      -L"$EXP/build/onig" -lonig -Wl,-rpath,"$EXP/build/onig" &&
  cd "$B" && cp "$L/g/g2.ml" . &&
  $X ocamlfind ocamlopt -O3 -package unix -linkpkg g2.ml -o g2 2> "$OUT/ocamlopt.log" ||
  $X ocamlfind ocamlopt -package unix -linkpkg g2.ml -o g2 ;;
classify)
  "$B/g2" classify "$EXP/out/all.tsv" "$M2/gen/classify.tsv" > "$M2/gen/in-s2.tsv" 2> "$OUT/classify.log" ;;
gen)
  # prover case modules and table modules (restricted, full; heavy subset)
  python3 -I "$L/cases/gen2.py" "$M2/gen/in-s2.tsv" "$OUT/oracle-verdicts.txt" \
    "$M2/gen/tables.txt" "$M2/gen/p" heavy 2> "$OUT/gen2.log" ;;
full)
  "$M2/build/oracle/oracle2" "$M2/gen/in-s2.tsv" 0 > "$OUT/oracle-verdicts.txt" 2>/dev/null
  "$B/g2" run "$M2/gen/in-s2.tsv" 0 > "$OUT/g-verdicts.txt" 2>/dev/null ;;
thr)
  tm c-oracle "$M2/build/oracle/oracle2" "$M2/gen/in-s2.tsv" "${REPS_C:?}"
  tm g-ocamlopt "$B/g2" run "$M2/gen/in-s2.tsv" "${REPS:?}" ;;
esac
