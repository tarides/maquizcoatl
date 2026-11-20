#!/bin/sh
# build.sh SRC OUT [JOBS]
# Mechanism 2: generate the C stub from the public headers, build it
# with CMake (default and POSIX), install into OUT/stubs/m2/{default,posix}.
set -eu
SRC=$(cd "$1" && pwd); OUT=$(cd "$2" && pwd); JOBS=${3:-4}
HERE=$(cd "$(dirname "$0")" && pwd)
G=$OUT/stubs/m2/gen; mkdir -p "$G"
printf '#include "oniggnu.h"\n' >"$G/a.c"
printf '#include "onigposix.h"\n' >"$G/p.c"
gcc -I"$SRC/src" -fsyntax-only -aux-info "$G/aux.txt" "$G/a.c"
gcc -I"$SRC/src" -fsyntax-only -aux-info "$G/auxp.txt" "$G/p.c"
python3 -I "$HERE/gen_c_stub.py" "$G/aux.txt" "$G/auxp.txt" "$HERE/../symbols.tsv" "$G"
for v in default posix; do
  f=OFF; [ $v = posix ] && f=ON
  B=$OUT/stubs/m2/build-$v
  cmake -S "$HERE" -B "$B" -DCMAKE_BUILD_TYPE=Release -DENABLE_POSIX_API=$f \
    -DCMAKE_C_FLAGS="-Wall -Wextra -std=c99" \
    -DONIG_INCLUDE="$SRC/src" -DGEN_DIR="$G" \
    -DCMAKE_INSTALL_PREFIX="$OUT/stubs/m2/$v" -DCMAKE_INSTALL_LIBDIR=lib >"$B.cmake.log" 2>&1
  make -C "$B" -j"$JOBS" >"$B.make.log" 2>&1
  make -C "$B" install >"$B.install.log" 2>&1
done
