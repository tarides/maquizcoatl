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
  hax/src/lib.rs hax/src/ffi.rs)

status=0
for tool in ${VU_MIRI_TOOLS:-aeneas verus}; do
  d=$w/$tool
  rm -rf "$d"
  mkdir -p "$d/vu"
  deps=""
  if [ "$tool" = verus ]; then
    python3 -I "$here/erase_verus.py" "$here/../verus/src" "$d/vu"
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
