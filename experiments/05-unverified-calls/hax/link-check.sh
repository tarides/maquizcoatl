#!/usr/bin/env bash
# link-check.sh OUTDIR: builds the hax prototype's library with rustc
# (the Rust toolchain hax pins, overflow checks on, as build.sh's step 4)
# and links it with caller/caller.c, whose output must equal
# caller/expected.txt. No proof is checked here: in run C neither
# backend's proof check could run (see the notebook entry), so this
# shows only that the prototype's C ABI, re-entrancy shapes (a) and (b)
# included, behaves as expected. Environment: VU_CACHE (its env.sh is
# sourced).
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/../lib.sh"
: "${VU_CACHE:?}"
. "$VU_CACHE/env.sh"
out=$(mkdir -p "$1" && cd "$1" && pwd)
tc=$(vu_pin .hax.rust)
{
  echo "== sources (sha256)"
  (cd "$here/.." && sha256sum hax/Cargo.toml hax/Cargo.lock hax/src/lib.rs hax/src/ffi.rs \
    hax/link-check.sh caller/caller.c caller/expected.txt proto.h)
  rustc "+$tc" --version
  rm -rf "$out/crate"
  mkdir -p "$out/crate"
  cp -r "$here/Cargo.toml" "$here/Cargo.lock" "$here/src" "$out/crate/"
  (cd "$out/crate" && CARGO_TARGET_DIR=$out/target cargo "+$tc" rustc --release --lib \
    -- --print native-static-libs) >"$out/rustc.log" 2>&1 || { cat "$out/rustc.log"; exit 1; }
  ldflags=$(sed -nE 's/^note: native-static-libs: //p' "$out/rustc.log" | tail -n 1)
  echo "ldflags: $ldflags"
  # shellcheck disable=SC2086
  cc -std=c11 -Wall -Wextra -Werror -I"$here/.." "$here/../caller/caller.c" \
    "$out/target/release/libvu.a" $ldflags -o "$out/caller"
  nm -g --defined-only "$out/target/release/libvu.a" 2>/dev/null |
    awk '$3 ~ /^vu_/ { print "exported:", $3 }'
  "$out/caller" >"$out/caller.out"
  echo "caller status: $?"
  if diff -u --label expected.txt --label caller.out "$here/../caller/expected.txt" "$out/caller.out"; then
    echo "caller_output=same"
  else
    echo "caller_output=DIFFERENT"; exit 1
  fi
} 2>&1 | vu_redact
