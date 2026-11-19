#!/bin/bash
# Experiment #7, Rocq.  Usage: RUN=<n> rocq.sh <run-id>
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/07-large-tables}
L=$(cd "$(dirname "$0")/.." && pwd)
. "$BENCH_WORKDIR/cache/env.sh"; . "$L/queries.env"
export OUT=$EXP/out/$1/rocq; . "$L/tm.sh"
B=$EXP/build/rocq/$1.$RUN; rm -rf "$B"; mkdir -p "$B"; cd "$B"
cp "${EMIT:-$EXP/emit}/rocq/Table.v" "$L"/rocq/Mem.v "$L"/rocq/Extract.v .
X="opam exec --switch=provers --"
$X rocq --version > "$OUT/version.txt" 2>&1
RC="$X rocq compile -R . T"
tm rocq-check $RC Table.v
[ "${ONLY_TABLE:-}" ] && exit 0
$RC Mem.v > "$OUT/mem.$RUN.log" 2>&1
tm rocq-extract $RC Extract.v
{ echo 'module M = Rocq_mem'; cat "$L/main_ml.ml"; } > main.ml
tm rocq-ocamlopt $X ocamlfind ocamlopt -O2 rocq_mem.mli rocq_mem.ml main.ml -o rocq_e07 2>/dev/null || \
tm rocq-ocamlopt $X ocamlfind ocamlopt rocq_mem.mli rocq_mem.ml main.ml -o rocq_e07
ls -l Table.v Table.vo rocq_mem.ml rocq_e07 | awk '{print $5"\t"$9}' > "$OUT/sizes.$RUN.tsv"
S=$EXP/sample
tm rocq-sample ./rocq_e07 "$S/queries.txt" "$S/names.txt" answers.txt
python3 -I "$L/sample.py" compare "$S/oracle.txt" answers.txt > "$OUT/sample.$RUN.txt" 2>&1
[ "$RUN" = 1 ] || exit 0
q() { printf 'From Stdlib Require Import ZArith.\nFrom T Require Import Mem.\n%s\n' "$2" > "$1.v"; tm "rocq-$1" $RC "$1.v"; }
q Q0 ''
for ev in vm_compute native_compute; do
  q "Q1_$ev" "Eval $ev in ctype_mem $LU%Z 65%Z."
  q "Q2_$ev" "Eval $ev in ctype_mem $LU%Z 233%Z."
  q "Q3_$ev" "Eval $ev in ctype_mem $GB%Z 205743%Z."
  q "Q4_$ev" "Eval $ev in ctype_mem $GB%Z 205744%Z."
done
TMO=1800 q S1 "Lemma table_ok_true : table_ok = true. Proof. vm_compute. reflexivity. Qed."
TMO=1800 q S2 "Lemma table_ok_true : table_ok = true. Proof. native_compute. reflexivity. Qed."
