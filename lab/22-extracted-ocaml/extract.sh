#!/bin/bash
# Issue #22, plan steps 3-4: check that the clone's experiment #9 sources
# are those of e1b9936, then regenerate the Rocq- and F*-extracted OCaml
# (the steps of lab/09-representative-proof/rocq/rocq.sh and
# fstar/fstar.sh) and copy it, with gen/*/dune, into <exp>/gen/.
# Untimed: nice -n 10, taskset -c 0-3,32-35, switch provers unchanged.
# Usage: CACHE=<cache> EXP=<exp> extract.sh RUNID
# Prints no host name, address or absolute path.
set -euo pipefail
: "${CACHE:?}" "${EXP:?}"
RID=${1:?run-id}
. "$CACHE/env.sh"
R=$EXP/repo; L9=$R/lab/09-representative-proof; L22=$R/lab/22-extracted-ocaml
OUT=$EXP/out/$RID/extract; mkdir -p "$OUT"
U="nice -n 10 taskset -c 0-3,32-35"
X="opam exec --switch provers --"
red() { sed "s|$EXP|<exp>|g; s|$CACHE|<cache>|g"; }
# step 3: source check
SRC="lab/09-representative-proof/rocq lab/09-representative-proof/fstar lab/06-spec-speed/rocq/Spec2.v lab/06-spec-speed/fstar/Spec2.fst"
if git -C "$R" diff --quiet e1b9936 HEAD -- $SRC; then
  echo "source check: identical to e1b9936 ($SRC)" | tee "$OUT/source-check.txt"
else
  echo "source check: DIFFERENT from e1b9936" | tee "$OUT/source-check.txt"; exit 1
fi
# step 4, Rocq (rocq/rocq.sh:23, :31)
B=$EXP/extract/rocq; rm -rf "$B"; mkdir -p "$B"; cd "$B"
cp "$L9"/rocq/*.v .; cp TablesStub.v Tables.v
$X rocq --version > "$OUT/rocq-version.txt" 2>&1
{ for f in Syntax Sem Compile Vm Extract; do
    echo "== $X rocq compile -R . S $f.v"; $U $X rocq compile -R . S "$f.v"; done; } 2>&1 | red > "$OUT/rocq-build.log"
# step 4, F* (fstar/fstar.sh:21-24, :28, :31-35)
B=$EXP/extract/fstar; rm -rf "$B"; mkdir -p "$B/cache"; cd "$B"
cp "$L9"/fstar/*.fst "$R/lab/06-spec-speed/fstar/Spec2.fst" .; cp TablesStub.fst Tables.fst
F="fstar.exe --cache_checked_modules --cache_dir cache --z3version 5.3.0"
ENTRIES="Compile.compile Vm.vm Sem.sem Syntax.ncap Syntax.search Spec2.search Spec2.search_from Spec2.lookup Spec2.fuel0"
fstar.exe --version > "$OUT/fstar-version.txt" 2>&1
{ for f in Syntax Sem Compile Vm Statement Tables Spec2 Extract; do
    echo "== $F $f.fst"; $U $F "$f.fst"; done
  echo "== $F --codegen OCaml $(for e in $ENTRIES; do printf -- '--custard_entry %s ' "$e"; done)Extract.fst --odir ml"
  $U $F --codegen OCaml $(for e in $ENTRIES; do printf -- '--custard_entry %s ' "$e"; done) Extract.fst --odir ml
  cp "$CACHE/fstar/lib/fstar/lib/app/Prims.ml" ml/; echo "== cp <cache>/fstar/lib/fstar/lib/app/Prims.ml ml/"
} 2>&1 | red > "$OUT/fstar-build.log"
# copy into <exp>/gen with the committed dune stanzas
rm -rf "$EXP/gen"; mkdir -p "$EXP/gen/rocq" "$EXP/gen/fstar"
cp "$EXP/extract/rocq/frag.ml" "$EXP/extract/rocq/frag.mli" "$L22/gen/rocq/dune" "$EXP/gen/rocq/"
cp "$EXP/extract/fstar/ml/Custard.ml" "$EXP/extract/fstar/ml/Prims.ml" "$L22/gen/fstar/dune" "$EXP/gen/fstar/"
# sha256, against experiment #9's copies (Rocq run 4, F* run 2)
REF="e76cf6f5643d59c21ed9c3d33af7440948c3f491db9b52e4cd95e32bbbc27c6f frag.ml
0fd4524098b411a0c907e6a929012e18bd1287934e45395b98e16ded91f1458e frag.mli
ae703add9eb3bda0e825a3f61a14721df4068e7825f0a6cee57a19941895f238 Custard.ml
e5b8a7e72625052eaccdbc3693aac8e26d8933498fe21a1369f3b1d809220aa8 Prims.ml"
cd "$EXP/gen"
for f in rocq/frag.ml rocq/frag.mli fstar/Custard.ml fstar/Prims.ml; do
  h=$(sha256sum "$f" | cut -d' ' -f1); b=$(basename "$f")
  r=$(echo "$REF" | awk -v b="$b" '$2==b{print $1}')
  echo "$h  $f  $([ "$h" = "$r" ] && echo "same as experiment #9's copy" || echo "DIFFERENT from experiment #9's copy $r")"
done | tee "$OUT/sha256.txt"
