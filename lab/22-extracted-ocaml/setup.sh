#!/bin/sh
# Issue #22 setup on the bench host (plan steps 2 and 5).
# Usage: CACHE=<cache> EXP=<exp> E12=<experiment #12's directory> \
#          setup.sh {clone|switch|cbuild|subjects|engines} RUNID
# Every job: nice -n 10, taskset -c 0-3,32-35, at most 4 parallel jobs.
# Prints no host name, address or absolute path into <exp>/out/RUNID/.
set -eu
: "${CACHE:?}" "${EXP:?}"
RID=${2:?run-id}
. "$CACHE/env.sh"
TS="nice -n 10 taskset -c 0-3,32-35"
OUT=$EXP/out/$RID/setup; mkdir -p "$OUT" "$EXP/bin"
red() { sed "s|$EXP|<exp>|g; s|$CACHE|<cache>|g; s|${E12:-/nonexistent}|<exp12>|g; s|$HOME|<home>|g"; }
PKGS="zarith.1.14 yojson.3.0.0 ppx_deriving.6.2.0 ppx_deriving_yojson.3.10.0"
case "$1" in
clone)
  [ -d "$EXP/repo" ] || git clone -q --recurse-submodules -b exp/12-extracted-ocaml \
    https://github.com/tarides/maquizcoatl.git "$EXP/repo"
  git -C "$EXP/repo" pull -q --ff-only
  git -C "$EXP/repo" submodule update --init
  test "$(git -C "$EXP/repo/upstream" rev-parse --short=7 HEAD)" = f95747b
  echo "repo $(git -C "$EXP/repo" rev-parse --short HEAD) upstream f95747b" | tee "$OUT/clone.txt"
  ;;
switch)
  # requirement 7: the F* column's packages into ffi, nothing upgraded or
  # removed; ffi exported before and after
  opam switch export --switch=ffi "$OUT/switch-ffi.before.export"
  $TS opam install --switch=ffi --dry-run --jobs=4 $PKGS 2>&1 | red > "$OUT/opam-dry-run.txt"
  cat "$OUT/opam-dry-run.txt"
  if grep -Eiq 'upgrade|downgrade|remove|recompile|reinstall' "$OUT/opam-dry-run.txt"; then
    echo "STOP: opam's solution changes installed packages"; exit 1
  fi
  $TS opam install --switch=ffi --jobs=4 $PKGS 2>&1 | red > "$OUT/opam-install.txt"
  opam switch export --switch=ffi "$OUT/switch-ffi.after.export"
  opam list --switch=ffi -i --columns=name,version --short zarith yojson ppx_deriving ppx_deriving_yojson \
    | tee "$OUT/f-star-packages.txt"
  ;;
cbuild)
  # libonig Release, Release without the optimiser, Debug with
  # ONIG_DEBUG_COMPILE (library only, never timed); out of tree
  for v in release noopt dbgc; do
    d="$EXP/build/onig-$v"
    case $v in
      release) a="-DCMAKE_BUILD_TYPE=Release" ;;
      noopt) a="-DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS=-DONIG_DONT_OPTIMIZE" ;;
      dbgc) a="-DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_FLAGS=-DONIG_DEBUG_COMPILE" ;;
    esac
    $TS cmake -S "$EXP/repo/upstream" -B "$d" $a -DBUILD_SHARED_LIBS=ON > "$OUT/cmake-$v.log" 2>&1
    if [ $v = dbgc ]; then $TS make -C "$d" -j4 onig > "$OUT/make-$v.log" 2>&1
    else $TS make -C "$d" -j4 > "$OUT/make-$v.log" 2>&1; fi
  done
  (cd "$EXP/build/onig-release/test" && $TS ./test_utf8 2>&1 | tail -1) | tee "$OUT/test_utf8.txt"
  ;;
subjects)
  : "${E12:?}"
  mkdir -p "$EXP/subjects"
  for f in log-1m log-16m src-1m src-16m; do cp "$E12/subjects/$f" "$EXP/subjects/"; done
  M="$EXP/repo/lab/results/2026-11-19-exp-12-raw/subjects-manifest.txt"
  for f in log-1m log-16m src-1m src-16m; do
    want=$(sed -n "s/^$f .*sha256=\([0-9a-f]*\).*/\1/p" "$M")
    got=$(sha256sum "$EXP/subjects/$f" | cut -d' ' -f1)
    echo "$f $got $([ "$got" = "$want" ] && echo same || echo "DIFFERENT (manifest $want)")"
  done | tee "$OUT/subjects.txt"
  ! grep -q DIFFERENT "$OUT/subjects.txt"
  ;;
engines)
  # staging tree: one dune project holding lab/12-ffi-vs-native,
  # lab/22-extracted-ocaml and the generated sources, so that lab/12's
  # bench executable sees the extracted22 library (a private library is
  # visible within its own project only: the per-directory dune-project
  # files are left out of the copy)
  S=$EXP/src; rm -rf "$S"; mkdir -p "$S"
  cp -r "$EXP/repo/lab/12-ffi-vs-native" "$EXP/repo/lab/22-extracted-ocaml" "$EXP/gen" "$S/"
  rm -rf "$S/12-ffi-vs-native/_build" "$S/22-extracted-ocaml/gen"
  rm -f "$S/12-ffi-vs-native/dune-project" "$S/22-extracted-ocaml/dune-project"
  echo '(lang dune 3.0)' > "$S/dune-workspace"; echo '(lang dune 3.0)' > "$S/dune-project"
  L="$EXP/build/onig-release"
  ONIG_INC="$EXP/repo/upstream/src" ONIG_LIB="$L" $TS opam exec --switch=ffi -- \
    dune build -j 4 --root "$S" --profile release 2>&1 | red > "$OUT/dune-build.log"
  cp "$S/_build/default/12-ffi-vs-native/bench/main.exe" "$EXP/bin/main-ffi.exe"
  cp "$S/_build/default/22-extracted-ocaml/x22/x22.exe" "$EXP/bin/x22.exe"
  $TS gcc -O2 -Wall -I"$EXP/repo/upstream/src" "$EXP/repo/lab/12-ffi-vs-native/bench/cdriver.c" \
    -L"$L" -lonig -Wl,-rpath,"$L" -o "$EXP/bin/cdriver"
  d="$EXP/build/onig-noopt"
  $TS gcc -O2 -Wall -I"$EXP/repo/upstream/src" "$EXP/repo/lab/12-ffi-vs-native/bench/cdriver.c" \
    -L"$d" -lonig -Wl,-rpath,"$d" -o "$EXP/bin/cdriver-noopt"
  # effective flags of the OCaml libraries (release profile)
  for dir in gen/rocq gen/fstar 22-extracted-ocaml/adapter 12-ffi-vs-native/vm 12-ffi-vs-native/bench; do
    echo "== $dir"
    opam exec --switch=ffi -- dune printenv --root "$S" --profile release "$dir" 2>/dev/null \
      | tr '\n' ' ' | sed 's/  */ /g'; echo
    grep -h 'flags' "$S/$dir/dune" 2>/dev/null | tr '\n' ' '; echo
  done | red > "$OUT/ocaml-flags.txt"
  # the linked engine module: x22 adapters, not the stand-ins
  (cd "$S" && ls _build/default/12-ffi-vs-native/bench/extracted.ml && \
     cat _build/default/12-ffi-vs-native/bench/extracted.ml) | tail -1 > "$OUT/select.txt"
  cat "$OUT/select.txt"
  ;;
*) echo "usage: setup.sh {clone|switch|cbuild|subjects|engines} RUNID" >&2; exit 2 ;;
esac
