#!/usr/bin/env bash
# build.sh: the CN prototype of experiment #5 (run E), under run.sh's
# contract (see ../run.sh).
#
# Copies vu.c and ../proto.h into VU_OUT (with VU_NEGATIVE_CONTROL=1 the
# clamp between the CLAMP markers is removed; with 2 the upper bound
# test between the READ markers), checks that the only proof escapes are
# the three trusted shims, runs `cn verify` (Z3 4.15.3 of the F* bundle,
# VU_WHY3_Z3; state files in VU_OUT/cn-state) and, for a normal run,
# compiles vu.c with the C compiler into VU_OUT/libvu.a.
#
# Exit status: 0 when every function is verified and the library built;
# VU_PROOF_REJECTED when CN reports a failed function ("-- fail") and no
# other error; 1 otherwise.
set -euo pipefail
: "${VU_HARNESS:?}" "${VU_OUT:?}" "${VU_NEGATIVE_CONTROL:?}" "${VU_PROOF_REJECTED:?}"
: "${VU_OWN_OPAMROOT:?}" "${VU_WHY3_Z3:?}"
export OPAMROOT=$VU_OWN_OPAMROOT OPAMCOLOR=never
PATH="$(dirname "$(readlink -f "$VU_WHY3_Z3")"):$PATH"
cn() { opam exec --switch cn -- cn "$@"; }

echo "cn source: $(git -C "$VU_CACHE/cn/src" rev-parse HEAD)"
opam show --switch cn --field=pin cerberus-lib
z3 --version

d=$VU_OUT/src
rm -rf "$d"
mkdir -p "$d" "$VU_OUT/cn-state"
cp "$VU_HARNESS/proto.h" "$d/"
case "$VU_NEGATIVE_CONTROL" in
0) cp vu.c "$d/vu.c" ;;
1) sed '/CLAMP-BEGIN/,/CLAMP-END/d' vu.c >"$d/vu.c"
   echo "negative control: clamp removed" ;;
2) sed '/READ-BEGIN/,/READ-END/d' vu.c >"$d/vu.c"
   echo "negative control: upper bound test of vu_get_subject_byte removed" ;;
*) echo "bad VU_NEGATIVE_CONTROL"; exit 1 ;;
esac
cmp -s vu.c "$d/vu.c" && [ "$VU_NEGATIVE_CONTROL" != 0 ] &&
  { echo "markers not found in vu.c"; exit 1; }
diff -u --label vu.c --label control/vu.c vu.c "$d/vu.c" | sed 's/^/  /' || true

# Proof escapes, in the annotations (/*@ ... @*/): "trusted" only on the
# three shims; no assume or lemma.
n=$(grep -c '/\*@ *trusted' "$d/vu.c" || true)
[ "$n" = 3 ] || { echo "expected 3 trusted shims, found $n"; exit 1; }
if awk '/\/\*@/,/@\*\//' "$d/vu.c" | grep -nE '\b(assume|lemma|trusted)\b' | grep -v '/\*@ *trusted;'; then
  echo "proof escape outside the shims: refused"; exit 1
fi

set +e
(cd "$d" && cn verify -I . --output-dir="$VU_OUT/cn-state" vu.c) 2>&1 | tee "$VU_OUT/cn.log"
rc=${PIPESTATUS[0]}
set -e
echo "cn status: $rc"
if [ "$rc" != 0 ]; then
  if grep -q -- '-- fail$' "$VU_OUT/cn.log" &&
    ! grep -qiE 'type error|parse|unexpected token|unsupported' "$VU_OUT/cn.log"; then
    echo "proof rejected"
    exit "$VU_PROOF_REJECTED"
  fi
  echo "CN failed for another reason than a rejected proof"
  exit 1
fi
grep -q -- '-- fail$' "$VU_OUT/cn.log" && { echo "a function failed but cn returned 0"; exit 1; }
echo "CN: all functions verified"
[ "$VU_NEGATIVE_CONTROL" != 0 ] && exit 0

cc -std=c11 -O2 -Wall -Wextra -Werror -I "$d" -c "$d/vu.c" -o "$VU_OUT/vu.o"
ar rcs "$VU_OUT/libvu.a" "$VU_OUT/vu.o"
nm -g --defined-only "$VU_OUT/libvu.a" | awk '$3 ~ /^vu_/ { print "exported:", $3 }'
