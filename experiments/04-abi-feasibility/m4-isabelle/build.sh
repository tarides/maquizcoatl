#!/bin/bash
# build.sh SRC OUT CACHE [JOBS]
# Mechanism 4 (Isabelle-LLVM): generate the stub theories from the
# public headers, build them with Isabelle (export_llvm writes
# OnigStub.ll, OnigStubPosix.ll and their C headers), compile the IR
# with clang from the pinned LLVM release, link it with the
# hand-written C shell (mechanism 2's variadic stub_shell.c and the
# generated data symbols), and install into OUT/stubs/m4/{default,posix}
# with soname libonig.so.5, the three file names and the upstream
# headers. Exports are limited to the public names (DEV-005) with the
# version scripts written by exports.sh (OUT/exports/onig-*.map).
# Needs OUT/stubs/m2/gen/aux{,p}.txt from m2-c/build.sh and the
# toolchain from install.sh in CACHE. Prints one line per step.
set -u
SRC=$(cd "$1" && pwd); OUT=$(cd "$2" && pwd); CACHE=$(cd "$3" && pwd); JOBS=${4:-4}
HERE=$(cd "$(dirname "$0")" && pwd)
ISA=$CACHE/isabelle/bin/isabelle
AFP=$CACHE/isabelle/afp-2026-11-19/afp-2026-11-19
ILLVM=$CACHE/isabelle/isabelle_llvm
CLANG=$CACHE/llvm/current/clang
M=$OUT/stubs/m4; G=$M/gen; LOG=$M/logs
rm -rf "$M"; mkdir -p "$G" "$LOG"
step() { local l=$1; shift; local t0=$SECONDS; "$@" >"$LOG/$l.log" 2>&1; local st=$?
         echo "$l	exit $st	$((SECONDS-t0)) s"; return $st; }

step generate python3 -I "$HERE/gen_isabelle_stub.py" "$OUT/stubs/m2/gen/aux.txt" \
  "$OUT/stubs/m2/gen/auxp.txt" "$HERE/../symbols.tsv" "$G" || exit 1
step sizes "$CLANG" -std=c11 -fsyntax-only -I"$SRC/src" "$G/sizes.c" || exit 1
# -c: export_llvm writes the .ll files only when the theory is processed.
step isabelle /usr/bin/time -v "$ISA" build -c -j 1 -o threads="$JOBS" \
  -d "$AFP/thys" -d "$ILLVM/thys" -D "$G" || exit 1
ls "$G"/*.ll "$G"/*.h >"$LOG/exported-files.txt" 2>&1
step ir-default "$CLANG" -O2 -fPIC -c "$G/OnigStub.ll" -o "$G/OnigStub.o" || exit 1
step ir-posix "$CLANG" -O2 -fPIC -c "$G/OnigStubPosix.ll" -o "$G/OnigStubPosix.o" || exit 1
CF="-O2 -fPIC -std=c99 -Wall -Wextra -I$SRC/src -I$HERE/../m2-c"
step shell-data "$CLANG" $CF -c "$G/shell_data.c" -o "$G/shell_data.o" || exit 1
step shell-variadic "$CLANG" $CF -c "$HERE/../m2-c/stub_shell.c" -o "$G/stub_shell.o" || exit 1
for v in default posix; do
  P=$M/$v; mkdir -p "$P/lib" "$P/include"
  objs="$G/OnigStub.o $G/shell_data.o $G/stub_shell.o"
  hdrs="$SRC/src/oniguruma.h $SRC/src/oniggnu.h"
  if [ $v = posix ]; then objs="$objs $G/OnigStubPosix.o"; hdrs="$hdrs $SRC/src/onigposix.h"; fi
  step link-$v "$CLANG" -shared -fuse-ld=bfd -Wl,-soname,libonig.so.5 \
    -Wl,--version-script="$OUT/exports/onig-$v.map" -o "$P/lib/libonig.so.5.5.0" $objs || exit 1
  ln -sfn libonig.so.5.5.0 "$P/lib/libonig.so.5"
  ln -sfn libonig.so.5 "$P/lib/libonig.so"
  cp $hdrs "$P/include/"
done
echo "build-m4 done"
