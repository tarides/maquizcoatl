#!/bin/bash
# Experiment #7, F*.  Usage: RUN=<n> fstar.sh <run-id>
set -uo pipefail
EXP=${EXP:-$HOME/maquizcoatl-work/exp/07-large-tables}
L=$(cd "$(dirname "$0")/.." && pwd)
. "$HOME/maquizcoatl-work/cache/env.sh"; . "$L/queries.env"
export OUT=$EXP/out/$1/fstar; . "$L/tm.sh"
B=$EXP/build/fstar/$1.$RUN; rm -rf "$B"; mkdir -p "$B"; cd "$B"
cp "${EMIT:-$EXP/emit}"/fstar/Table.fst "${EMIT:-$EXP/emit}"/fstar/TableC.fst "$L"/fstar/Mem.fst "$L"/fstar/*.c .
F="fstar.exe --cache_checked_modules --cache_dir cache --z3version 5.3.0"
mkdir -p cache
fstar.exe --version > "$OUT/version.txt"; krml -version >> "$OUT/version.txt" 2>&1
tm fstar-check  $F Table.fst
tm fstarc-check $F TableC.fst
[ "${ONLY_TABLE:-}" ] && exit 0
$F Mem.fst > "$OUT/mem.$RUN.log" 2>&1
X="opam exec --switch=provers --"
S=$EXP/sample
# OCaml target
tm fstar-extract-ocaml $F --codegen OCaml --custard_entry Mem.ctype_mem --custard_entry Mem.lookup_name Mem.fst --odir ml
{ echo 'module M = struct let ctype_mem a b = Custard.mem_ctype_mem (Z.of_int a) (Z.of_int b)
  let lookup_name s = Z.to_int (Custard.mem_lookup_name s) end'; cat "$L/main_ml.ml"; } > ml/main.ml
# fstar.lib in the binary release is compiled by OCaml 5.3.0; the one module the
# extracted code uses (Prims) is compiled from its shipped source in the switch.
cp "$CACHE/fstar/lib/fstar/lib/app/Prims.ml" ml/
cd ml
tm fstar-ocamlopt $X ocamlfind ocamlopt -package zarith -linkpkg Prims.ml Custard.ml main.ml -o fstar_e07
cd ..
tm fstar-sample ml/fstar_e07 "$S/queries.txt" "$S/names.txt" answers-ocaml.txt
python3 -I "$L/sample.py" compare "$S/oracle.txt" answers-ocaml.txt > "$OUT/sample-ocaml.$RUN.txt" 2>&1
# KaRaMeL C target
tm fstarc-extract-krml $F --codegen KrmlC --extract TableC TableC.fst --odir krml
tm fstarc-krml krml -skip-compilation -tmpdir kc krml/*.krml
tm fstarc-gcc-krml gcc -O2 -I kc -I "$CACHE/fstar/include/krml" -o krml_e07 kc/TableC.c driver_c.c -DTABLEC_KRML
tm fstarc-sample-krml ./krml_e07 "$S/queries.txt" answers-krml.txt
python3 -I "$L/sample.py" compare "$S/oracle.txt" answers-krml.txt 85772 > "$OUT/sample-krml.$RUN.txt" 2>&1
# direct C target
tm fstarc-extract-c $F --codegen C --extract TableC TableC.fst --odir dc
tm fstarc-gcc-c gcc -O2 -I dc -o c_e07 dc/*.c driver_c.c -DTABLEC_DIRECT
tm fstarc-sample-c ./c_e07 "$S/queries.txt" answers-c.txt
python3 -I "$L/sample.py" compare "$S/oracle.txt" answers-c.txt 85772 > "$OUT/sample-c.$RUN.txt" 2>&1
ls -l Table.fst TableC.fst ml/Custard.ml ml/fstar_e07 kc/TableC.c krml_e07 dc/* c_e07 2>/dev/null | awk '{print $5"\t"$9}' > "$OUT/sizes.$RUN.tsv"
[ "$RUN" = 1 ] || exit 0
q() { printf 'module %s\nopen Mem\n%s\n' "$1" "$2" > "$1.fst"; tm "fstar-$1" $F "$1.fst"; }
q Q0 ''
q Q1 "let _ = assert_norm (ctype_mem $LU 65 = true)"
q Q2 "let _ = assert_norm (ctype_mem $LU 233 = false)"
q Q3 "let _ = assert_norm (ctype_mem $GB 205743 = true)"
q Q4 "let _ = assert_norm (ctype_mem $GB 205744 = false)"
TMO=1800 q S1 "let _ = assert_norm (table_ok = true)"
