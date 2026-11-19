#!/bin/bash
# Toolchains for experiment #7 on the bench host. Idempotent.
# CACHE and EXP default to ~/maquizcoatl-work/{cache,exp/07-large-tables}.
# Usage: setup.sh opam|lean|fstar|karamel|onig
set -euo pipefail
CACHE=${CACHE:-$HOME/maquizcoatl-work/cache}
EXP=${EXP:-$HOME/maquizcoatl-work/exp/07-large-tables}
JOBS=${JOBS:-12}
mkdir -p "$CACHE/bin" "$CACHE/dl" "$EXP"
cat > "$CACHE/env.sh" <<EOS
export OPAMROOT=$CACHE/opam ELAN_HOME=$CACHE/elan OPAMNOENVNOTICE=1 OPAMYES=1
export PATH=$CACHE/bin:$CACHE/elan/bin:$CACHE/fstar/bin:\$PATH
EOS
. "$CACHE/env.sh"
fetch() { # url sha256 dest
  [ -f "$3" ] || curl -fsSL -o "$3.part" "$1" && { [ -f "$3" ] || mv "$3.part" "$3"; }
  echo "$2  $3" | sha256sum -c --quiet
}
df -BG --output=avail "$HOME" | tail -1
case "$1" in
opam)
  fetch https://github.com/ocaml/opam/releases/download/2.6.1/opam-2.6.1-x86_64-linux \
    b533d393a6967150d6ef41cb3d71e147e93ecbabeb59e921aa412c0ae79ebe3d "$CACHE/bin/opam"
  chmod +x "$CACHE/bin/opam"
  [ -d "$OPAMROOT" ] || opam init --bare --disable-sandboxing -n
  opam switch list -s | grep -qx provers || opam switch create provers ocaml-base-compiler.5.4.1 --jobs=$JOBS
  opam install --switch=provers --jobs=$JOBS rocq-core.9.3.0 rocq-stdlib rocq-native why3.1.9.0 alt-ergo.2.6.5 ocamlfind zarith batteries pprint stdint yojson ppx_deriving ppx_deriving_yojson
  ;;
lean)
  fetch https://github.com/leanprover/elan/releases/download/v4.4.0/elan-x86_64-unknown-linux-gnu.tar.gz \
    0e8250aa2be86c7af929ade68db617af9edc8b9ccf6eaf5ece228250d0d032e2 "$CACHE/dl/elan.tar.gz"
  tar -xzf "$CACHE/dl/elan.tar.gz" -C "$CACHE/dl"
  [ -x "$ELAN_HOME/bin/elan" ] || "$CACHE/dl/elan-init" -y --no-modify-path --default-toolchain none
  elan toolchain install leanprover/lean4:v4.36.0
  ;;
fstar)
  fetch https://github.com/FStarLang/FStar/releases/download/v2026.11.15/fstar-v2026.11.15-Linux-x86_64.tar.gz \
    375b811af042d36c38641995799c4d4146a521b1db4014efc9d018c713e5177b "$CACHE/dl/fstar.tar.gz"
  [ -d "$CACHE/fstar" ] || tar -xzf "$CACHE/dl/fstar.tar.gz" -C "$CACHE"
  ;;
karamel)
  # The F* v2026.11.15 Linux binary release bundles krml (bin/krml, lib/krml)
  # built at the KaRaMeL commit it was released with; that krml is used
  # instead of building KaRaMeL master (no separate build needed).
  "$CACHE/fstar/bin/krml" -version
  ;;
onig)
  [ -d "$EXP/repo" ] || git clone -q --recurse-submodules -b exp/07-large-tables https://github.com/tarides/maquizcoatl "$EXP/repo"
  test "$(git -C "$EXP/repo/upstream" rev-parse --short=7 HEAD)" = f95747b
  cmake -S "$EXP/repo/upstream" -B "$EXP/build/onig" -DCMAKE_BUILD_TYPE=Release >/dev/null
  make -C "$EXP/build/onig" -j$JOBS >/dev/null
  "$EXP/build/onig/test/test_utf8" | tail -1
  ;;
esac
echo "setup $1: ok"
