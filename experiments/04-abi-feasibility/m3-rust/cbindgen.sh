#!/bin/sh
# cbindgen.sh OUT CBINDGEN: second layout check of mechanism 3. A C
# header is generated from the Rust #[repr(C)] types with cbindgen and
# layout.c / layout_posix.c are compiled against it (installed as
# oniguruma.h and onigposix.h in a scratch include dir); outputs are
# diffed against the references compiled from upstream's headers.
set -u
OUT=$(cd "$1" && pwd); CB=$2; HERE=$(cd "$(dirname "$0")" && pwd)
M=$OUT/stubs/m3; C=$M/cbindgen; mkdir -p "$C"
export PATH="$HOME/.cargo/bin:$PATH"
"$CB" --version >"$C/version"
(cd "$HERE" && ONIG_STUB_GEN="$M/gen_default.rs" "$CB" --config cbindgen.toml \
   --crate onig-stub -o "$C/oniguruma.h" . 2>"$C/log")
cp "$C/oniguruma.h" "$C/onigposix.h"
for l in layout layout_posix; do
  if gcc -std=gnu11 -I"$C" -o "$C/$l" "$HERE/../$l.c" 2>"$C/$l.err"; then
    "$C/$l" >"$C/$l.txt"
    if diff "$OUT/harness/ref/$l.txt" "$C/$l.txt" >"$C/$l.diff"; then echo "$l	same"
    else echo "$l	differs"; fi
  else echo "$l	does not compile against the cbindgen header"; fi
done
