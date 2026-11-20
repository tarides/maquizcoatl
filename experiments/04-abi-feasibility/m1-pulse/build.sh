#!/bin/bash
# build.sh SRC OUT [JOBS]
# Mechanism 1: generate OnigStub.fst (default and POSIX variants), check
# it with F*, extract it with both emitters, build each output plus the
# C shell with CMake, install into OUT/stubs/m1{a,b}/{default,posix}.
#   1a: --codegen KrmlC, then krml -no-prefix OnigStub
#   1b: --codegen C --custard_c_no_prefix OnigStub
# Needs the shared F* release on PATH (cache env.sh) and
# OUT/stubs/m2/gen/aux{,p}.txt from m2-c/build.sh.
set -u
SRC=$(cd "$1" && pwd); OUT=$(cd "$2" && pwd); JOBS=${3:-4}
HERE=$(cd "$(dirname "$0")" && pwd)
FS=$(dirname "$(dirname "$(command -v fstar.exe)")")
KINC="$FS/include/krml $FS/lib/krml/dist/minimal"
G=$OUT/stubs/m2/gen
step() { local l=$1; shift; local t0=$SECONDS; "$@" >"$LOG/$l.log" 2>&1; local st=$?
         echo "$l	exit $st	$((SECONDS-t0)) s"; return $st; }
for v in default posix; do
  W=$OUT/stubs/m1-fstar/$v; LOG=$W/logs; rm -rf "$W"; mkdir -p "$W/cache" "$LOG"; cd "$W"
  python3 -I "$HERE/gen_fstar_stub.py" "$G/aux.txt" "$G/auxp.txt" "$HERE/../symbols.tsv" OnigStub.fst $v
  F="fstar.exe --cache_checked_modules --cache_dir cache --z3version 5.3.0"
  step $v-check $F OnigStub.fst || continue
  step $v-extract-krml $F --codegen KrmlC --custard_entry_module OnigStub OnigStub.fst --odir krml
  step $v-krml krml -skip-compilation -no-prefix OnigStub -tmpdir kc krml/*.krml
  step $v-extract-c $F --codegen C --custard_entry_module OnigStub --custard_c_no_prefix OnigStub \
    OnigStub.fst --odir dc
  for e in krml custard; do
    case $e in krml) m=m1a; gd=$W/kc;; custard) m=m1b; gd=$W/dc;; esac
    f=OFF; [ $v = posix ] && f=ON
    B=$OUT/stubs/$m/build-$v; mkdir -p "$OUT/stubs/$m"; rm -rf "$B" "$OUT/stubs/$m/$v"
    step $v-$e-cmake cmake -S "$HERE" -B "$B" -DCMAKE_BUILD_TYPE=Release -DEMITTER=$e \
      -DENABLE_POSIX_API=$f -DONIG_INCLUDE="$SRC/src" -DGEN_DIR="$gd" -DKRML_INCLUDE="$KINC" \
      -DCMAKE_INSTALL_PREFIX="$OUT/stubs/$m/$v" -DCMAKE_INSTALL_LIBDIR=lib
    step $v-$e-make make -C "$B" -j"$JOBS"
    step $v-$e-install make -C "$B" install
  done
done
