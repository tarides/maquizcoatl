#!/bin/bash
# Experiment #7, F*/Pulse static-array representation, KaRaMeL and direct C
# targets.  Usage: RUN=<n> pulse.sh <run-id>
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/07-large-tables}
L=$(cd "$(dirname "$0")/.." && pwd)
CACHE=$BENCH_WORKDIR/cache
. "$CACHE/env.sh"; . "$L/queries.env"
export OUT=$EXP/out/$1/pulse; . "$L/tm.sh"
B=$EXP/build/pulse/$1.$RUN; rm -rf "$B"; mkdir -p "$B/cache"; cd "$B"
cp "${EMIT:-$EXP/emit}"/fstar/PulseTable.fst "$L"/fstar/driver_c.c .
F="fstar.exe --cache_checked_modules --cache_dir cache --z3version 5.3.0"
S=$EXP/sample
tm pulse-check $F PulseTable.fst
tm pulse-extract-krml $F --codegen KrmlC --custard_entry PulseTable.ctype_mem PulseTable.fst --odir krml
tm pulse-krml krml -skip-compilation -tmpdir kc krml/Custard.krml
tm pulse-gcc-krml gcc -O2 -I kc -I "$CACHE/fstar/include/krml" -I "$CACHE/fstar/lib/krml/dist/minimal" -DFN=PulseTable_ctype_mem -o krml_e07 kc/Custard.c driver_c.c
tm pulse-sample-krml ./krml_e07 "$S/queries.txt" answers-krml.txt
python3 -I "$L/sample.py" compare "$S/oracle.txt" answers-krml.txt 85772 > "$OUT/sample-krml.$RUN.txt" 2>&1
tm pulse-extract-c $F --codegen C --custard_entry PulseTable.ctype_mem PulseTable.fst --odir dc
tm pulse-gcc-c gcc -O2 -I dc -DFN=PulseTable_ctype_mem -o c_e07 dc/Custard.c driver_c.c
tm pulse-sample-c ./c_e07 "$S/queries.txt" answers-c.txt
python3 -I "$L/sample.py" compare "$S/oracle.txt" answers-c.txt 85772 > "$OUT/sample-c.$RUN.txt" 2>&1
ls -l PulseTable.fst kc/Custard.c krml_e07 dc/Custard.c c_e07 2>/dev/null | awk '{print $5"\t"$9}' > "$OUT/sizes.$RUN.tsv"
