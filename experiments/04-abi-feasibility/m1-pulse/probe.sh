#!/bin/bash
# probe.sh OUT: check Probe.fst and extract it with both emitters.
#   1a: fstar.exe --codegen KrmlC, then krml -no-prefix Probe
#   1b: fstar.exe --codegen C --custard_c_no_prefix Probe
# Needs the shared F* release (BENCH cache env.sh sourced by the caller).
set -u
OUT=$1; HERE=$(cd "$(dirname "$0")" && pwd)
W=$OUT/m1-probe; rm -rf "$W"; mkdir -p "$W/cache"; cd "$W"
cp "$HERE/Probe.fst" .
fstar.exe --version >version.txt; krml -version >>version.txt 2>&1
F="fstar.exe --cache_checked_modules --cache_dir cache --z3version 5.3.0"
run() { local l=$1; shift; "$@" >"$l.log" 2>&1; echo "$l	exit $?"; }
run check $F Probe.fst
run extract-krml $F --codegen KrmlC --custard_entry_module Probe Probe.fst --odir krml
run krml krml -skip-compilation -no-prefix Probe -tmpdir kc krml/*.krml
run extract-c $F --codegen C --custard_entry_module Probe --custard_c_no_prefix Probe Probe.fst --odir dc
