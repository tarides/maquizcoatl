#!/bin/sh
# Host setup: clone the repository at a given commit, extract and check the
# LLVM 21.1.8 release toolchain. Usage: setup.sh <commit>
set -eu
. "$(dirname "$0")/env.sh" 2>/dev/null || . ./env.sh
COMMIT=$1
mkdir -p "$HOSTDIR/src" "$HOSTDIR/toolchain" "$LOGS"
if [ ! -d "$SRC" ]; then
  git clone -q https://github.com/tarides/maquizcoatl.git "$SRC"
fi
git -C "$SRC" fetch -q origin
git -C "$SRC" checkout -q "$COMMIT"
git -C "$SRC" submodule update -q --init upstream
test "$(git -C "$UP" rev-parse --short=7 HEAD)" = f95747b
cd "$HOSTDIR/toolchain"
T=LLVM-21.1.8-Linux-X64.tar.xz
test -f $T || curl -sSL -o $T https://github.com/llvm/llvm-project/releases/download/llvmorg-21.1.8/$T
stat -c '%s' $T
sha256sum $T
test -d LLVM-21.1.8-Linux-X64 || tar -xJf $T
find LLVM-21.1.8-Linux-X64/lib/clang -name 'libclang_rt.fuzzer*.a'
"$CC" --version | head -1
# trivial fuzz target
cat > t.c <<'C'
#include <stdint.h>
#include <stddef.h>
int LLVMFuzzerTestOneInput(const uint8_t *d, size_t n) { return 0; }
C
"$CC" -fsanitize=fuzzer,address,undefined t.c -o t && ./t -runs=100 2>&1 | tail -1
