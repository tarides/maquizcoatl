#!/usr/bin/env bash
# miri.sh: runs client.rs against the Verus and Aeneas prototypes under
# Miri (experiment #5, run B). For each tool, a cargo project in
# WORKDIR/<tool> holds the prototype's Rust sources as the library
# "vu" (Aeneas: src/lib.rs and src/ffi.rs as they are; Verus: lib.rs,
# shim.rs and ffi.rs erased to plain Rust by erase_verus.py, since
# Verus's own erasure needs its rustc) and client.rs as a binary. Each
# runs under Stacked Borrows (Miri's default) and Tree Borrows.
#
# Run C added hax (milestone 3): its src/lib.rs and src/ffi.rs as they
# are, with the hax-lib crate (pins.json) as a dependency for its
# specification attributes; hax's vu_args holds the subject as a usize
# address, so client.rs is used with SUBJECT.as_ptr() replaced by
# SUBJECT.as_ptr().expose_provenance() (a sed, printed in the log).
#
# Run E added creusot: its src/lib.rs and src/ffi.rs as they are, with
# creusot-std (=0.14.0) as a dependency for its contract attributes
# (erased outside cfg(creusot)); its vu_args holds the subject as a raw
# pointer, as Aeneas's, so client.rs is used unchanged.
#
# Run F added refinedrust: its src/lib.rs and src/ffi.rs as they are
# (the rr attributes are a registered tool, no dependency); its
# vu_args and vu_fold_rec spell the arrays slot[5] and from[8] as one
# field per element, so client.rs is used with the array accesses
# rewritten to the fields (a sed, printed in the log).
#
# Usage: miri.sh WORKDIR. Environment: VU_CACHE (its env.sh is
# sourced), VU_MIRI_TOOLCHAIN (default: the Charon nightly of
# pins.json, which has the miri component), VU_MIRI_TOOLS (default
# "aeneas verus"; run C: "hax").
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/../lib.sh"
: "${VU_CACHE:?}"
. "$VU_CACHE/env.sh"
w=$(mkdir -p "$1" && cd "$1" && pwd)
tc=${VU_MIRI_TOOLCHAIN:-$(vu_pin .charon.rust)}
export XDG_CACHE_HOME=$w/xdg-cache CARGO_TARGET_DIR=$w/target
echo "toolchain: $tc"
cargo "+$tc" --version
cargo "+$tc" miri --version
echo "sha256:"
(cd "$here/.." && sha256sum miri/client.rs miri/erase_verus.py miri/miri.sh \
  verus/src/lib.rs verus/src/shim.rs verus/src/ffi.rs aeneas/src/lib.rs aeneas/src/ffi.rs \
  hax/src/lib.rs hax/src/ffi.rs creusot/src/lib.rs creusot/src/ffi.rs \
  refinedrust/src/lib.rs refinedrust/src/ffi.rs)

status=0
for tool in ${VU_MIRI_TOOLS:-aeneas verus}; do
  d=$w/$tool
  rm -rf "$d"
  mkdir -p "$d/vu"
  deps=""
  if [ "$tool" = verus ]; then
    python3 -I "$here/erase_verus.py" "$here/../verus/src" "$d/vu"
  elif [ "$tool" = creusot ]; then
    cp "$here/../creusot/src/lib.rs" "$here/../creusot/src/ffi.rs" "$d/vu/"
    deps="creusot-std = \"=0.14.0\""
  elif [ "$tool" = refinedrust ]; then
    cp "$here/../refinedrust/src/lib.rs" "$here/../refinedrust/src/ffi.rs" "$d/vu/"
  elif [ "$tool" = hax ]; then
    cp "$here/../hax/src/lib.rs" "$here/../hax/src/ffi.rs" "$d/vu/"
    deps="hax-lib = \"=$(vu_pin .hax.hax_lib)\""
  else
    cp "$here/../aeneas/src/lib.rs" "$here/../aeneas/src/ffi.rs" "$d/vu/"
  fi
  cp "$here/client.rs" "$d/client.rs"
  if [ "$tool" = hax ]; then
    sed -i 's/SUBJECT\.as_ptr()/SUBJECT.as_ptr().expose_provenance()/g' "$d/client.rs"
    diff -u --label client.rs --label hax/client.rs "$here/client.rs" "$d/client.rs" || true
  fi
  if [ "$tool" = refinedrust ]; then
    sed -i -e 's/slot: \[41, 0, 0, 0, 0\]/slot0: 41, slot1: 0, slot2: 0, slot3: 0, slot4: 0/' \
      -e 's/slot: \[0; 5\]/slot0: 0, slot1: 0, slot2: 0, slot3: 0, slot4: 0/' \
      -e 's/a\.slot\b/[a.slot0, a.slot1, a.slot2, a.slot3, a.slot4]/g' \
      -e 's/from: \[0; 8\]/from0: 0, from1: 0, from2: 0, from3: 0, from4: 0, from5: 0, from6: 0, from7: 0/' \
      -e 's/&rec\.from\[\.\.2\]/\&[rec.from0, rec.from1]/g' "$d/client.rs"
    diff -u --label client.rs --label refinedrust/client.rs "$here/client.rs" "$d/client.rs" || true
  fi
  cat >"$d/Cargo.toml" <<TOML
[package]
name = "vu-miri-$tool"
version = "0.0.0"
edition = "2021"
publish = false

[lib]
name = "vu"
path = "vu/lib.rs"

[[bin]]
name = "client"
path = "client.rs"

[dependencies]
$deps
TOML
  for model in stacked tree; do
    flags=""
    [ "$model" = tree ] && flags="-Zmiri-tree-borrows"
    echo "== $tool, $model borrows"
    set +e
    (cd "$d" && MIRIFLAGS="$flags" cargo "+$tc" miri run --quiet --bin client 2>&1)
    s=$?
    set -e
    echo "miri $tool $model: status=$s"
    [ "$s" = 0 ] || status=1
  done
done
exit "$status"
