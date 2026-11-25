#!/bin/bash
# Experiment #11, step 2: reproducible setup on the bench host.
# Usage: setup.sh   (BENCH defaults to ~/maquizcoatl-work/exp/11-perf-baselines)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/env.sh"
case "$BENCH" in "$HOME"/*) ;; *) echo "BENCH must be under \$HOME" >&2; exit 1;; esac
mkdir -p "$BENCH"/{src,build,prefix,toolchains,workloads,out,log}
avail=$(df -BG --output=avail "$BENCH" | tail -1 | tr -dc 0-9)
[ "$avail" -ge 10 ] || { echo "less than 10 GB free" >&2; exit 1; }
echo "load: $(cut -d' ' -f1-3 /proc/loadavg)"

# Tarballs, verified against pins.json when a sha256 is pinned.
fetch() { # name
  url=$(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))[sys.argv[2]]['url'])" "$HERE/pins.json" "$1")
  want=$(python3 -I -c "import json,sys;print(json.load(open(sys.argv[1]))[sys.argv[2]]['sha256'])" "$HERE/pins.json" "$1")
  f="$BENCH/src/$(basename "$url")"
  [ -f "$f" ] || curl -sSfL -o "$f" "$url"
  got=$(sha256sum "$f" | cut -d' ' -f1)
  echo "sha256 $1 $(basename "$f") $got"
  if [ "$want" != TBD ] && [ "$want" != "$got" ]; then echo "sha256 mismatch for $1" >&2; exit 1; fi
}
fetch pcre2; fetch abseil; fetch re2

# Rust, under $BENCH/toolchains only.
if [ ! -x "$CARGO_HOME/bin/rustup" ]; then
  curl -sSfL -o "$BENCH/src/rustup-init" https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init
  echo "sha256 rustup-init $(sha256sum "$BENCH/src/rustup-init" | cut -d' ' -f1)"
  chmod +x "$BENCH/src/rustup-init"
  "$BENCH/src/rustup-init" -y --no-modify-path --profile minimal --default-toolchain 1.100.0
fi
rustc --version

# OCaml, separate OPAMROOT.
if [ ! -d "$OPAMROOT/e11" ]; then
  opam init --bare --disable-sandboxing -n
  taskset -c "$BUILD_CPUS" opam switch create e11 ocaml-base-compiler.5.5.2 --jobs=4
fi
taskset -c "$BUILD_CPUS" opam install --jobs=4 re.1.14.0 mtime.2.2.0 dune.3.25.0
opam exec -- ocamlfind list 2>/dev/null | grep -E '^(re|mtime) ' || opam list --columns=name,version re mtime dune ocaml
echo setup done
