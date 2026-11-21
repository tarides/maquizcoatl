#!/usr/bin/env bash
# build.sh: the Why3 prototype of experiment #5. Follows the TOOL/build.sh
# contract of run.sh: run from this directory with VU_HARNESS, VU_OUT,
# VU_JOBS, VU_NEGATIVE_CONTROL and VU_PROOF_REJECTED set, after
# <cache>/env.sh has been sourced.
#
# 1. Copies vu.mlw and vu.drv into VU_OUT/src. With VU_NEGATIVE_CONTROL=1,
#    the clamp of vu_char_len (the lines from CLAMP-BEGIN to CLAMP-END)
#    is replaced by "r", the callee's raw result. With
#    VU_NEGATIVE_CONTROL=2, the lines from READ-BEGIN to READ-END (the
#    upper bound test of vu_get_subject_byte) are deleted, so that it may
#    read past subject_len. Module Vu may hold no
#    val, axiom or assume.
# 2. Splits every verification condition of vu.mlw into its goals
#    (transformation split_vc) and proves each goal with Alt-Ergo, then
#    with Z3 (Why3's registered provers). Every goal must be valid for
#    both provers.
# 3. Extracts module Vu to C with Why3's C driver and vu.drv, compiles
#    it against proto.h and archives it into VU_OUT/libvu.a.
#
# Exit status: 0, VU_PROOF_REJECTED when a prover answers anything but
# Valid for a goal (Invalid, Unknown, Timeout, OutOfMemory, StepLimit),
# 1 for any other failure.

set -euo pipefail

: "${VU_HARNESS:?}" "${VU_OUT:?}" "${VU_PROOF_REJECTED:?}"
control=${VU_NEGATIVE_CONTROL:-0}
here=$(pwd)
src=$VU_OUT/src
timelimit=10
# VU_JOBS is not used: why3 prove has no job option, and Why3's
# configuration in <cache>/why3 runs at most 2 provers at a time.

fail() {
  printf 'why3/build.sh: %s\n' "$*" >&2
  exit 1
}

for t in why3 alt-ergo cc ar sha256sum; do
  command -v "$t" >/dev/null || fail "$t not found"
done
[ -n "${VU_WHY3_Z3:-}" ] && [ -x "$VU_WHY3_Z3" ] ||
  fail "VU_WHY3_Z3 is not set or not executable: run setup.sh 1 why3"

echo "== versions"
why3 --version
echo "alt-ergo: $(alt-ergo --version)"
"$VU_WHY3_Z3" --version
why3 config list-provers
cc --version | head -n 1

echo "== sources (negative control: $control)"
mkdir -p "$src"
cp "$here/vu.mlw" "$here/vu.drv" "$src/"
if [ "$control" = 1 ]; then
  [ "$(grep -c 'CLAMP-BEGIN' "$src/vu.mlw")" = 1 ] &&
    [ "$(grep -c 'CLAMP-END' "$src/vu.mlw")" = 1 ] ||
    fail "vu.mlw must hold exactly one CLAMP-BEGIN and one CLAMP-END line"
  awk '/CLAMP-BEGIN/ { print "    r"; skip = 1; next }
       /CLAMP-END/ { skip = 0; next }
       !skip' "$here/vu.mlw" >"$src/vu.mlw"
  cmp -s "$here/vu.mlw" "$src/vu.mlw" && fail "the clamp was not removed"
  diff -u --label vu.mlw --label vu.mlw.control "$here/vu.mlw" \
    "$src/vu.mlw" || true
elif [ "$control" = 2 ]; then
  [ "$(grep -c 'READ-BEGIN' "$src/vu.mlw")" = 1 ] &&
    [ "$(grep -c 'READ-END' "$src/vu.mlw")" = 1 ] ||
    fail "vu.mlw must hold exactly one READ-BEGIN and one READ-END line"
  sed '/READ-BEGIN/,/READ-END/d' "$here/vu.mlw" >"$src/vu.mlw"
  cmp -s "$here/vu.mlw" "$src/vu.mlw" && fail "the bound test was not removed"
  diff -u --label vu.mlw --label vu.mlw.control-read "$here/vu.mlw" \
    "$src/vu.mlw" || true
fi
sha256sum "$src/vu.mlw" "$src/vu.drv" | sed 's#  .*/#  #'
# No proof escape in module Vu, the verified part: no val (a declaration
# without body), axiom or assume. What Why3 assumes is all in module
# Client, which TRUSTED lists.
vu_module=$(awk '/^module Vu$/ { f = 1 } f; f && /^end$/ { exit }' "$src/vu.mlw")
[ -n "$vu_module" ] || fail "no module Vu in vu.mlw"
if printf '%s\n' "$vu_module" | grep -nwE 'val|axiom|assume'; then
  fail "module Vu holds a val, axiom or assume"
fi
echo "proof escapes in module Vu: none"

# prove PROVER: proves every goal of vu.mlw with PROVER, logs to
# VU_OUT/prove-PROVER.log and prints one summary line. Returns 0 when
# every goal is valid, VU_PROOF_REJECTED when some goal is not, 1 on any
# other failure.
prove() {
  local p=$1 log=$VU_OUT/prove-$1.log start status goals valid rejected
  start=$(date +%s)
  status=0
  why3 prove -L "$src" -P "$p" -t "$timelimit" -a split_vc "$src/vu.mlw" \
    >"$log" 2>&1 ||
    status=$?
  cat "$log"
  # why3 prove exits with 0 when every goal is valid and with 2 when a
  # prover answered something else for some goal; the per-goal answers
  # below decide which.
  goals=$(grep -c '^Prover result is: ' "$log" || true)
  valid=$(grep -c '^Prover result is: Valid' "$log" || true)
  # Case-insensitive: Why3 1.9.0 prints "Out of memory" and "Step limit
  # exceeded" (run B found the first one missed by a case-sensitive test).
  rejected=$(grep -Eic '^Prover result is: (Invalid|Unknown|Timeout|Out ?of ?memory|Step ?limit)' "$log" || true)
  echo "prover=$p exit=$status goals=$goals valid=$valid rejected=$rejected seconds=$(($(date +%s) - start))"
  [ "$goals" -gt 0 ] || return 1
  [ "$status" = 0 ] && [ "$valid" = "$goals" ] && return 0
  [ "$status" = 2 ] && [ "$rejected" -gt 0 ] &&
    [ $((valid + rejected)) = "$goals" ] && return "$VU_PROOF_REJECTED"
  return 1
}

echo "== proofs"
worst=0
for p in alt-ergo z3; do
  s=0
  prove "$p" || s=$?
  case "$s" in
  0) ;;
  "$VU_PROOF_REJECTED") [ "$worst" = 0 ] && worst=$s ;;
  *) worst=1 ;;
  esac
done
if [ "$worst" != 0 ]; then
  echo "proof status: $([ "$worst" = "$VU_PROOF_REJECTED" ] && echo rejected || echo error)"
  exit "$worst"
fi
echo "proof status: all goals valid for alt-ergo and z3"

echo "== extraction"
why3 extract -L "$src" -D c -D "$src/vu.drv" -o "$VU_OUT/vu.c" vu.Vu
echo "vu.c: $(wc -l <"$VU_OUT/vu.c") lines, sha256 $(sha256sum "$VU_OUT/vu.c" | cut -d' ' -f1)"

echo "== compilation"
cc -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror -I"$VU_HARNESS" \
  -c "$VU_OUT/vu.c" -o "$VU_OUT/vu.o"
ar rcs "$VU_OUT/libvu.a" "$VU_OUT/vu.o"
echo "libvu.a: ok"
