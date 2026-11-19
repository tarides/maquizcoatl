#!/bin/bash
# Experiment #11, steps 3-4: build every engine and harness on the bench
# host from pinned sources. Every command is echoed (set -x) into the log.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/env.sh"
REPO=$(cd "$HERE/../.." && pwd)
UP="$REPO/upstream"
B="$BENCH/build"; P="$BENCH/prefix"; BIN="$BENCH/bin"
mkdir -p "$B" "$P" "$BIN"
J="taskset -c $BUILD_CPUS"
CFLAGS_E11="-O3 -DNDEBUG"
[ "$(git -C "$UP" rev-parse HEAD)" = f95747b462de672b6f8dbdeb478245ddf061ca53 ] || { echo "upstream not at f95747b" >&2; exit 1; }
set -x

# Oniguruma, two dispatch builds, static, Release (-O3 -DNDEBUG).
for v in threaded switch; do
  extra=""; [ $v = switch ] && extra="-DONIG_DISABLE_DIRECT_THREADING"
  cmake -S "$UP" -B "$B/onig-$v" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_C_FLAGS="$extra" > "$B/onig-$v.cmake.log"
  $J make -C "$B/onig-$v" -j4 onig > "$B/onig-$v.make.log"
  # Dispatch probe with this build's flags and config.h.
  gcc $CFLAGS_E11 $extra -I"$B/onig-$v" -I"$UP/src" -o "$BIN/probe-$v" "$HERE/dispatch_probe.c"
  "$BIN/probe-$v"
  gcc $CFLAGS_E11 -I"$UP/src" -I"$HERE" -o "$BIN/onig-$v" "$HERE/onig_bench.c" "$B/onig-$v/libonig.a"
done
sha256sum "$B"/onig-*/CMakeFiles/onig.dir/src/regexec.c.o | sed "s|$B/||"
if cmp -s "$B/onig-threaded/CMakeFiles/onig.dir/src/regexec.c.o" "$B/onig-switch/CMakeFiles/onig.dir/src/regexec.c.o"; then
  echo "regexec.c.o identical in both builds" >&2; exit 1
fi

# PCRE2 10.49: 8-bit only, JIT, static.
rm -rf "$B/pcre2-src"; mkdir -p "$B/pcre2-src"
tar -xzf "$BENCH/src/pcre2-10.49.tar.gz" -C "$B/pcre2-src" --strip-components=1
cmake -S "$B/pcre2-src" -B "$B/pcre2" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DPCRE2_BUILD_PCRE2_8=ON -DPCRE2_BUILD_PCRE2_16=OFF -DPCRE2_BUILD_PCRE2_32=OFF \
  -DPCRE2_SUPPORT_JIT=ON -DPCRE2_BUILD_PCRE2GREP=OFF -DPCRE2_BUILD_TESTS=OFF \
  -DCMAKE_INSTALL_PREFIX="$P" > "$B/pcre2.cmake.log"
$J make -C "$B/pcre2" -j4 install > "$B/pcre2.make.log"
for j in 0 1; do
  n=pcre2-interp; [ $j = 1 ] && n=pcre2-jit
  gcc $CFLAGS_E11 -DE11_JIT=$j -I"$P/include" -I"$HERE" -o "$BIN/$n" "$HERE/pcre2_bench.c" "$P/lib/libpcre2-8.a"
done

# Abseil then RE2, static, C++17, into $P.
for x in abseil re2; do
  t=$(ls "$BENCH"/src/${x}*.tar.gz | head -1)
  rm -rf "$B/$x-src"; mkdir -p "$B/$x-src"; tar -xzf "$t" -C "$B/$x-src" --strip-components=1
done
cmake -S "$B/abseil-src" -B "$B/abseil" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_PREFIX_PATH="$P" -DCMAKE_CXX_STANDARD=17 -DABSL_PROPAGATE_CXX_STD=ON \
  -DABSL_BUILD_TESTING=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_INSTALL_PREFIX="$P" > "$B/abseil.cmake.log"
$J make -C "$B/abseil" -j4 install > "$B/abseil.make.log"
cmake -S "$B/re2-src" -B "$B/re2" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_PREFIX_PATH="$P" -DCMAKE_CXX_STANDARD=17 -DABSL_PROPAGATE_CXX_STD=ON \
  -DRE2_BUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX="$P" > "$B/re2.cmake.log"
$J make -C "$B/re2" -j4 install > "$B/re2.make.log"
# Link the RE2 harness through a tiny CMake project so that Abseil's
# static link order is resolved by its own package config.
mkdir -p "$B/re2_bench_proj"
cat > "$B/re2_bench_proj/CMakeLists.txt" <<CM
cmake_minimum_required(VERSION 3.16)
project(re2_bench CXX)
set(CMAKE_CXX_STANDARD 17)
find_package(re2 REQUIRED)
add_executable(re2_bench "$HERE/re2_bench.cc")
target_include_directories(re2_bench PRIVATE "$HERE")
target_link_libraries(re2_bench re2::re2)
CM
cmake -S "$B/re2_bench_proj" -B "$B/re2_bench" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$P" > "$B/re2_bench.cmake.log"
$J make -C "$B/re2_bench" -j4 > "$B/re2_bench.make.log"
cp "$B/re2_bench/re2_bench" "$BIN/re2"

# Rust regex, locked.
( cd "$HERE/rust_bench" && [ -f Cargo.lock ] || cargo generate-lockfile )
( cd "$HERE/rust_bench" && CARGO_TARGET_DIR="$B/rust" $J cargo build --release --locked -j4 )
cp "$B/rust/release/rust_bench" "$BIN/rust-regex"

# OCaml ocaml-re.
( cd "$HERE/ocaml_bench" && $J opam exec -- dune build --release --build-dir="$B/ocaml" ./ocaml_bench.exe )
# dune leaves its output read-only: replace, do not overwrite, the binary.
install -m 755 "$B/ocaml/default/ocaml_bench.exe" "$BIN/ocaml-re"
set +x
echo build done
