#!/usr/bin/env bash
# build.sh: checks and builds the Verus prototype (contract in ../run.sh).
#
# Copies src/ into VU_OUT/src (with the clamp of char_len replaced by
# the callee's raw result when VU_NEGATIVE_CONTROL=1), verifies it with
# Verus and, for a normal run, compiles it in the same Verus run into
# the static library VU_OUT/libvu.a. VU_OUT/ldflags gets the native
# libraries the Rust standard library needs, as rustc prints them.
#
# Exit status: 0 when verified and built; VU_PROOF_REJECTED when Verus
# reports verification errors; 1 for anything else.

set -euo pipefail
: "${VU_OUT:?}" "${VU_JOBS:?}" "${VU_PROOF_REJECTED:?}"
control=${VU_NEGATIVE_CONTROL:-0}

command -v verus >/dev/null || { echo "build.sh: no verus on PATH" >&2; exit 1; }
verus --version

rm -rf "$VU_OUT/src"
mkdir -p "$VU_OUT/src"
cp src/*.rs "$VU_OUT/src/"
if [ "$control" = 1 ]; then
  # The clamp is the block between the VU-CLAMP markers; without it,
  # char_len returns the callee's result as it is.
  awk '/^ *\/\/ VU-CLAMP-BEGIN$/ { print "    raw"; skip = 1; next }
       /^ *\/\/ VU-CLAMP-END$/ { skip = 0; next }
       !skip' src/lib.rs >"$VU_OUT/src/lib.rs"
  if cmp -s src/lib.rs "$VU_OUT/src/lib.rs"; then
    echo "build.sh: no clamp markers in src/lib.rs" >&2
    exit 1
  fi
  echo "negative control: clamp removed"
  diff -u --label src/lib.rs --label control/lib.rs src/lib.rs "$VU_OUT/src/lib.rs" | sed 's/^/  /' || true
fi

args=(--num-threads "$VU_JOBS" --time --crate-type=staticlib --crate-name=vu
  --edition=2021 "$VU_OUT/src/lib.rs")
if [ "$control" = 0 ]; then
  args+=(--compile -o "$VU_OUT/libvu.a" --print "native-static-libs")
fi

set +e
verus "${args[@]}" >"$VU_OUT/verus.log" 2>&1
status=$?
set -e
cat "$VU_OUT/verus.log"

# "verification results:: N verified, M errors"
results=$(grep -E '^verification results:: [0-9]+ verified, [0-9]+ errors' \
  "$VU_OUT/verus.log" | tail -n 1 || true)
errors=$(printf '%s\n' "$results" | sed -nE 's/.* ([0-9]+) errors.*/\1/p')
if [ -n "$errors" ] && [ "$errors" -gt 0 ]; then
  echo "build.sh: Verus rejected the proof ($results)"
  exit "$VU_PROOF_REJECTED"
fi
if [ "$status" != 0 ] || [ -z "$results" ]; then
  echo "build.sh: Verus failed (status $status) without a proof rejection" >&2
  exit 1
fi
[ "$control" = 1 ] && exit 0

[ -f "$VU_OUT/libvu.a" ] || { echo "build.sh: no libvu.a" >&2; exit 1; }
sed -nE 's/^note: native-static-libs: //p' "$VU_OUT/verus.log" | tail -n 1 \
  >"$VU_OUT/ldflags"
[ -s "$VU_OUT/ldflags" ] || { echo "build.sh: rustc printed no native-static-libs" >&2; exit 1; }
echo "ldflags: $(cat "$VU_OUT/ldflags")"
echo "libvu.a: $(wc -c <"$VU_OUT/libvu.a") bytes, sha256 $(sha256sum "$VU_OUT/libvu.a" | cut -d' ' -f1)"
