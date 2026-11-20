#!/bin/bash
# Experiment #8 setup on the bench host.  Usage: setup.sh verus|onig|smoke
# Rocq, Lean 4 and F* (with Pulse) are experiment #7's toolchains
# (lab/07-large-tables/setup.sh); this script adds Verus and the two C builds.
# Paths come from BENCH_WORKDIR (written <bench-workdir> in public text);
# nothing printed here contains absolute paths.
set -euo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
CACHE=$BENCH_WORKDIR/cache EXP=${EXP:-$BENCH_WORKDIR/exp/08-hard-features}
JOBS=${JOBS:-4}
L=$(cd "$(dirname "$0")" && pwd)
fetch() { [ -f "$3" ] || curl -fsSL -o "$3" "$1"; echo "$2  $3" | sha256sum -c --quiet; }
case "$1" in
verus)
  VZ=verus-0.2026.11.02.8bf68ee-x86-linux.zip
  mkdir -p "$CACHE/dl"
  fetch "https://github.com/verus-lang/verus/releases/download/release/0.2026.11.02.8bf68ee/$VZ" \
    f3a0119292df8855e4435da8130bee1873b0e6a60c306accf81a08ea687bba3c "$CACHE/dl/$VZ"
  if [ ! -d "$CACHE/verus" ]; then
    rm -rf "$CACHE/dl/verus-unz"; mkdir -p "$CACHE/dl/verus-unz"
    (cd "$CACHE/dl/verus-unz" && unzip -q "../$VZ")
    mv "$CACHE/dl/verus-unz"/* "$CACHE/verus"; rmdir "$CACHE/dl/verus-unz"
  fi
  export RUSTUP_HOME=$CACHE/rustup CARGO_HOME=$CACHE/cargo PATH=$CACHE/cargo/bin:$PATH
  printf 'export RUSTUP_HOME=%s CARGO_HOME=%s PATH=%s:%s:$PATH\n' "$RUSTUP_HOME" "$CARGO_HOME" "$CACHE/cargo/bin" "$CACHE/verus" > "$CACHE/verus-env.sh"
  [ -x "$CARGO_HOME/bin/rustup" ] || {
    curl -fsSL -o "$CACHE/dl/rustup-init" https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init
    chmod +x "$CACHE/dl/rustup-init"
    "$CACHE/dl/rustup-init" -y --no-modify-path --default-toolchain none --profile minimal; }
  # the toolchain Verus names, e.g. 1.xx.0-x86_64-unknown-linux-gnu
  TC=$(sed -n 's/.*"toolchain": *"\([^" ]*\).*/\1/p' "$CACHE/verus/version.json" 2>/dev/null || true)
  [ -n "$TC" ] || TC=$("$CACHE/verus/verus" --version 2>&1 | sed -n 's/.*rustup install \([^ ]*\).*/\1/p' | head -1)
  echo "toolchain: $TC"
  "$CARGO_HOME/bin/rustup" toolchain install "$TC" --profile minimal
  "$CACHE/verus/verus" --version
  ;;
onig)
  R=$EXP/repo/upstream
  cmake -S "$R" -B "$EXP/build/onig-debug" -DCMAKE_BUILD_TYPE=Debug > /dev/null
  make -C "$EXP/build/onig-debug" -j"$JOBS" > /dev/null
  cmake -S "$R" -B "$EXP/build/onig-asan" -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_C_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer" \
    -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined" \
    -DCMAKE_SHARED_LINKER_FLAGS="-fsanitize=address,undefined" > /dev/null
  make -C "$EXP/build/onig-asan" -j"$JOBS" > /dev/null
  for b in onig-debug onig-asan; do echo "$b: $("$EXP/build/$b/test/test_utf8" | grep RESULT)"; done
  ;;
*) echo "usage: setup.sh verus|onig" >&2; exit 2;;
esac
