#!/bin/bash
# Experiment #7, Lean 4.  Usage: lean.sh <run-id>  (RUN=1..3 for timed runs)
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/07-large-tables}
L=$(cd "$(dirname "$0")/.." && pwd)
. "$BENCH_WORKDIR/cache/env.sh"; . "$L/queries.env"
export OUT=$EXP/out/$1/lean; . "$L/tm.sh"
B=$EXP/build/lean/$1.$RUN; rm -rf "$B"; mkdir -p "$B"; cd "$B"
cp "${EMIT:-$EXP/emit}/lean/Table.lean" "$L"/lean/Mem.lean "$L"/lean/Main.lean .
export LEAN_PATH=$B
echo leanprover/lean4:v4.36.0 > lean-toolchain
lean --version > "$OUT/version.txt"
tm lean-check  lean -R . Table.lean -o Table.olean -i Table.ilean
tm lean-emit-c lean -R . Table.lean -o Table.olean -c Table.c
tm lean-cc     leanc -c -O3 -DNDEBUG Table.c -o Table.o
[ "${ONLY_TABLE:-}" ] && exit 0
lean -R . Mem.lean -o Mem.olean -c Mem.c && leanc -c -O3 Mem.c -o Mem.o
lean -R . Main.lean -o Main.olean -c Main.c && leanc -c -O3 Main.c -o Main.o
tm lean-link   leanc -o e07 Main.o Mem.o Table.o
ls -l Table.lean Table.olean Table.c Table.o e07 | awk '{print $5"\t"$9}' > "$OUT/sizes.$RUN.tsv"
S=$EXP/sample
tm lean-sample ./e07 "$S/queries.txt" "$S/names.txt" answers.txt
python3 -I "$L/sample.py" compare "$S/oracle.txt" answers.txt > "$OUT/sample.$RUN.txt" 2>&1
[ "$RUN" = 1 ] || exit 0
# criterion 3: per-query files, baseline Q0 is the import alone
q() { printf 'import Mem\n%s\n' "$2" > "$1.lean"; tm "lean-$1" lean -R . "$1.lean"; }
q Q0 ''
q Q1 "#eval ctypeMem $LU 0x41"
q Q2 "#eval ctypeMem $LU 0xE9"
q Q3 "#eval ctypeMem $GB 0x323AF"
q Q4 "#eval ctypeMem $GB 0x323B0"
TMO=300 q R1 "#reduce ctypeMem $LU 0x41"
# criterion 4: sanity lemma by computation, 30-minute cap each
TMO=1800 q S0 "#eval tableOk"
TMO=1800 q S1 "theorem table_ok : tableOk = true := by decide"
TMO=1800 q S2 "theorem table_ok : tableOk = true := by native_decide"
TMO=300 q R2 "set_option maxRecDepth 100000 in
#reduce ctypeMem $LU 0x41"
TMO=1800 q S3 "set_option maxRecDepth 100000 in
theorem table_ok : tableOk = true := by decide"
TMO=1800 q S4 "theorem table_ok : tableOk = true := by decide +kernel"
TMO=1800 q S5 "theorem table_ok : tableOkL = true := by decide +kernel"
