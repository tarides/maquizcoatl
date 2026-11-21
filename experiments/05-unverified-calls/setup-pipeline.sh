#!/usr/bin/env bash
# setup-pipeline.sh: the experiment pipeline's install of the milestone
# 1 and 2 toolchains of experiment #5 (run A, 2026-11-21).
#
# The earlier runs installed with setup.sh into a cache the pipeline's
# account cannot read. This script installs the same pins (pins.json,
# sha256 checked by setup.sh's vu_fetch) into the project's shared
# toolchain cache instead, and runs setup.sh itself unchanged: it builds
# a "view" directory with the layout setup.sh expects for VU_CACHE, made
# of links into the shared cache, and runs setup.sh with VU_CACHE set to
# that view. run.sh and the build.sh scripts then run unchanged with the
# same VU_CACHE.
#
# Usage: setup-pipeline.sh view
#        setup-pipeline.sh check
#        setup-pipeline.sh MILESTONE [COMPONENT...]   (passed to setup.sh)
#
#   view    creates or refreshes the view <shared>/exp05-view
#   check   checks the shared copies that setup.sh's own steps would
#           not install (see "Differences" below) against pins.json
#
# Environment: VU_SHARED_CACHE (the shared cache, <shared-cache>),
# VU_EXP, VU_CPUS, VU_JOBS as for setup.sh. VU_CACHE is set here.
# VU_MIN_FREE_GB (default 20): a milestone run is refused when the disk
# holding the shared cache has less than this much free space plus
# VU_NEED_GB (the caller's estimate of the install, default 0).
#
# Differences from setup.sh's own cache layout (each one recorded in
# the run A notebook entry):
#   - F*: the shared cache holds the same release (fstar.tar.gz, sha256
#     as pinned) unpacked at <shared-cache>/fstar, not fstar/<version>;
#     the view links fstar/current to it, and setup.sh's "fstar" step is
#     not run (its find does not follow a linked start directory).
#     "check" verifies the sha256 of the download and the versions.
#   - Verus: likewise, the same release zip unpacked at
#     <shared-cache>/verus; verus/current links to it, the "verus" step
#     is not run, "check" verifies it.
#   - LLVM and Isabelle: installed in the shared cache by experiment #4
#     with the same pins; the "llvm" step is not run because it would
#     re-point the shared llvm/current link (to the same directory, by
#     another path). The "isabelle-llvm" step runs: it finds everything
#     present and only checks the session heap is up to date.
#   - Why3: the switch "provers" of the shared cache (as before); the
#     view has its own why3/ (why3.conf and the Z3 link), so the shared
#     cache's why3.conf is untouched.
#   - opam: the shared root <shared-cache>/opam, where the "vst" step
#     adds the switch "vst"; the shared opam binary.
#   - rustup, cargo, elan: the shared ones (elan 4.4.0 already there);
#     the steps add the pinned toolchains to them.
#   - Mathlib's download cache goes to <shared-cache>/mathlib-cache
#     (MATHLIB_CACHE_DIR) and XDG_CACHE_HOME to <shared-cache>/xdg, not
#     the account's home.
#   - env.sh is the view's own; the shared cache's env.sh is untouched.

set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$here/lib.sh"

vu_need_env VU_SHARED_CACHE
[ -d "$VU_SHARED_CACHE" ] || vu_die "VU_SHARED_CACHE is not a directory"
VU_SHARED_CACHE=$(cd "$VU_SHARED_CACHE" && pwd -P)
view=$VU_SHARED_CACHE/exp05-view
export VU_CACHE=$view VU_SHARED_CACHE
export MATHLIB_CACHE_DIR=$VU_SHARED_CACHE/mathlib-cache
export XDG_CACHE_HOME=$VU_SHARED_CACHE/xdg

# link NAME TARGET: view/NAME -> TARGET (absolute), created or refreshed.
link() {
  mkdir -p "$(dirname "$view/$1")"
  ln -sfn "$2" "$view/$1"
}

make_view() {
  local d
  mkdir -p "$view/why3/bin" "$MATHLIB_CACHE_DIR" "$XDG_CACHE_HOME"
  for d in bin dl opam rustup cargo elan aeneas isabelle llvm; do
    mkdir -p "$VU_SHARED_CACHE/$d"
    link "$d" "$VU_SHARED_CACHE/$d"
  done
  link fstar/current "$VU_SHARED_CACHE/fstar"
  link verus/current "$VU_SHARED_CACHE/verus"
  vu_log "view ready: <shared-cache>/exp05-view"
}

check_shared() {
  local got
  [ -f "$view/env.sh" ] || vu_die "no env.sh in the view: run setup-pipeline.sh 1 first"
  # shellcheck disable=SC1091
  . "$view/env.sh"
  got=$(vu_sha256 "$VU_SHARED_CACHE/dl/fstar.tar.gz")
  [ "$got" = "$(vu_pin .fstar.sha256)" ] || vu_die "F* download is not the pinned release"
  echo "fstar download sha256 as pinned: $got"
  fstar.exe --version | sed -n 1p
  krml -version
  got=$(vu_sha256 "$VU_SHARED_CACHE/dl/verus-$(vu_pin .verus.version)-x86-linux.zip")
  [ "$got" = "$(vu_pin .verus.sha256)" ] || vu_die "Verus download is not the pinned release"
  echo "verus download sha256 as pinned: $got"
  verus --version 2>&1 | grep -F "$(vu_pin .verus.version)"
  for f in Isabelle2026_linux.tar.gz afp-2026-11-19.tar.gz LLVM-23.1.5-Linux-X64.tar.xz; do
    echo "$f sha256=$(vu_sha256 "$VU_SHARED_CACHE/dl/$f")"
  done
  git -C "$VU_SHARED_CACHE/isabelle/isabelle_llvm" rev-parse HEAD
  clang --version | sed -n 1p
}

case "${1:-}" in
view) make_view ;;
check) check_shared 2>&1 | vu_redact ;;
1 | 2)
  make_view
  for c in "${@:2}"; do
    case "$c" in fstar | verus | llvm)
      vu_die "component $c is not run on the shared cache (see the header)" ;;
    esac
  done
  [ $# -ge 2 ] || vu_die "name the components (fstar, verus and llvm are not run here)"
  free=$(df -BG --output=avail "$VU_SHARED_CACHE" | tail -n 1 | tr -dc 0-9)
  need=$((${VU_MIN_FREE_GB:-20} + ${VU_NEED_GB:-0}))
  [ "$free" -ge "$need" ] ||
    vu_die "only ${free} GB free, ${need} GB needed: install refused"
  exec "$here/setup.sh" "$@"
  ;;
*) vu_die "usage: setup-pipeline.sh view | check | MILESTONE COMPONENT..." ;;
esac
