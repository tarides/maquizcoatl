#!/bin/sh
# build.sh SRC OUT [JOBS]
# Mechanism 3: Rust cdylib stub. Needs OUT/stubs/m2/gen/aux{,p}.txt
# (gcc -aux-info of the public headers, made by m2-c/build.sh).
# Installs OUT/stubs/m3/{default,posix} (variadic via a naked-function
# trampoline) and, for the record, OUT/stubs/m3/noexport: the C shim
# linked in directly, with -Wl,--export-dynamic-symbol.
set -eu
SRC=$(cd "$1" && pwd); OUT=$(cd "$2" && pwd); JOBS=${3:-4}
HERE=$(cd "$(dirname "$0")" && pwd)
M=$OUT/stubs/m3; G=$OUT/stubs/m2/gen; mkdir -p "$M"
export PATH="$HOME/.cargo/bin:$PATH"
rustc --version >"$M/rustc.version"; cargo --version >>"$M/rustc.version"
# criterion 5 evidence: a direct C-variadic definition on stable rustc
rustc --edition 2024 --crate-type cdylib -o "$M/variadic_try.so" \
  "$HERE/variadic_try.rs" >"$M/variadic_try.log" 2>&1 && echo accepted >>"$M/variadic_try.log" \
  || echo "rejected (exit $?)" >>"$M/variadic_try.log"
inst() { # target-dir prefix
  mkdir -p "$2/lib" "$2/include"
  cp "$1/release/libonig.so" "$2/lib/libonig.so.5.5.0"
  ln -sf libonig.so.5.5.0 "$2/lib/libonig.so.5"; ln -sf libonig.so.5 "$2/lib/libonig.so"
  cp "$SRC/src/oniguruma.h" "$SRC/src/oniggnu.h" "$2/include/"
}
for v in default posix noexport; do
  pv=$v; [ $v = noexport ] && pv=default
  python3 -I "$HERE/gen_rust_stub.py" "$G/aux.txt" "$G/auxp.txt" "$HERE/../symbols.tsv" \
    "$M/gen_$pv.rs" $pv
  rm -rf "$M/$v"
  if [ $v = noexport ]; then export ONIG_EXPORT_SHIM=1; unset ONIG_TRAMPOLINE || true; else unset ONIG_EXPORT_SHIM || true; export ONIG_TRAMPOLINE=1; fi
  ONIG_STUB_GEN="$M/gen_$pv.rs" ONIG_INCLUDE="$SRC/src" ONIG_SHIM_C="$HERE/../m2-c/stub_shell.c" \
    cargo build --release -j"$JOBS" --manifest-path "$HERE/Cargo.toml" \
      --target-dir "$M/target-$v" >"$M/cargo-$v.log" 2>&1
  inst "$M/target-$v" "$M/$v"
  [ $v = posix ] && cp "$SRC/src/onigposix.h" "$M/$v/include/"
done
# layout of the Rust types, same format as layout.c
ONIG_STUB_GEN="$M/gen_default.rs" ONIG_INCLUDE="$SRC/src" ONIG_SHIM_C="$HERE/../m2-c/stub_shell.c" \
  ONIG_TRAMPOLINE=1 cargo run --release -q --example layout --manifest-path "$HERE/Cargo.toml" \
  --target-dir "$M/target-default" >"$M/layout-rust.txt" 2>"$M/layout-rust.log"
ONIG_STUB_GEN="$M/gen_default.rs" ONIG_INCLUDE="$SRC/src" ONIG_SHIM_C="$HERE/../m2-c/stub_shell.c" \
  ONIG_TRAMPOLINE=1 cargo run --release -q --example layout --manifest-path "$HERE/Cargo.toml" \
  --target-dir "$M/target-default" -- posix >"$M/layout_posix-rust.txt" 2>>"$M/layout-rust.log"
