#!/bin/bash
# Experiment #7, Why3.  Usage: RUN=<n> why3.sh <run-id>
set -uo pipefail
EXP=${EXP:-$HOME/maquizcoatl-work/exp/07-large-tables}
L=$(cd "$(dirname "$0")/.." && pwd)
. "$HOME/maquizcoatl-work/cache/env.sh"; . "$L/queries.env"
export OUT=$EXP/out/$1/why3; . "$L/tm.sh"
B=$EXP/build/why3/$1.$RUN; rm -rf "$B"; mkdir -p "$B"; cd "$B"
cp "${EMIT:-$EXP/emit}"/why3/table.mlw "${EMIT:-$EXP/emit}"/why3/tablec.mlw "$L"/why3/mem.mlw "$L"/why3/driver.ml "$L"/fstar/driver_c.c .
X="opam exec --switch=provers --"
$X why3 --version > "$OUT/version.txt" 2>&1
tm why3-typecheck  $X why3 prove -L . --type-only table.mlw
tm why3-vcgen      $X why3 prove -L . table.mlw
tm why3c-typecheck $X why3 prove -L . --type-only tablec.mlw
[ "${ONLY_TABLE:-}" ] && exit 0
S=$EXP/sample
# OCaml target
tm why3-extract-ocaml $X why3 extract -D ocaml64 -L . --recursive mem.Mem -o why3_mem.ml
{ cat driver.ml; sed -n '/^let () =/,$p' "$L/main_ml.ml"; } > main.ml
tm why3-ocamlopt $X ocamlfind ocamlopt -package zarith -linkpkg why3_mem.ml main.ml -o why3_e07
tm why3-sample ./why3_e07 "$S/queries.txt" "$S/names.txt" answers-ocaml.txt
head -n 85772 answers-ocaml.txt > answers-ocaml-q.txt
python3 -I "$L/sample.py" compare "$S/oracle.txt" answers-ocaml-q.txt 85772 > "$OUT/sample-ocaml.$RUN.txt" 2>&1
# C target (decision trees over uint32)
tm why3c-extract-c $X why3 extract -D c -L . --recursive tablec.TableC -o tablec.c
tm why3c-gcc gcc -O2 -I . -I "$($X why3 --print-datadir)/../../lib/why3" -o c_e07 tablec.c driver_c.c -DFN=ctype_mem
tm why3c-sample ./c_e07 "$S/queries.txt" answers-c.txt
python3 -I "$L/sample.py" compare "$S/oracle.txt" answers-c.txt 85772 > "$OUT/sample-c.$RUN.txt" 2>&1
ls -l table.mlw tablec.mlw why3_mem.ml why3_e07 tablec.c tablec.h c_e07 2>/dev/null | awk '{print $5"\t"$9}' > "$OUT/sizes.$RUN.tsv"
[ "$RUN" = 1 ] || exit 0
q() { tm "why3-$1" $X why3 execute -L . mem.mlw --use=Mem "$2"; }
q Q1 "ctype_mem $LU 65"
q Q2 "ctype_mem $LU 233"
q Q3 "ctype_mem $GB 205743"
q Q4 "ctype_mem $GB 205744"
q Q0 "0"
TMO=1800 tm why3-S1 $X why3 prove -L . -a compute_in_goal -T Sanity mem.mlw
