#!/bin/sh
# Setup for experiment #12 on the bench host.
# Usage: CACHE=<cache> EXP=<exp> setup.sh {switches|clone|cbuild}
# All jobs run under taskset -c 0-3,32-35 with at most 4 parallel jobs.
set -eu
: "${CACHE:?}" "${EXP:?}"
. "$CACHE/env.sh"
TS="taskset -c 0-3,32-35"
PKGS="dune.3.25.0 ctypes.0.24.0 ctypes-foreign.0.24.0 re.1.14.0 mtime.2.2.0"
case "$1" in
switches)
  $TS opam update default
  opam repo list --all
  git -C "$OPAMROOT/repo/default" rev-parse HEAD 2>/dev/null || true
  # flambda first (longest build), then vanilla. There is no
  # ocaml-option-O3 package: -O3 is passed to ocamlopt by the dune build.
  opam switch list | grep -q ' ffi-flambda ' ||
    $TS opam switch create ffi-flambda --jobs=4 --no-switch \
      --packages=ocaml-variants.5.4.1+options,ocaml-option-flambda
  $TS opam install --switch=ffi-flambda --jobs=4 $PKGS
  opam switch list | grep -q ' ffi ' ||
    $TS opam switch create ffi --jobs=4 --no-switch \
      --packages=ocaml-base-compiler.5.4.1
  $TS opam install --switch=ffi --jobs=4 $PKGS
  ;;
clone)
  [ -d "$EXP/repo" ] || git clone --recurse-submodules -b exp/12-ffi-vs-native \
    https://github.com/tarides/maquizcoatl.git "$EXP/repo"
  git -C "$EXP/repo" pull --ff-only
  git -C "$EXP/repo" submodule update --init
  test "$(git -C "$EXP/repo/upstream" rev-parse --short=7 HEAD)" = f95747b
  ;;
cbuild)
  for t in Release Debug; do
    d="$EXP/build/onig-$(echo $t | tr A-Z a-z)"
    $TS cmake -S "$EXP/repo/upstream" -B "$d" -DCMAKE_BUILD_TYPE=$t -DBUILD_SHARED_LIBS=ON
    $TS make -C "$d" -j4
  done
  d="$EXP/build/onig-dbgc"
  $TS cmake -S "$EXP/repo/upstream" -B "$d" -DCMAKE_BUILD_TYPE=Debug \
    -DBUILD_SHARED_LIBS=ON -DCMAKE_C_FLAGS=-DONIG_DEBUG_COMPILE
  $TS make -C "$d" -j4 onig
  ;;
engines)
  # OCaml harness in both switches, C driver; all against the Release libonig.so
  L="$EXP/build/onig-release"
  for sw in ffi ffi-flambda; do
    ONIG_INC="$EXP/repo/upstream/src" ONIG_LIB="$L" $TS opam exec --switch=$sw -- \
      dune build -j 4 --root "$EXP/repo/lab/12-ffi-vs-native" --build-dir "$EXP/_build-$sw" --profile release
    cp "$EXP/_build-$sw/default/bench/main.exe" "$EXP/bin/main-$sw.exe"
  done
  $TS gcc -O2 -Wall -I"$EXP/repo/upstream/src" "$EXP/repo/lab/12-ffi-vs-native/bench/cdriver.c" \
    -L"$L" -lonig -Wl,-rpath,"$L" -o "$EXP/bin/cdriver"
  ;;
esac
