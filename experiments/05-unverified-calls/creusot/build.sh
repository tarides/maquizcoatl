#!/usr/bin/env bash
# build.sh: the Creusot prototype of experiment #5 (run E), under
# run.sh's contract (see ../run.sh).
#
# Steps, each timed in the log:
#   1. copy the crate (Cargo.toml, src/) to VU_OUT/crate; with
#      VU_NEGATIVE_CONTROL=1 the clamp of char_len (between the VU-CLAMP
#      markers) becomes "raw", the callee's raw result; with 2 the bound
#      test of get_subject_byte (between the VU-READ markers) keeps its
#      lower bound only. lib.rs must contain no proof escape (#[trusted],
#      assume, admit); ffi.rs is not seen by Creusot (cfg(not(creusot))).
#   2. cargo creusot --only=coma: Creusot translates the crate to Coma
#      (a failure here is not a proof rejection: exit 1);
#   3. cargo creusot --only=prove: Why3find proves every verification
#      condition with the provers creusot-install set up; a failed proof
#      exits with VU_PROOF_REJECTED;
#   4. rustc (through cargo): the static library (normal run only).
#
# Environment (from run.sh): VU_HARNESS, VU_OUT, VU_NEGATIVE_CONTROL,
# VU_PROOF_REJECTED, VU_JOBS; VU_CACHE, PATH, CARGO_HOME and RUSTUP_HOME
# from <cache>/env.sh.
set -euo pipefail
: "${VU_HARNESS:?}" "${VU_OUT:?}" "${VU_NEGATIVE_CONTROL:?}"
: "${VU_PROOF_REJECTED:?}" "${VU_CACHE:?}"
# shellcheck source=../lib.sh
. "$VU_HARNESS/lib.sh"
here=$VU_HARNESS/creusot
tc=$(vu_pin .creusot.rust)
export CREUSOT_DATA_HOME=$VU_CACHE/creusot/data XDG_CONFIG_HOME=$VU_CACHE/creusot/config
export CARGO_TARGET_DIR=$VU_OUT/target

t0=$(date +%s)
step() { echo "== $* ($(($(date +%s) - t0)) s)"; }

step "versions"
cargo "+$tc" creusot version 2>&1 || cargo-creusot --version
rustc "+$tc" --version
echo "creusot source: $(git -C "$VU_CACHE/creusot/src" rev-parse HEAD)"

step "1. source (negative control: $VU_NEGATIVE_CONTROL)"
crate=$VU_OUT/crate
rm -rf "$crate"
mkdir -p "$crate"
cp -r "$here/Cargo.toml" "$here/src" "$crate/"
[ -f "$here/Cargo.lock" ] && cp "$here/Cargo.lock" "$crate/"
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
if grep -nE '#\[trusted\]|\bassume\b|\badmit\b' "$lib" | grep -vE '^[0-9]+: *//'; then
  echo "lib.rs has a proof escape (#[trusted], assume, admit): refused"
  exit 1
fi
# why3find.json: the one creusot-install wrote, as `cargo creusot init`
# copies it into a new project (provers, time limits, tactics).
cp "$CREUSOT_DATA_HOME/why3find.json" "$crate/why3find.json"
cat "$crate/why3find.json"
cd "$crate"

step "2. cargo creusot --only=coma"
cargo "+$tc" creusot --only=coma 2>&1 | tee coma.log
[ "${PIPESTATUS[0]}" = 0 ] || { echo "Creusot translation failed: not a proof rejection"; exit 1; }
find verif -type f -name '*.coma' | sort | while IFS= read -r f; do
  echo "coma $f: $(wc -l <"$f") lines, sha256 $(vu_sha256 "$f")"
done

step "3. cargo creusot --only=prove"
set +e
cargo "+$tc" creusot --only=prove 2>&1 | tee prove.log
rc=${PIPESTATUS[0]}
set -e
if [ "$rc" != 0 ]; then
  if grep -qiE 'fail|unproved|not proved|timeout' prove.log; then
    echo "proof rejected (status $rc)"
    exit "$VU_PROOF_REJECTED"
  fi
  echo "why3find failed for another reason (status $rc)"
  exit 1
fi
echo "Creusot: every verification condition proved"
[ "$VU_NEGATIVE_CONTROL" != 0 ] && exit 0

step "4. rustc"
cargo "+$tc" rustc --release --lib -j "${VU_JOBS:-4}" -- --print native-static-libs >rustc.log 2>&1 ||
  { cat rustc.log; exit 1; }
cat rustc.log
cp "$CARGO_TARGET_DIR/release/libvu.a" "$VU_OUT/libvu.a"
sed -nE 's/^note: native-static-libs: //p' rustc.log | tail -n 1 >"$VU_OUT/ldflags"
[ -s "$VU_OUT/ldflags" ] || { echo "rustc printed no native-static-libs"; exit 1; }
echo "libvu.a: $(wc -c <"$VU_OUT/libvu.a") bytes"
nm -g --defined-only "$VU_OUT/libvu.a" 2>/dev/null | awk '$3 ~ /^vu_/ { print "exported:", $3 }'
step "done"
