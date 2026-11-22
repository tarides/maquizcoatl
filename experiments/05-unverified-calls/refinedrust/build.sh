#!/usr/bin/env bash
# build.sh: the RefinedRust prototype of experiment #5 (run F), under
# run.sh's contract (see ../run.sh).
#
# Steps, each timed in the log:
#   1. copy the crate (Cargo.toml, RefinedRust.toml, src/, proofs/) to
#      VU_OUT/crate; with VU_NEGATIVE_CONTROL=1 the clamp of char_len
#      (between the VU-CLAMP markers) becomes "raw", the callee's raw
#      result; with 2 the bound test of get_subject_byte (between the
#      VU-READ markers) keeps its lower bound only. src/lib.rs must
#      contain no proof escape (#[rr::trust_me], #[rr::only_spec],
#      #[rr::skip], #[rr::shim], #[rr::code_shim]), and proofs/ no
#      Admitted, admit or Axiom; src/ffi.rs is the trusted glue, every
#      item #[rr::skip];
#   2. cargo refinedrust: the frontend translates the crate to Rocq
#      (code, specifications, proof templates) under output/ (a failure
#      here is not a proof rejection: exit 1);
#   3. the manual proofs of proofs/ replace their generated templates
#      (RefinedRust keeps a proof file once it exists; the case studies
#      of its repository work the same way), and the generated files are
#      checked for Admitted;
#   4. dune build: Rocq checks every proof; a proof that RefinedRust's
#      automation leaves stuck or with an open side condition exits with
#      VU_PROOF_REJECTED;
#   5. rustc (through cargo, the frontend's nightly): the static library
#      (normal run only).
#
# Environment (from run.sh): VU_HARNESS, VU_OUT, VU_NEGATIVE_CONTROL,
# VU_PROOF_REJECTED, VU_JOBS; VU_CACHE, PATH, CARGO_HOME and RUSTUP_HOME
# from <cache>/env.sh; the opam root VU_OWN_OPAMROOT, switch refinedrust.
set -euo pipefail
: "${VU_HARNESS:?}" "${VU_OUT:?}" "${VU_NEGATIVE_CONTROL:?}"
: "${VU_PROOF_REJECTED:?}" "${VU_CACHE:?}" "${VU_OWN_OPAMROOT:?}"
# shellcheck source=../lib.sh
. "$VU_HARNESS/lib.sh"
here=$VU_HARNESS/refinedrust
export OPAMROOT=$VU_OWN_OPAMROOT OPAMSWITCH=refinedrust
src=$VU_CACHE/refinedrust/src
tc=$(sed -n 's/^channel = "\(.*\)"/\1/p' "$src/rr_frontend/rust-toolchain.toml")
export CARGO_TARGET_DIR=$VU_OUT/target

t0=$(date +%s)
step() { echo "== $* ($(($(date +%s) - t0)) s)"; }

step "versions"
echo "refinedrust source: $(git -C "$src" rev-parse HEAD), frontend toolchain $tc"
rustc "+$tc" --version
opam exec -- rocq --version 2>/dev/null | head -n 1 || opam exec -- coqc --version | head -n 1
opam list --installed --short refinedrust refinedrust-stdlib rocq-iris rocq-stdpp 2>/dev/null | tr '\n' ' '
echo

step "1. source (negative control: $VU_NEGATIVE_CONTROL)"
crate=$VU_OUT/crate
rm -rf "$crate"
mkdir -p "$crate"
cp -r "$here/Cargo.toml" "$here/RefinedRust.toml" "$here/src" "$here/proofs" "$crate/"
lib=$crate/src/lib.rs
if [ "$VU_NEGATIVE_CONTROL" = 1 ]; then
  [ "$(grep -c '^ *// VU-CLAMP-\(BEGIN\|END\)$' "$here/src/lib.rs")" = 2 ] ||
    { echo "clamp markers not found in src/lib.rs"; exit 1; }
  awk '/^ *\/\/ VU-CLAMP-BEGIN$/ { print "    raw"; skip = 1; next }
       /^ *\/\/ VU-CLAMP-END$/ { skip = 0; next }
       !skip' "$here/src/lib.rs" >"$lib"
  echo "negative control: clamp removed"
  diff -u --label src/lib.rs --label control/lib.rs "$here/src/lib.rs" "$lib" | sed 's/^/  /' || true
elif [ "$VU_NEGATIVE_CONTROL" = 2 ]; then
  [ "$(grep -c '^ *// VU-READ-\(BEGIN\|END\)$' "$here/src/lib.rs")" = 2 ] ||
    { echo "read markers not found in src/lib.rs"; exit 1; }
  awk '/^ *\/\/ VU-READ-BEGIN$/ { print "    if 0 <= i {"; skip = 1; next }
       /^ *\/\/ VU-READ-END$/ { skip = 0; next }
       !skip' "$here/src/lib.rs" >"$lib"
  echo "negative control: upper bound test of get_subject_byte removed"
  diff -u --label src/lib.rs --label control-read/lib.rs "$here/src/lib.rs" "$lib" | sed 's/^/  /' || true
fi
if grep -nE 'rr::(trust_me|only_spec|skip|shim|code_shim)' "$lib" | grep -vE '^[0-9]+: *//'; then
  echo "src/lib.rs has a proof escape (trust_me, only_spec, skip, shim): refused"
  exit 1
fi
if grep -nE '\b(Admitted|admit|Axiom)\b' "$crate"/proofs/*.v | grep -vE '^[^:]+:[0-9]+: *\(\*'; then
  echo "proofs/ has Admitted, admit or Axiom: refused"
  exit 1
fi
cd "$crate"

step "2. cargo refinedrust"
opam exec -- cargo "+$tc" refinedrust 2>&1 | grep -v '^ *\(Compiling\|Checking\)' | tee translate.log
[ "${PIPESTATUS[0]}" = 0 ] || { echo "RefinedRust translation failed: not a proof rejection"; exit 1; }

step "3. manual proofs"
pdir=output/vu/proofs
[ -d "$pdir" ] || { echo "no $pdir after the translation"; exit 1; }
for f in proofs/*.v; do
  [ -f "$pdir/$(basename "$f")" ] || { echo "$f has no generated template"; exit 1; }
  cp "$f" "$pdir/"
  echo "manual proof: $(basename "$f") sha256 $(vu_sha256 "$f")"
done
if grep -rnE '\b(Admitted|admit)\b' output/vu --include='*.v'; then
  echo "a generated file has Admitted or admit: refused"
  exit 1
fi
find output/vu -name '*.v' | sort | while IFS= read -r f; do
  echo "rocq $f: $(wc -l <"$f") lines, sha256 $(vu_sha256 "$f")"
done

step "4. dune build"
set +e
(cd output && opam exec -- dune build -j "${VU_JOBS:-4}" --display short) >dune.log 2>&1
rc=$?
set -e
grep -vE '^H[0-9]+ : \((Min|Max|127|2 \*|32)' dune.log | tail -n 300
if [ "$rc" != 0 ]; then
  if grep -qE 'Tactic failure|Attempt to save an incomplete proof|Type system got stuck|Shelved goal remaining|Cannot solve' dune.log; then
    echo "proof rejected (status $rc)"
    exit "$VU_PROOF_REJECTED"
  fi
  echo "dune failed for another reason (status $rc)"
  exit 1
fi
for f in "$pdir"/*.v; do
  vo=output/_build/default/vu/proofs/$(basename "${f%.v}").vo
  [ -f "$vo" ] || { echo "missing $vo"; exit 1; }
done
echo "RefinedRust: every proof checked ($(ls "$pdir"/*.v | wc -l) files)"
[ "$VU_NEGATIVE_CONTROL" != 0 ] && exit 0

step "5. rustc"
cargo "+$tc" rustc --release --lib -j "${VU_JOBS:-4}" -- --print native-static-libs >rustc.log 2>&1 ||
  { cat rustc.log; exit 1; }
cat rustc.log
cp "$CARGO_TARGET_DIR/release/libvu.a" "$VU_OUT/libvu.a"
sed -nE 's/^note: native-static-libs: //p' rustc.log | tail -n 1 >"$VU_OUT/ldflags"
[ -s "$VU_OUT/ldflags" ] || { echo "rustc printed no native-static-libs"; exit 1; }
echo "libvu.a: $(wc -c <"$VU_OUT/libvu.a") bytes"
nm -g --defined-only "$VU_OUT/libvu.a" 2>/dev/null | awk '$3 ~ /^vu_/ { print "exported:", $3 }'
step "done"
