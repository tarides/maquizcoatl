#!/bin/sh
# oracle.sh SRC OUT [JOBS]
# Builds upstream (f95747b) out of tree, Release, default and POSIX,
# installs each into its own prefix and records the ABI reference:
# nm -D --defined-only, readelf -d, library file names.
set -eu
SRC=$(cd "$1" && pwd); OUT=$2; JOBS=${3:-4}
mkdir -p "$OUT/build"; OUT=$(cd "$OUT" && pwd)
for v in default posix; do
  case $v in default) b=onig; f=OFF;; posix) b=onig-posix; f=ON;; esac
  cmake -S "$SRC" -B "$OUT/build/$b" -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_POSIX_API=$f -DCMAKE_INSTALL_PREFIX="$OUT/oracle/$v" \
        -DCMAKE_INSTALL_LIBDIR=lib >"$OUT/build/$b.cmake.log" 2>&1
  make -C "$OUT/build/$b" -j"$JOBS" >"$OUT/build/$b.make.log" 2>&1
  make -C "$OUT/build/$b" install >"$OUT/build/$b.install.log" 2>&1
  lib="$OUT/oracle/$v/lib"
  nm -D --defined-only "$lib/libonig.so.5" | awk '{print $3, $2}' | sort \
     >"$OUT/oracle/$v.nm"
  readelf -d "$lib/libonig.so.5" >"$OUT/oracle/$v.readelf"
  ls -l "$lib" | awk '/libonig/{print $9, $10, $11}' >"$OUT/oracle/$v.files"
done
