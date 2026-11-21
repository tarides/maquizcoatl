#!/usr/bin/env bash
# build.sh BACKEND: the hax prototype of experiment #5, under run.sh's
# contract (see ../run.sh), for one hax backend (fstar or rocq). It is
# called by ../hax-fstar/build.sh and ../hax-rocq/build.sh, which are
# run.sh's tools: each backend has its own verdict.
#
# Steps, each timed in the log:
#   1. copy the crate (Cargo.toml, Cargo.lock, src/, and for rocq the
#      proofs of ../hax-rocq) to VU_OUT/crate; with VU_NEGATIVE_CONTROL=1,
#      replace the clamp of char_len (between the VU-CLAMP markers of
#      src/lib.rs) by "raw", the callee's raw result; with
#      VU_NEGATIVE_CONTROL=2, replace the bound test of get_subject_byte
#      (between the VU-READ markers) by its lower bound alone;
#   2. hax: cargo hax into BACKEND, without the C glue
#      (-i '-vu::ffi::**'). Any hax error fails the build, and so does an
#      admit, assume, sorry or Admitted in the extracted files;
#   3. the proof check:
#      fstar: F* checks the extracted modules, whose specifications are
#        the requires/ensures of src/lib.rs. Failed proof obligations
#        only (F* error 19) exit with VU_PROOF_REJECTED, anything else
#        with 1;
#      rocq: the hax Rocq library (Core) is built once, then the
#        extracted model and ../hax-rocq/Proofs.v are checked with rocq
#        (coqc). An error located in Proofs.v exits with
#        VU_PROOF_REJECTED, as does any axiom other than the standard
#        ones reported by Print Assumptions; an error in the model or
#        the library exits with 1;
#   4. rustc (through cargo): the static library (normal run only).
#
# Environment (from run.sh): VU_HARNESS, VU_OUT, VU_NEGATIVE_CONTROL,
# VU_PROOF_REJECTED, VU_JOBS, VU_EXP; VU_CACHE, PATH, OPAMROOT and the
# rest from <cache>/env.sh.

set -euo pipefail
backend=${1:?usage: build.sh fstar|rocq}
: "${VU_HARNESS:?}" "${VU_OUT:?}" "${VU_NEGATIVE_CONTROL:?}"
: "${VU_PROOF_REJECTED:?}" "${VU_CACHE:?}" "${VU_EXP:?}"
# shellcheck source=../lib.sh
. "$VU_HARNESS/lib.sh"
here=$VU_HARNESS/hax
tc=$(vu_pin .hax.rust)
hax_home=$VU_CACHE/hax/$(vu_pin .hax.version)
export OPAMROOT=$VU_OWN_OPAMROOT OPAMCOLOR=never
# hax-engine is in the opam switch hax; cargo-hax and hax-driver in
# hax_home/bin.
PATH="$hax_home/bin:$(opam var --switch hax bin):$PATH"
export PATH CARGO_TARGET_DIR=$VU_OUT/target
# cargo fetches hax-lib from crates.io into CARGO_HOME (the cache's).

t0=$(date +%s)
step() { echo "== $* ($(($(date +%s) - t0)) s)"; }

step "versions"
cargo "+$tc" hax --version
rustc "+$tc" --version
echo "hax source: $(git -C "$hax_home/src" rev-parse HEAD)"

step "1. source (backend $backend, negative control: $VU_NEGATIVE_CONTROL)"
crate=$VU_OUT/crate
rm -rf "$crate"
mkdir -p "$crate"
cp -r "$here/Cargo.toml" "$here/Cargo.lock" "$here/src" "$crate/"
lib=$crate/src/lib.rs
if [ "$VU_NEGATIVE_CONTROL" = 1 ]; then
  [ "$(grep -c '^ *// VU-CLAMP-\(BEGIN\|END\)$' "$here/src/lib.rs")" = 2 ] ||
    { echo "clamp markers not found in src/lib.rs"; exit 1; }
  awk '/^ *\/\/ VU-CLAMP-BEGIN$/ { print "    raw"; skip = 1; next }
       /^ *\/\/ VU-CLAMP-END$/ { skip = 0; next }
       !skip' "$here/src/lib.rs" >"$lib"
  echo "negative control: clamp removed"
  diff -u --label src/lib.rs --label control/lib.rs "$here/src/lib.rs" "$lib" |
    sed 's/^/  /' || true
elif [ "$VU_NEGATIVE_CONTROL" = 2 ]; then
  [ "$(grep -c '^ *// VU-READ-\(BEGIN\|END\)$' "$here/src/lib.rs")" = 2 ] ||
    { echo "read markers not found in src/lib.rs"; exit 1; }
  awk '/^ *\/\/ VU-READ-BEGIN$/ { print "    if 0 <= i {"; skip = 1; next }
       /^ *\/\/ VU-READ-END$/ { skip = 0; next }
       !skip' "$here/src/lib.rs" >"$lib"
  echo "negative control: upper bound test of get_subject_byte removed"
  diff -u --label src/lib.rs --label control-read/lib.rs "$here/src/lib.rs" "$lib" |
    sed 's/^/  /' || true
fi
cd "$crate"

case "$backend" in
fstar) into=fstar; ext=proofs/fstar/extraction ;;
rocq) into=coq; ext=proofs/coq/extraction ;;
*) echo "unknown backend $backend"; exit 1 ;;
esac

step "2. hax into $into"
set +e
cargo "+$tc" hax into -i '-vu::ffi::**' "$into" >hax.log 2>&1
status=$?
set -e
cat hax.log
[ "$status" = 0 ] || { echo "hax failed (status $status)"; exit 1; }
[ -d "$ext" ] || { echo "hax wrote no $ext"; exit 1; }
find "$ext" -type f | sort | while IFS= read -r f; do
  echo "extracted $f: $(wc -l <"$f") lines, sha256 $(vu_sha256 "$f")"
done
# The Rocq backend states each ensures clause as a lemma ending with
# "Admitted" (a proof obligation): Admitted is refused only in F*'s
# output, and checked against Proofs.v for Rocq.
esc='\b(admit|admit_smt_queries|assume|magic|sorry|Axiom|Parameter)\b'
[ "$backend" = fstar ] && esc='\b(admit|admit_smt_queries|assume|magic|sorry|Admitted|Axiom|Parameter)\b'
if grep -rnE "$esc" "$ext"; then
  echo "the extraction has an escape (admit, assume, sorry, Admitted, Axiom, Parameter), refused"
  exit 1
fi

if [ "$backend" = fstar ]; then
  step "3. F*"
  # F*: <cache>/fstar (milestone 1's) unless VU_HAX_FSTAR names another
  # F* root; the plan tries the cache's first, else hax's pin.
  fstar_home=${VU_HAX_FSTAR:-$VU_FSTAR_HOME}
  fstar=$fstar_home/bin/fstar.exe
  "$fstar" --version
  # Include directories as hax's F* Makefiles compute them: hax's
  # proof-libs, and the proofs/fstar/extraction directory of every
  # crate dependency (hax-lib's F* library).
  incs=("$hax_home/src/hax-lib/proof-libs/fstar/rust_primitives"
    "$hax_home/src/hax-lib/proof-libs/fstar/core")
  while IFS= read -r d; do
    [ -d "$d/proofs/fstar/extraction" ] && incs+=("$d/proofs/fstar/extraction")
  done < <(cargo "+$tc" metadata --format-version 1 |
    jq -r '.packages[].manifest_path | split("/") | .[:-1] | join("/")' | sort -u)
  printf 'include %s\n' "${incs[@]}"
  # The checked files of the libraries are cached per F* version, under
  # <exp>; the prototype's own modules are always rechecked.
  # (F* 2025.10.06 prints "F* 2025.10.06", 2026.11.15 "F* version: ...":
  # both are read since run E, which found the cache directory unnamed.)
  cache=$VU_EXP/build/hax-fstar-cache/$("$fstar" --version | head -n 1 | sed 's/^F\* *//; s/^version: *//' | tr -c 'A-Za-z0-9.\n' _)
  mkdir -p "$cache"
  # hax's flags (examples/hax.fst.config.json), except --cmi when this F*
  # does not know it (F* 2026.11.15's --help does not list it). The log
  # says which, and prints the command line below.
  flags=()
  if "$fstar" --help 2>/dev/null | grep -q -- '--cmi'; then
    flags+=(--cmi)
  else
    echo "flag --cmi dropped: not listed by this F*'s --help"
  fi
  flags+=(--warn_error -331 --cache_checked_modules --cache_dir "$cache"
    --already_cached "+Prims+FStar+LowStar+C+Spec.Loops+TestLib")
  for d in "${incs[@]}"; do flags+=(--include "$d"); done
  flags+=(--include "$ext")
  set +e
  for m in $(cd "$ext" && ls ./*.fst ./*.fsti 2>/dev/null | sed 's#^\./##'); do
    echo "-- $m"
    echo "fstar.exe ${flags[*]} $ext/$m" | vu_redact
    rm -f "$cache/$m.checked"
    "$fstar" "${flags[@]}" "$ext/$m"
    rc=$?
    echo "status $m: $rc"
    [ "$rc" = 0 ] || break
  done 2>&1 | tee check.log
  set -e
  if grep -q '^status .*: [1-9]' check.log; then
    codes=$(sed -n 's/^.*Error \([0-9]*\) .*/\1/p' check.log | sort -u | tr '\n' ' ')
    echo "F* error codes: $codes"
    if [ "$codes" = "19 " ]; then
      echo "proof rejected (F* error 19 only)"
      exit "$VU_PROOF_REJECTED"
    fi
    echo "F* failed for another reason than a rejected proof obligation"
    exit 1
  fi
  echo "F*: all modules checked"
else
  step "3. Rocq"
  # Rocq 9.3 of the switch provers (experiment #7's, not altered). The
  # extraction needs hax's Rocq library Core (proof-libs/coq/coq/
  # generated-core at the tag) and RecordUpdate (coq-record-update, tag
  # in pins.json), neither of which is in provers: both are built once
  # with that Rocq into <exp>/build/hax-rocq-libs, not installed.
  rocq_bin=$VU_SHARED_CACHE/opam/provers/bin
  PATH="$rocq_bin:$PATH"
  rocq --version
  libs=$VU_EXP/build/hax-rocq-libs
  ru=$libs/record-update
  core=$libs/core
  if [ ! -f "$ru/src/RecordUpdate.vo" ]; then
    rm -rf "$ru"
    git clone -q -c advice.detachedHead=false --depth 1 \
      --branch "$(vu_pin .hax.rocq_record_update.tag)" \
      "$(vu_pin .hax.rocq_record_update.repository)" "$ru"
    [ "$(git -C "$ru" rev-parse HEAD)" = "$(vu_pin .hax.rocq_record_update.commit)" ] ||
      { echo "coq-record-update is not at the pinned commit"; exit 1; }
    (cd "$ru" && rocq makefile -f _CoqProject -o Makefile.rocq &&
      make -f Makefile.rocq -j "${VU_JOBS:-4}") >"$libs-record-update.log" 2>&1 ||
      { cat "$libs-record-update.log"; echo "RecordUpdate does not build"; exit 1; }
  fi
  echo "RecordUpdate: $(git -C "$ru" rev-parse HEAD)"
  if [ ! -f "$core/src/Core.vo" ]; then
    rm -rf "$core"
    cp -r "$hax_home/src/hax-lib/proof-libs/coq/coq/generated-core" "$core"
    (cd "$core" && { echo "-Q $ru/src RecordUpdate"; cat _CoqProject; } >_CoqProject.vu &&
      rocq makefile -f _CoqProject.vu -o Makefile.rocq &&
      make -f Makefile.rocq -j "${VU_JOBS:-4}") >"$libs-core.log" 2>&1 ||
      { cat "$libs-core.log"; echo "hax's Core library does not build"; exit 1; }
  fi
  echo "Core: $(find "$core" -name '*.vo' | wc -l) compiled files"
  model=$crate/$ext/Vu.v
  set +e
  (cd "$crate/$ext" && rocq compile -w none -Q "$ru/src" RecordUpdate \
    -R "$core/src" Core -R "$core/spec" Core -R "$core/phase_library" Core Vu.v) \
    >model-check.log 2>&1
  status=$?
  set -e
  cat model-check.log
  # The ensures lemmas hax emits end with "Proof. Admitted.": they are
  # the proof obligations, to be proved in ../hax-rocq/Proofs.v once the
  # model checks.
  echo "ensures lemmas emitted as Admitted: $(grep -c 'Admitted' "$model")"
  if [ "$status" != 0 ]; then
    echo "the extracted model does not check (status $status): not a proof rejection"
    exit 1
  fi
  echo "the model checks; Proofs.v is not written yet"
  exit 1
fi
[ "$VU_NEGATIVE_CONTROL" != 0 ] && exit 0

step "4. rustc"
cargo "+$tc" rustc --release --lib -j "${VU_JOBS:-4}" -- --print native-static-libs >rustc.log 2>&1 ||
  { cat rustc.log; exit 1; }
cat rustc.log
cp "$CARGO_TARGET_DIR/release/libvu.a" "$VU_OUT/libvu.a"
sed -nE 's/^note: native-static-libs: //p' rustc.log | tail -n 1 >"$VU_OUT/ldflags"
[ -s "$VU_OUT/ldflags" ] || { echo "rustc printed no native-static-libs"; exit 1; }
echo "ldflags: $(cat "$VU_OUT/ldflags")"
echo "libvu.a: $(wc -c <"$VU_OUT/libvu.a") bytes"
nm -g --defined-only "$VU_OUT/libvu.a" 2>/dev/null | awk '$3 ~ /^vu_/ { print "exported:", $3 }'
step "done"
