#!/bin/bash
# exports.sh SRC OUT [JOBS]
# Export control (maintainer decision on issue #7, spec/deviations.md
# DEV-005): rebuild the stubs with an anonymous version script listing
# exactly the public names of symbols.tsv (208 default, 216 POSIX), and
# check that nothing else is exported and that public data stays
# preemptible. Needs the generated sources left by m2-c/build.sh and
# m1-pulse/build.sh under OUT/stubs, the harness, and fstar.exe on PATH.
# Installs OUT/stubs/{m1a,m1b,m2}-vs/{default,posix}, the negative
# control OUT/stubs/m1b-vs-bsymbolic/default, and OUT/stubs/m3-vs/
# {default,shim} (Rust: rustc's own export list, plus a user version
# script exporting the C shim's variadic directly). Reports go to
# OUT/exports/.
set -u
SRC=$(cd "$1" && pwd); OUT=$(cd "$2" && pwd); JOBS=${3:-4}
HERE=$(cd "$(dirname "$0")" && pwd)
R=$OUT/exports; mkdir -p "$R"
FS=$(dirname "$(dirname "$(command -v fstar.exe)")")
KINC="$FS/include/krml $FS/lib/krml/dist/minimal"
G=$OUT/stubs/m2/gen

# 1. version scripts
for v in default posix; do
  awk -F'\t' -v v=$v 'NR>1 && $3=="public" && index($5, v) {print $1}' "$HERE/symbols.tsv" \
    | sort >"$R/public-$v.txt"
  { echo "{"; echo "  global:"; sed 's/.*/    &;/' "$R/public-$v.txt"; echo "  local: *;"; echo "};"; } \
    >"$R/onig-$v.map"
  echo "$v public names: $(wc -l <"$R/public-$v.txt")"
done

# 2. C stubs (1a, 1b, 2) rebuilt with the version script
build() { # mech variant srcdir gendir extra-cmake-args... ; installs under OUT/stubs/<mech>
  local m=$1 v=$2 s=$3; shift 3
  local f=OFF; [ $v = posix ] && f=ON
  local B=$OUT/stubs/$m/build-$v
  rm -rf "$B" "$OUT/stubs/$m/$v"; mkdir -p "$B"
  cmake -S "$s" -B "$B" -DCMAKE_BUILD_TYPE=Release -DENABLE_POSIX_API=$f \
    -DONIG_INCLUDE="$SRC/src" -DCMAKE_INSTALL_PREFIX="$OUT/stubs/$m/$v" \
    -DCMAKE_INSTALL_LIBDIR=lib "$@" >"$B.cmake.log" 2>&1 &&
  make -C "$B" -j"$JOBS" VERBOSE=1 >"$B.make.log" 2>&1 &&
  make -C "$B" install >"$B.install.log" 2>&1
  echo "build $m $v exit $?"
}
for v in default posix; do
  map=$R/onig-$v.map; W=$OUT/stubs/m1-fstar/$v
  build m2-vs $v "$HERE/m2-c" -DGEN_DIR="$G" -DCMAKE_C_FLAGS="-Wall -Wextra -std=c99" -DEXPORT_MAP="$map"
  build m1a-vs $v "$HERE/m1-pulse" -DEMITTER=krml -DGEN_DIR="$W/kc" -DKRML_INCLUDE="$KINC" -DEXPORT_MAP="$map"
  build m1b-vs $v "$HERE/m1-pulse" -DEMITTER=custard -DGEN_DIR="$W/dc" -DEXPORT_MAP="$map"
done
# negative control for the Custard constructor route: same, plus -Bsymbolic
build m1b-vs-bsymbolic default "$HERE/m1-pulse" -DEMITTER=custard \
  -DGEN_DIR="$OUT/stubs/m1-fstar/default/dc" -DEXPORT_MAP="$R/onig-default.map" \
  -DEXTRA_LINK_FLAGS="-Wl,-Bsymbolic"

# 3. Rust (mechanism 3): rustc already writes its own version script
# for a cdylib; record it, and try a user version script that exports
# the C shim's variadic directly (no trampoline).
export PATH="$HOME/.cargo/bin:$PATH"
M=$OUT/stubs/m3-vs; mkdir -p "$M"
rinst() { mkdir -p "$2/lib" "$2/include"
  cp "$1/release/libonig.so" "$2/lib/libonig.so.5.5.0"
  ln -sf libonig.so.5.5.0 "$2/lib/libonig.so.5"; ln -sf libonig.so.5 "$2/lib/libonig.so"
  cp "$SRC/src/oniguruma.h" "$SRC/src/oniggnu.h" "$2/include/"; }
for k in default shim; do
  rm -rf "$M/$k" "$M/target-$k"
  if [ $k = default ]; then
    ( export ONIG_TRAMPOLINE=1; unset ONIG_EXPORT_SHIM
      ONIG_STUB_GEN="$OUT/stubs/m3/gen_default.rs" ONIG_INCLUDE="$SRC/src" ONIG_SHIM_C="$HERE/m2-c/stub_shell.c" \
      cargo rustc --lib --release -j"$JOBS" --manifest-path "$HERE/m3-rust/Cargo.toml" \
        --target-dir "$M/target-$k" -- --print link-args ) >"$M/cargo-$k.log" 2>&1
  else
    ( unset ONIG_TRAMPOLINE ONIG_EXPORT_SHIM
      ONIG_STUB_GEN="$OUT/stubs/m3/gen_default.rs" ONIG_INCLUDE="$SRC/src" ONIG_SHIM_C="$HERE/m2-c/stub_shell.c" \
      cargo rustc --lib --release -j"$JOBS" --manifest-path "$HERE/m3-rust/Cargo.toml" \
        --target-dir "$M/target-$k" -- --print link-args \
        -C link-arg=-Wl,--version-script="$R/onig-default.map" ) >"$M/cargo-$k.log" 2>&1
  fi
  st=$?; echo "build m3-vs $k exit $st"
  [ $st -eq 0 ] && rinst "$M/target-$k" "$M/$k"
done

# 4. checks
dynvis() { # lib: defined dynamic symbols by binding/visibility
  readelf -W --dyn-syms "$1" | awk '$7!="UND" && $8!="" && $4!="SECTION" && $4!="FILE" {print $5, $6}' \
    | sort | uniq -c; }
for p in m2-vs/default m2-vs/posix m1a-vs/default m1a-vs/posix m1b-vs/default m1b-vs/posix \
         m1b-vs-bsymbolic/default m3-vs/default m3-vs/shim; do
  [ -e "$OUT/stubs/$p/lib/libonig.so.5" ] || { echo "$p: not built"; continue; }
  v=${p#*/}; [ "$v" = posix ] || v=default
  t=$R/$(echo "$p" | tr / -)
  "$HERE/check-stub.sh" "$OUT/stubs/$p" $v "$OUT" >"$t.tsv"
  lib=$OUT/stubs/$p/lib/libonig.so.5
  nm -D --defined-only "$lib" | awk '{print $3}' | sort >"$t.exported"
  {
    echo "== exported not public: $(comm -23 "$t.exported" "$R/public-$v.txt" | tr '\n' ' ')"
    echo "== public not exported: $(comm -13 "$t.exported" "$R/public-$v.txt" | tr '\n' ' ')"
    echo "== binding/visibility of defined dynamic symbols"; dynvis "$lib"
    echo "== dynamic flags"; readelf -d "$lib" | grep -E 'FLAGS|SYMBOLIC|SONAME' || echo "(no FLAGS entry)"
    echo "== relocations against OnigEncodingUTF8 / OnigEncodingASCII in the library"
    readelf -W -r "$lib" | grep -E 'OnigEncoding(UTF8|ASCII) ' || echo "(none)"
    echo "== stub-private names still in the full symbol table (local)"
    nm "$lib" 2>/dev/null | grep -E ' (s_init|s_mbc_enc_len|custard_init_globals|onig_stub_)' | head -5
    echo "== data_init"
    LD_LIBRARY_PATH="$OUT/stubs/$p/lib" "$OUT/harness/bin-data_init" 2>&1
    echo "== variadic_call"
    LD_LIBRARY_PATH="$OUT/stubs/$p/lib" "$OUT/harness/bin-variadic_call" 2>&1 | head -4
  } >"$t.txt"
  echo "$p	$(grep -P '^1\tsymbols\t' "$t.tsv" | cut -f3,4)	binaries $(awk -F'\t' '$1==3' "$t.tsv" | grep -c pass)/$(awk -F'\t' '$1==3' "$t.tsv" | wc -l)	layout $(awk -F'\t' '$1==2' "$t.tsv" | grep -c pass)/$(awk -F'\t' '$1==2' "$t.tsv" | wc -l)	extra-vs-public $(comm -23 "$t.exported" "$R/public-$v.txt" | wc -l)"
done | tee "$R/summary.tsv"
echo "== executable side: copy relocations in data_init" >"$R/data_init-relocs.txt"
readelf -W -r "$OUT/harness/bin-data_init" | grep -E 'COPY' >>"$R/data_init-relocs.txt"
