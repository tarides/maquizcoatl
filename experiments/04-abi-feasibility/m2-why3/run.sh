#!/bin/sh
# run.sh OUT: extract each module of abi.mlw to C with Why3's C driver,
# one module at a time, and record the result (C text or error).
# Needs why3 on PATH (the shared opam switch).
set -u
OUT=$1; HERE=$(cd "$(dirname "$0")" && pwd)
W=$OUT/why3; mkdir -p "$W"
why3 --version >"$W/why3.version"
for m in Fun EncStruct DataStruct DataScalar DataScalarDef; do
  mkdir -p "$W/$m"
  if why3 extract -D c -L "$HERE" "abi.$m" -o "$W/$m/$m.c" >"$W/$m.log" 2>&1; then
    echo "$m	extracted"
  else
    echo "$m	error: $(tr '\n' ' ' <"$W/$m.log" | cut -c1-300)"
  fi
done
