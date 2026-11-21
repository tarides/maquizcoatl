#!/bin/bash
# clightgen.sh SRC OUT: VST's front end (CompCert's clightgen) on the
# hand-written C of mechanism 2: the generated stub (file-scope struct
# initialisers holding function pointers, from stub_data.h), the POSIX
# file, and stub_shell.c (variadic definition with va_list). Records
# per file whether a Clight .v file is produced and what clightgen says.
# Needs clightgen on PATH (opam switch with coq-compcert).
set -u
SRC=$(cd "$1" && pwd); OUT=$(cd "$2" && pwd); HERE=$(cd "$(dirname "$0")" && pwd)
W=$OUT/clightgen; rm -rf "$W"; mkdir -p "$W"
clightgen -version >"$W/version" 2>&1
G=$OUT/stubs/m2/gen
cp "$G/stub.c" "$G/stub_posix.c" "$HERE/stub_shell.c" "$HERE/stub_data.h" "$W/"
cd "$W"
for f in stub.c stub_posix.c stub_shell.c; do
  for mode in plain normalize; do
    opt=""; [ $mode = normalize ] && opt="-normalize"
    rm -f "${f%.c}.v"
    clightgen $opt -I"$SRC/src" -I. "$f" >"$f.$mode.log" 2>&1
    st=$?
    if [ -s "${f%.c}.v" ]; then mv "${f%.c}.v" "${f%.c}.$mode.v"; v=yes; else v=no; fi
    printf '%s\t%s\texit %s\t.v produced: %s\t%s\n' "$f" "$mode" "$st" "$v" \
      "$(grep -v '^$' "$f.$mode.log" | head -3 | tr '\n' ' ' | cut -c1-240)"
  done
done
