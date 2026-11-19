#!/bin/sh
# Four out-of-tree CMake builds of upstream/ and the harnesses.
set -eu
. "$(dirname "$0")/env.sh"
J="taskset -c $CPUS"
NJ=${NJ:-10}
OPT="-O1 -g -fno-omit-frame-pointer"
FUZZ="-fsanitize=fuzzer-no-link,address,undefined -fno-sanitize-recover=undefined"
TESTS="-fsanitize=address,undefined -fsanitize-recover=address,undefined"
ARITH="-fsanitize=unsigned-integer-overflow,implicit-conversion -fsanitize-recover=unsigned-integer-overflow,implicit-conversion"
cfg() { # name cmake-args...
  n=$1; shift
  cmake -S "$UP" -B "$B/$n" -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" "$@" > "$LOGS/cmake-$n.log" 2>&1
}
cfg fuzz  -DBUILD_SHARED_LIBS=OFF -DBUILD_TEST=OFF -DCMAKE_BUILD_TYPE= "-DCMAKE_C_FLAGS=$OPT $FUZZ"
cfg plain -DBUILD_SHARED_LIBS=OFF -DBUILD_TEST=OFF -DCMAKE_BUILD_TYPE= "-DCMAKE_C_FLAGS=$OPT"
cfg tests -DCMAKE_BUILD_TYPE=Debug -DENABLE_POSIX_API=ON "-DCMAKE_C_FLAGS=-fno-omit-frame-pointer $TESTS" "-DCMAKE_EXE_LINKER_FLAGS=$TESTS" "-DCMAKE_SHARED_LINKER_FLAGS=$TESTS"
cfg arith -DCMAKE_BUILD_TYPE=Debug -DENABLE_POSIX_API=ON "-DCMAKE_C_FLAGS=-fno-omit-frame-pointer $ARITH" "-DCMAKE_EXE_LINKER_FLAGS=$ARITH" "-DCMAKE_SHARED_LINKER_FLAGS=$ARITH"
for n in fuzz plain tests arith; do
  $J make -C "$B/$n" -j"$NJ" > "$LOGS/make-$n.log" 2>&1 &
done
wait
for n in fuzz plain tests arith; do tail -1 "$LOGS/make-$n.log"; done
mkdir -p "$H"
HD=$UP/harnesses
cp "$HD/base.c" "$H/base-deep.c"
patch -s "$H/base-deep.c" < "$EXP/fuzzer-deep.patch"
I="-I$UP/src -Wall $OPT"
FL="-fsanitize=fuzzer,address,undefined -fno-sanitize-recover=undefined"
RL="-fsanitize=address,undefined -fno-sanitize-recover=undefined -DSTANDALONE"
LIB=$B/fuzz/libonig.a
mk() { # out compiler flags src
  o=$1; c=$2; shift 2
  $J "$c" $I "$@" -o "$H/$o" >> "$LOGS/harness.log" 2>&1 || { echo "FAILED $o"; return 1; }
}
: > "$LOGS/harness.log"
mk fuzzer-encode   "$CC"  $FL "$HD/base.c" "$LIB" &
mk fuzzer-syntax   "$CC"  $FL -DSYNTAX_TEST "$HD/base.c" "$LIB" &
mk fuzzer-utf16-be "$CC"  $FL -DUTF16_BE "$HD/base.c" "$LIB" &
mk fuzzer-utf16-le "$CC"  $FL -DUTF16_LE "$HD/base.c" "$LIB" &
mk fuzzer-regset   "$CC"  $FL "$HD/regset.c" "$LIB" &
mk fuzzer-deluxe   "$CC"  $FL "$HD/deluxe.c" "$LIB" &
mk libfuzzer-onig  "$CXX" $FL "$HD/libfuzzer-onig.cpp" "$LIB" &
mk libfuzzer-onig-full "$CXX" $FL -DFULL_TEST "$HD/libfuzzer-onig.cpp" "$LIB" &
mk fuzzer-deep     "$CC"  $FL "$H/base-deep.c" "$LIB" &
wait
# read-* replay binaries: fuzzer-no-link keeps the library's coverage
# instrumentation linkable without libFuzzer's main.
RF="-fsanitize=fuzzer-no-link,address,undefined -fno-sanitize-recover=undefined -DSTANDALONE"
mk read-encode   "$CC" $RF "$HD/base.c" "$LIB" &
mk read-syntax   "$CC" $RF -DSYNTAX_TEST "$HD/base.c" "$LIB" &
mk read-utf16-be "$CC" $RF -DUTF16_BE "$HD/base.c" "$LIB" &
mk read-utf16-le "$CC" $RF -DUTF16_LE "$HD/base.c" "$LIB" &
mk read-regset   "$CC" $RF "$HD/regset.c" "$LIB" &
mk read-deluxe   "$CC" $RF "$HD/deluxe.c" "$LIB" &
mk read-deep     "$CC" $RF "$H/base-deep.c" "$LIB" &
mk read-deep-plain "$CC" -DSTANDALONE "$H/base-deep.c" "$B/plain/libonig.a" &
# read-deep-ns: read-deep with the harness file compiled without the
# shift-base check, because base.c:98 (to_binary, STANDALONE only) is a
# signed 1 << 31 that aborts read-deep before parsing. The library keeps
# the full fuzz-build checks.
mk read-deep-ns  "$CC" $RF -fno-sanitize=shift-base "$H/base-deep.c" "$LIB" &
wait
cp "$HD/ascii_compatible.dict" "$H/ascii.dict"
python3 -I "$HD/dict_conv.py" utf16_be < "$HD/ascii_compatible.dict" > "$H/utf16_be.dict"
python3 -I "$HD/dict_conv.py" utf16_le < "$HD/ascii_compatible.dict" > "$H/utf16_le.dict"
ls "$H"
git -C "$UP" status --porcelain | wc -l
