#!/bin/sh
# harness.sh SRC OUT
# Needs OUT/build/{onig,onig-posix} and OUT/oracle/{default,posix}
# from oracle.sh. Builds OUT/harness: the upstream test binaries with
# RUNPATH removed, 15 samples (crnl.c excluded), client_encoding,
# layout reference outputs, and golden outputs from upstream.
set -eu
SRC=$(cd "$1" && pwd); OUT=$(cd "$2" && pwd); HERE=$(cd "$(dirname "$0")" && pwd)
H=$OUT/harness; mkdir -p "$H/bin" "$H/golden" "$H/ref"
CC=${CC:-gcc}
for t in test_utf8 test_back testc testcu test_syntax test_options test_regset; do
  cp "$OUT/build/onig/test/$t" "$H/bin/$t"
done
cp "$OUT/build/onig-posix/test/testp" "$H/bin/testp"
for b in "$H"/bin/test*; do patchelf --remove-rpath "$b"; done
for s in "$SRC"/sample/*.c; do
  n=$(basename "$s" .c)
  case $n in crnl) continue;; posix) v=posix;; *) v=default;; esac
  $CC -O1 -I"$SRC/src" -o "$H/bin/$n" "$s" -L"$OUT/oracle/$v/lib" -lonig
done
$CC -O1 -std=gnu11 -I"$SRC/src" -o "$H/bin/client_encoding" "$HERE/client_encoding.c" \
    -L"$OUT/oracle/default/lib" -lonig
# layout references, compiled against upstream's own headers
$CC -std=gnu11 -I"$SRC/src" -o "$H/ref/layout" "$HERE/layout.c"
$CC -std=gnu11 -I"$SRC/src" -o "$H/ref/layout_posix" "$HERE/layout_posix.c"
"$H/ref/layout" >"$H/ref/layout.txt"; "$H/ref/layout_posix" >"$H/ref/layout_posix.txt"
# golden outputs (stdout+stderr, exit status) from upstream
for b in "$H"/bin/*; do
  n=$(basename "$b"); case $n in testp|posix) v=posix;; *) v=default;; esac
  st=0
  ( cd "$H" && LD_LIBRARY_PATH="$OUT/oracle/$v/lib" timeout 120 "$b" </dev/null \
      >"$H/golden/$n.out" 2>&1 ) || st=$?
  echo $st >"$H/golden/$n.status"
done
