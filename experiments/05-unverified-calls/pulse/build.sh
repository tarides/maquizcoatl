#!/usr/bin/env bash
# build.sh: F* + Pulse prototype of experiment #5, under run.sh's
# contract (see ../run.sh): checks VU.fst with F*, extracts it to C with
# KaRaMeL, checks the ABI of the generated C against proto.h and leaves
# VU_OUT/libvu.a.
#
# Steps, each timed in the log:
#   1. copy VU.fst to VU_OUT/src; with VU_NEGATIVE_CONTROL=1, replace the
#      lines between CLAMP-BEGIN and CLAMP-END (the clamp of vu_char_len)
#      by "r", the callee's raw result; refuse admit, assume, magic,
#      unsafe_coerce, --admit_smt_queries and --lax;
#   2. F* check (writes the .checked file extraction needs); a rejection
#      made only of failed proof obligations (F* error 19) exits with
#      VU_PROOF_REJECTED, any other error with 1;
#   3. extraction: fstar --codegen KrmlC, then krml -no-prefix VU (no
#      warning allowed);
#   4. ABI: abi_check.c must compile with -Werror against the generated
#      header, and layout.c must print the same layouts against proto.h
#      and against the generated header;
#   5. compile the generated C and archive it.
#
# Environment (from run.sh): VU_HARNESS, VU_OUT, VU_NEGATIVE_CONTROL,
# VU_PROOF_REJECTED; VU_FSTAR_HOME from <cache>/env.sh. VU_JOBS is not
# used: F* checks one module.

set -euo pipefail
: "${VU_HARNESS:?}" "${VU_OUT:?}" "${VU_NEGATIVE_CONTROL:?}"
: "${VU_PROOF_REJECTED:?}" "${VU_FSTAR_HOME:?}"
here=$(pwd)
src=$VU_OUT/src
mkdir -p "$src/cache"

t0=$(date +%s)
step() { echo "== $* ($(($(date +%s) - t0)) s)"; }

step "versions"
fstar.exe --version | sed -n '1p;/^commit=/p'
krml -version | head -1
cc --version | head -1

step "1. source (negative control: $VU_NEGATIVE_CONTROL)"
if [ "$VU_NEGATIVE_CONTROL" = 1 ]; then
  [ "$(grep -c 'CLAMP-BEGIN\|CLAMP-END' VU.fst)" = 2 ] ||
    { echo "clamp markers not found"; exit 1; }
  sed '/CLAMP-BEGIN/,/CLAMP-END/c\  r' VU.fst >"$src/VU.fst"
  diff VU.fst "$src/VU.fst" || true
else
  cp VU.fst "$src/VU.fst"
fi
# No proof escape: the client contracts are function-typed parameters,
# so the module needs no admit, assume, magic or admitted SMT query.
if grep -nE '\b(admit|admit_|assume|assume_|magic|unsafe_coerce)\b|admit_smt_queries|--lax' \
  "$src/VU.fst"; then
  echo "VU.fst admits or assumes a proof obligation, refused"
  exit 1
fi
echo "proof escapes: none"
cd "$src"
fstar=(fstar.exe --cache_checked_modules --cache_dir cache)

step "2. F* check"
set +e
"${fstar[@]}" VU.fst >check.log 2>&1
status=$?
set -e
cat check.log
if [ "$status" != 0 ]; then
  codes=$(sed -n 's/^\* Error \([0-9]*\) .*/\1/p' check.log | sort -u)
  if [ "$codes" = 19 ]; then
    echo "proof rejected (F* error 19 only)"
    exit "$VU_PROOF_REJECTED"
  fi
  echo "F* failed with errors: ${codes:-none reported}"
  exit 1
fi

step "3. extraction"
"${fstar[@]}" --codegen KrmlC --custard_entry_module VU VU.fst --odir krml
krml -skip-compilation -no-prefix VU -tmpdir kc krml/Custard.krml \
  >krml.log 2>&1 || { cat krml.log; exit 1; }
cat krml.log
if grep -q 'Warning' krml.log; then
  echo "krml warned, refused"
  exit 1
fi
for f in kc/Custard.c kc/Custard.h; do
  echo "generated $f: $(wc -l <"$f") lines, $(wc -c <"$f") bytes," \
    "sha256 $(sha256sum "$f" | cut -d' ' -f1)"
done

krml_inc=(-I kc -I "$VU_FSTAR_HOME/include/krml"
  -I "$VU_FSTAR_HOME/lib/krml/dist/minimal")
# gnu11: krmllib's endianness macros use htole64 and friends, which
# glibc declares only outside strict ISO C.
cflags=(-std=gnu11 -O2 -Wall -Wextra -Werror)

step "4. ABI checks"
cc "${cflags[@]}" "${krml_inc[@]}" -c "$here/abi_check.c" -o abi_check.o
echo "abi_check: ok"
cc "${cflags[@]}" -I "$VU_HARNESS" "$here/layout.c" -o layout-proto
cc "${cflags[@]}" -DVU_KRML "${krml_inc[@]}" "$here/layout.c" -o layout-krml
./layout-proto >layout-proto.txt
./layout-krml >layout-krml.txt
cat layout-proto.txt
diff layout-proto.txt layout-krml.txt
echo "layout: same"

step "5. compile"
cc "${cflags[@]}" "${krml_inc[@]}" -c kc/Custard.c -o "$VU_OUT/vu.o"
ar rcs "$VU_OUT/libvu.a" "$VU_OUT/vu.o"
nm -g --defined-only "$VU_OUT/vu.o" | awk '{print "exported:", $3}'
step "done"
