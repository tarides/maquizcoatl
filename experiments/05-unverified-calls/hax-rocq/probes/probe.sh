#!/usr/bin/env bash
# probe.sh WORKDIR: extracts each probe crate (struct, cmp) with hax's
# Rocq backend and checks the output with Rocq 9.3 (switch provers),
# against hax's Core library and RecordUpdate as built by
# ../../hax/build.sh rocq in <exp>/build/hax-rocq-libs (run it first).
# Run C of experiment #5: it separates the backend's defects from the
# prototype. Environment: VU_CACHE (its env.sh is sourced), VU_EXP.
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/../../lib.sh"
: "${VU_CACHE:?}" "${VU_EXP:?}"
. "$VU_CACHE/env.sh"
export OPAMROOT=$VU_OWN_OPAMROOT OPAMCOLOR=never
tc=$(vu_pin .hax.rust)
hax_home=$VU_CACHE/hax/$(vu_pin .hax.version)
PATH="$hax_home/bin:$(opam var --switch hax bin):$VU_SHARED_CACHE/opam/provers/bin:$PATH"
libs=$VU_EXP/build/hax-rocq-libs
[ -f "$libs/core/src/Core.vo" ] || { echo "no built Core: run hax-rocq first"; exit 1; }
w=$(mkdir -p "$1" && cd "$1" && pwd)
export CARGO_TARGET_DIR=$w/target
for p in struct cmp; do
  d=$w/$p
  rm -rf "$d"
  mkdir -p "$d"
  cp -r "$here/$p/src" "$d/"
  printf '[package]\nname = "probe_%s"\nversion = "0.1.0"\nedition = "2021"\n[dependencies]\nhax-lib = "=%s"\n' \
    "$p" "$(vu_pin .hax.hax_lib)" >"$d/Cargo.toml"
  echo "== probe $p: src/lib.rs sha256 $(vu_sha256 "$here/$p/src/lib.rs")"
  (cd "$d" && cargo "+$tc" hax into coq 2>&1 | grep -v '^ *Compiling\|^ *Checking\|^ *Locking\|^ *Updating\|^ *Adding\|^ *Downloaded\|^ *Downloading')
  f=$(ls "$d"/proofs/coq/extraction/*.v)
  echo "-- extracted $(basename "$f"):"
  sed -n '/NotImplementedYet/,$p' "$f"
  echo "-- rocq compile:"
  (cd "$(dirname "$f")" && rocq compile -w none -Q "$libs/record-update/src" RecordUpdate \
    -R "$libs/core/src" Core -R "$libs/core/spec" Core -R "$libs/core/phase_library" Core \
    "$(basename "$f")" 2>&1)
  echo "probe $p: rocq status=$?"
done 2>&1 | vu_redact
