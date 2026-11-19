#!/bin/bash
# source-level.sh SRC OUT STUBDIR CMAKE_SRC GEN_DIR
# Criterion 4 for a stub that has a CMake build (mechanisms 1 and 2):
#  (a) the CMake build itself (already done by the mechanism's build.sh;
#      re-checked here from its installed prefix),
#  (b) pkg-config --cflags --libs oniguruma on the installed prefix and
#      a client (sample/simple.c) built with those flags and run,
#  (c) an emscripten build of the stub (emcmake cmake), static library,
#      linked with sample/simple.c into a wasm program and run under node.
# Prints TSV: criterion, item, result, detail.
set -u
SRC=$(cd "$1" && pwd); OUT=$(cd "$2" && pwd); S=$(cd "$3" && pwd)
CSRC=$(cd "$4" && pwd); GEN=$(cd "$5" && pwd)
out() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }
P=$S/default
r=fail; [ -f "$P/lib/libonig.so.5.5.0" ] && [ -f "$P/include/oniguruma.h" ] && r=pass
out 4 cmake-build $r "installed prefix from the stub's CMakeLists.txt"
flags=$(PKG_CONFIG_PATH="$P/lib/pkgconfig" pkg-config --cflags --libs oniguruma 2>&1)
rc=$?; r=fail; [ $rc -eq 0 ] && r=pass
out 4 pkg-config $r "$(echo "$flags" | sed "s|$OUT|<out>|g")"
if gcc -o "$S/client-simple" "$SRC/sample/simple.c" $flags 2>"$S/client.log"; then
  LD_LIBRARY_PATH="$P/lib" timeout 10 "$S/client-simple" >"$S/client.out" 2>&1
  out 4 pkg-config-client pass "built with pkg-config flags; run exit $?"
else out 4 pkg-config-client fail "see client.log"; fi
# emscripten
set +u; . "$EMSDK_ENV" >/dev/null 2>&1; set -u
emcc --version | head -1 >"$S/emcc.version"
B=$S/build-wasm
emcmake cmake -S "$CSRC" -B "$B" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DONIG_INCLUDE="$SRC/src" -DGEN_DIR="$GEN" -DCMAKE_INSTALL_PREFIX="$S/wasm" \
  -DCMAKE_INSTALL_LIBDIR=lib >"$B.cmake.log" 2>&1 \
 && emmake make -C "$B" -j"${JOBS:-4}" >"$B.make.log" 2>&1 \
 && make -C "$B" install >"$B.install.log" 2>&1
r=fail; [ -f "$S/wasm/lib/libonig.a" ] && r=pass
out 4 emscripten-build $r "emcmake cmake + make, static libonig.a"
if emcc -O1 -I"$S/wasm/include" -o "$S/simple.js" "$SRC/sample/simple.c" "$S/wasm/lib/libonig.a" \
     >"$S/emcc-client.log" 2>&1; then
  node "$S/simple.js" >"$S/simple-wasm.out" 2>&1
  out 4 emscripten-client pass "sample/simple.c linked to wasm, node exit $?"
else out 4 emscripten-client fail "see emcc-client.log"; fi
