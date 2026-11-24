#!/usr/bin/env bash
# warn.sh: reproduces the Aeneas warning "extracted external, unknown
# definitions" on a one-function crate. imax/ reads i32::MAX, which
# Aeneas maps to core.num.I32.MAX of its Lean library, and gets the
# warning although nothing external is left in the model; plain/ reads
# no global and does not get it. Aeneas sets the flag behind the warning
# in export_global (src/Translate.ml:1007 at 8f4466d) before its check
# for a library definition (:1009-1012); src/Main.ml:777-782 prints the
# warning from that flag unless -split-files is given.
#
# Usage: warn.sh WORKDIR (an empty or absent directory). Needs charon,
# aeneas and the pinned Rust toolchain on PATH (<cache>/env.sh).
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
w=$1
mkdir -p "$w"
echo "charon $(charon version)"
aeneas -version
for c in plain imax; do
  echo "== $c: $(cat "$here/$c/src/lib.rs")"
  rm -rf "${w:?}/$c"
  cp -r "$here/$c" "$w/$c"
  (cd "$w/$c" &&
    charon rustc --preset=aeneas --dest-file x.llbc -- \
      --crate-type=lib --crate-name="$c" --edition=2021 src/lib.rs 2>&1 &&
    echo "-- aeneas -backend lean" &&
    aeneas -backend lean -no-progress-bar -dest lean x.llbc 2>&1 &&
    echo "-- aeneas -backend lean -split-files" &&
    aeneas -backend lean -no-progress-bar -split-files -dest split x.llbc 2>&1 &&
    echo "files: $(cd lean && ls) | split: $(cd split && ls)" &&
    echo "axiom/opaque/sorry in the model: $(cat lean/*.lean | grep -cE '^ *(axiom|opaque)\b|\bsorry\b' || true)")
done
