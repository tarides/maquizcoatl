#!/bin/bash
# Experiment #6, stack G and the C oracle.  RUN=<n> g.sh <phase> <run-id>
# phases: build (C library, oracle, stack G; untimed), full (verdicts),
#         thr (timed: REPS passes of parse, search and end to end)
. "$(dirname "$0")/../common.sh"
export OUT=$EXP/out/$RID/g; . "$L/tm.sh"
case $PHASE in
build)
  cmake -S "$EXP/upstream" -B "$EXP/build/onig" -DCMAKE_BUILD_TYPE=Release > "$OUT/onig-cmake.log" 2>&1 &&
  nice -n 10 make -C "$EXP/build/onig" -j4 > "$OUT/onig-make.log" 2>&1 &&
  "$EXP/build/onig/test/test_utf8" | tail -1 > "$OUT/test_utf8.txt" &&
  mkdir -p "$EXP/build/oracle" "$EXP/build/g" &&
  gcc -O2 -I "$EXP/upstream/src" -o "$EXP/build/oracle/oracle" "$L/oracle/oracle.c" \
      -L"$EXP/build/onig" -lonig -Wl,-rpath,'$ORIGIN/../onig' &&
  cd "$EXP/build/g" && cp "$L/g/g.ml" . &&
  $X ocamlfind ocamlopt -package unix -linkpkg g.ml -o g ;;
full)
  "$EXP/build/oracle/oracle" "$EXP/in.tsv" 0 > "$OUT/oracle-verdicts.txt" 2>/dev/null
  "$EXP/build/g/g" run "$EXP/in.tsv" 0 > "$OUT/g-verdicts.txt" 2>/dev/null ;;
thr)
  tm c-oracle "$EXP/build/oracle/oracle" "$EXP/in.tsv" "${REPS_C:?}"
  tm g-ocamlopt "$EXP/build/g/g" run "$EXP/in.tsv" "${REPS:?}" ;;
esac
