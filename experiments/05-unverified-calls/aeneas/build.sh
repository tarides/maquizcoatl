#!/usr/bin/env bash
# build.sh: Charon + Aeneas prototype of experiment #5, under run.sh's
# contract (see ../run.sh): translates src/lib.rs to Lean, checks the
# proofs of proofs/Proofs.lean against the translation, and compiles the
# same Rust source with rustc into VU_OUT/libvu.a.
#
# Aeneas emits no executable code: the Lean model is a translation of
# the Rust source, and the library that the caller links is that source
# compiled by rustc (the toolchain Charon reads it with), with overflow
# checks on, so that an overflow panics in the library as it fails in
# the model.
#
# Steps, each timed in the log:
#   1. copy src/ and proofs/ to VU_OUT; with VU_NEGATIVE_CONTROL=1,
#      replace the clamp of char_len (the lines between the VU-CLAMP
#      markers of src/lib.rs) by "raw", the callee's raw result; with
#      VU_NEGATIVE_CONTROL=2, replace the bound test of get_subject_byte
#      (between the VU-READ markers) by its lower bound alone;
#   2. Charon: Rust to LLBC, without the C glue (--exclude crate::ffi);
#   3. Aeneas: LLBC to Lean (Vu.lean). Any Aeneas error, or an axiom,
#      sorry or opaque definition in Vu.lean (Aeneas's fallback for what
#      it cannot translate), fails the build;
#   4. Lean, model alone: Vu.lean must check (any error exits with 1);
#   5. Lean, proofs: Vu.lean followed by Proofs.lean. Exits with
#      VU_PROOF_REJECTED when Lean reports an error located in the
#      proofs, a sorry, or a theorem that depends on an axiom other than
#      propext, Classical.choice and Quot.sound; any other failure
#      exits with 1;
#   6. rustc: the static library (normal run only).
#
# Environment (from run.sh): VU_HARNESS, VU_OUT, VU_NEGATIVE_CONTROL,
# VU_PROOF_REJECTED; VU_CACHE and PATH from <cache>/env.sh. VU_JOBS is
# not used: Lean checks one file, and the crate is one compilation unit.

set -euo pipefail
: "${VU_HARNESS:?}" "${VU_OUT:?}" "${VU_NEGATIVE_CONTROL:?}"
: "${VU_PROOF_REJECTED:?}" "${VU_CACHE:?}"
# shellcheck source=../lib.sh
. "$VU_HARNESS/lib.sh"
here=$(pwd)
lean_lib=$VU_CACHE/aeneas/$(vu_pin .aeneas.tag)/lean
toolchain=$(charon toolchain-version)
[ "$toolchain" = "$(vu_pin .charon.rust)" ] ||
  { echo "charon wants $toolchain, pins.json says $(vu_pin .charon.rust)"; exit 1; }
[ -d "$lean_lib/.lake/build/lib" ] ||
  { echo "no built Aeneas Lean library: run setup.sh 2 aeneas-lean"; exit 1; }

t0=$(date +%s)
step() { echo "== $* ($(($(date +%s) - t0)) s)"; }
lean() { (cd "$lean_lib" && lake env lean "$@"); }

step "versions"
echo "charon $(charon version)"
aeneas -version
rustc "+$toolchain" --version
lean --version

step "1. source (negative control: $VU_NEGATIVE_CONTROL)"
rm -rf "$VU_OUT/src" "$VU_OUT/proofs" "$VU_OUT/lean"
cp -r "$here/src" "$here/proofs" "$VU_OUT/"
if [ "$VU_NEGATIVE_CONTROL" = 1 ]; then
  [ "$(grep -c '^ *// VU-CLAMP-\(BEGIN\|END\)$' src/lib.rs)" = 2 ] ||
    { echo "clamp markers not found in src/lib.rs"; exit 1; }
  awk '/^ *\/\/ VU-CLAMP-BEGIN$/ { print "    raw"; skip = 1; next }
       /^ *\/\/ VU-CLAMP-END$/ { skip = 0; next }
       !skip' src/lib.rs >"$VU_OUT/src/lib.rs"
  echo "negative control: clamp removed"
  diff -u --label src/lib.rs --label control/lib.rs src/lib.rs \
    "$VU_OUT/src/lib.rs" | sed 's/^/  /' || true
elif [ "$VU_NEGATIVE_CONTROL" = 2 ]; then
  [ "$(grep -c '^ *// VU-READ-\(BEGIN\|END\)$' src/lib.rs)" = 2 ] ||
    { echo "read markers not found in src/lib.rs"; exit 1; }
  awk '/^ *\/\/ VU-READ-BEGIN$/ { print "    if 0 <= i {"; skip = 1; next }
       /^ *\/\/ VU-READ-END$/ { skip = 0; next }
       !skip' src/lib.rs >"$VU_OUT/src/lib.rs"
  echo "negative control: upper bound test of get_subject_byte removed"
  diff -u --label src/lib.rs --label control-read/lib.rs src/lib.rs \
    "$VU_OUT/src/lib.rs" | sed 's/^/  /' || true
fi
cd "$VU_OUT"
rust_args=(--crate-type=staticlib --crate-name=vu --edition=2021 src/lib.rs)

step "2. Charon"
charon rustc --preset=aeneas --exclude 'crate::ffi' --dest-file vu.llbc \
  -- "${rust_args[@]}" >charon.log 2>&1 || { cat charon.log; exit 1; }
cat charon.log

step "3. Aeneas"
aeneas -backend lean -no-progress-bar -dest lean vu.llbc >aeneas.log 2>&1 ||
  { cat aeneas.log; exit 1; }
cat aeneas.log
if grep -q 'Error' aeneas.log; then
  echo "Aeneas reported an error, refused"
  exit 1
fi
model=lean/Vu.lean
[ -f "$model" ] || { echo "Aeneas wrote no $model"; exit 1; }
if grep -nE '^ *(axiom|opaque)\b|\bsorry\b' "$model"; then
  echo "the model has an axiom, opaque definition or sorry, refused"
  exit 1
fi
echo "model $model: $(wc -l <"$model") lines, sha256 $(vu_sha256 "$model")"

step "4. Lean, model alone"
set +e
lean "$VU_OUT/$model" >model-check.log 2>&1
status=$?
set -e
cat model-check.log
if [ "$status" != 0 ] || grep -q ': error' model-check.log; then
  echo "the model does not check (status $status)"
  exit 1
fi

step "5. Lean, proofs"
n=$(wc -l <"$model")
cat "$model" proofs/Proofs.lean >VuProofs.lean
set +e
lean "$VU_OUT/VuProofs.lean" >proofs-check.log 2>&1
status=$?
set -e
# Error positions are shown relative to Proofs.lean ("Proofs.lean:L:C").
awk -v n="$n" -F: 'BEGIN { OFS = ":" }
  $1 ~ /VuProofs\.lean$/ && $2 ~ /^[0-9]+$/ && $2 > n {
    $1 = "Proofs.lean"; $2 = $2 - n }
  { print }' proofs-check.log
errors_model=$(awk -v n="$n" -F: '$1 ~ /VuProofs\.lean$/ && $3 ~ /^[0-9]+$/ &&
  $0 ~ /: error/ && $2 <= n' proofs-check.log | wc -l)
errors_proofs=$(awk -v n="$n" -F: '$1 ~ /VuProofs\.lean$/ && $3 ~ /^[0-9]+$/ &&
  $0 ~ /: error/ && $2 > n' proofs-check.log | wc -l)
# One report per "#print axioms" line; any subset of Lean's standard
# axioms is accepted.
reports=$(grep -E "^'[^']+' (depends on axioms: \[.*\]|does not depend on any axioms)$" \
  proofs-check.log || true)
axioms=$(printf '%s\n' "$reports" | grep -c . || true)
bad_axioms=$(printf '%s\n' "$reports" |
  sed -n 's/.*depends on axioms: \[\(.*\)\]$/\1/p' | tr ',' '\n' |
  sed 's/^ *//' | grep -cvxE 'propext|Classical\.choice|Quot\.sound' || true)
theorems=$(grep -c '^#print axioms ' proofs/Proofs.lean)
echo "proofs: status=$status errors_in_model=$errors_model" \
  "errors_in_proofs=$errors_proofs theorems=$theorems" \
  "axiom_reports=$axioms nonstandard_axioms=$bad_axioms"
if [ "$errors_model" != 0 ]; then
  echo "error inside the model part of VuProofs.lean, not a proof rejection"
  exit 1
fi
if [ "$errors_proofs" != 0 ] || [ "$bad_axioms" != 0 ] ||
  grep -q "declaration uses 'sorry'\|declaration uses \`sorry\`" proofs-check.log; then
  echo "proof rejected"
  exit "$VU_PROOF_REJECTED"
fi
if [ "$status" != 0 ] || [ "$axioms" != "$theorems" ]; then
  echo "Lean failed (status $status, $axioms of $theorems axiom reports)"
  exit 1
fi
echo "proofs: all $theorems theorems checked, standard axioms only"
[ "$VU_NEGATIVE_CONTROL" != 0 ] && exit 0

step "6. rustc"
rustc "+$toolchain" "${rust_args[@]}" -C opt-level=2 -C overflow-checks=on \
  -o libvu.a --print native-static-libs >rustc.log 2>&1 ||
  { cat rustc.log; exit 1; }
cat rustc.log
sed -nE 's/^note: native-static-libs: //p' rustc.log | tail -n 1 >ldflags
[ -s ldflags ] || { echo "rustc printed no native-static-libs"; exit 1; }
echo "ldflags: $(cat ldflags)"
echo "libvu.a: $(wc -c <libvu.a) bytes, sha256 $(vu_sha256 libvu.a)"
nm -g --defined-only libvu.a 2>/dev/null | awk '$3 ~ /^vu_/ { print "exported:", $3 }'
step "done"
