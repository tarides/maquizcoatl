#!/bin/bash
# Experiment #9, F* M1.  BENCH_WORKDIR=<bench-workdir> fstar/fstar.sh build <run-id>
# build: check the definitions (Syntax, Sem, Compile, Vm, Statement),
#        then experiment #6's Spec2.fst over TablesStub.fst and the
#        extraction root Extract.fst; extract to OCaml (--codegen OCaml,
#        one --custard_entry per name the driver uses), compile the
#        extracted Custard.ml with the release's Prims.ml source (Prims
#        only, as experiment #6: the release's fstar.lib is built by
#        OCaml 5.3.0, the switch is 5.4.1) and the driver; run it on the
#        fragment's cases and the extra probes (untimed: nice -n 10,
#        CPUs 4-7).  The timed checks are timed.sh's.
# Prints no hostnames, addresses or absolute paths.
set -euo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory}"
PHASE=${1:?phase} RID=${2:?run-id}
CACHE=$BENCH_WORKDIR/cache; EXP=$BENCH_WORKDIR/exp/09-representative-proof
L=$EXP/repo/lab/09-representative-proof; E06=$EXP/repo/lab/06-spec-speed/fstar
OUT=$EXP/out/$RID/fstar; mkdir -p "$OUT"
. "$CACHE/env.sh"
X="opam exec --switch provers --"
F="fstar.exe --cache_checked_modules --cache_dir cache --z3version 5.3.0"
PRIMS=$CACHE/fstar/lib/fstar/lib/app/Prims.ml
OPK=zarith,yojson,ppx_deriving.show,ppx_deriving_yojson
ENTRIES="Compile.compile Vm.vm Sem.sem Syntax.ncap Syntax.search Spec2.search Spec2.search_from Spec2.lookup Spec2.fuel0"
case $PHASE in
build)
  B=$EXP/build/fstar/$RID; rm -rf "$B"; mkdir -p "$B/cache"; cd "$B"
  cp "$L"/fstar/*.fst "$L/fstar/main.ml" "$E06/Spec2.fst" .; cp TablesStub.fst Tables.fst
  U="nice -n 10 taskset -c 4-7"
  fstar.exe --version > "$OUT/version.txt" 2>&1
  { for f in Syntax Sem Compile Vm Statement Tables Spec2 Extract; do
      echo "== $f"; $U $F "$f.fst"; done
    echo "== extract"
    $U $F --codegen OCaml $(for e in $ENTRIES; do printf -- '--custard_entry %s ' "$e"; done) Extract.fst --odir ml
    cp "$PRIMS" main.ml ml/; cd ml
    $U $X ocamlfind ocamlopt -package $OPK,unix -linkpkg Prims.ml Custard.ml main.ml -o fstar_e09
  } > "$OUT/build.log" 2>&1
  sed -i "s|$BENCH_WORKDIR|<bench-workdir>|g" "$OUT/build.log"
  for c in fragment extra; do $U ./fstar_e09 "$L/cases/$c.tsv" > "$OUT/$c.verdicts.txt"; done
  wc -l "$OUT"/*.verdicts.txt | sed 's|/.*/||' ;;
*) echo "unknown phase $PHASE" >&2; exit 2 ;;
esac
