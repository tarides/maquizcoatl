#!/usr/bin/env bash
# build.sh: Bedrock2 prototype of experiment #5 (run G), under run.sh's
# contract (see ../run.sh): checks VU.v with Rocq against coqutil and
# bedrock2, prints its C code with Bedrock2's ToCString, compiles it with
# the trusted shim and ABI wrapper, and leaves VU_OUT/libvu.a.
#
# Steps, each timed in the log:
#   1. copy VU.v to VU_OUT/src; with VU_NEGATIVE_CONTROL=1, delete the
#      lines between CLAMP-BEGIN and CLAMP-END (the clamp of
#      b2_vu_char_len, which then returns the callee's raw result); with
#      VU_NEGATIVE_CONTROL=2, delete the lines between READ-BEGIN and
#      READ-END (the upper bound test of b2_vu_get_subject_byte, which
#      may then read past subject_len). The proof scripts are unchanged.
#      VU.v may hold no admit, Admitted, Axiom, Parameter or Hypothesis;
#   2. rocq compile VU.v. A failure located inside a Proof ... Qed block
#      exits with VU_PROOF_REJECTED, any other failure with 1;
#   3. Print Assumptions of the seven theorems (Check.v): each must be
#      closed under the global context;
#   4. print the C code (ToC.v, ToCString) into vu.c with bytedump.py;
#   5. compile vu.c (with b2ext.h, whose declarations the compiler checks
#      against the generated definitions), abi.c, shim.c and layout.c,
#      and archive them.
#
# Environment (from run.sh): VU_HARNESS, VU_OUT, VU_NEGATIVE_CONTROL,
# VU_PROOF_REJECTED; VU_CACHE and PATH (rocq, from the provers switch)
# from <cache>/env.sh. VU_JOBS is not used: Rocq checks one file.

set -euo pipefail
: "${VU_HARNESS:?}" "${VU_OUT:?}" "${VU_NEGATIVE_CONTROL:?}"
: "${VU_PROOF_REJECTED:?}" "${VU_CACHE:?}"
here=$(pwd)
src=$VU_OUT/src
mkdir -p "$src"
b2=$VU_CACHE/bedrock2/src
flags=(-Q "$b2/deps/coqutil/src/coqutil" coqutil -Q "$b2/bedrock2/src/bedrock2" bedrock2
  -Q "$src" VU)

t0=$(date +%s)
step() { echo "== $* ($(($(date +%s) - t0)) s)"; }

step "versions"
rocq --version | head -1
echo "bedrock2 commit: $(git -C "$b2" rev-parse HEAD)"
echo "coqutil commit: $(git -C "$b2/deps/coqutil" rev-parse HEAD)"
cc --version | head -1

step "1. source (negative control: $VU_NEGATIVE_CONTROL)"
[ "$(grep -c 'CLAMP-BEGIN\|CLAMP-END' VU.v)" = 2 ] ||
  { echo "clamp markers not found"; exit 1; }
[ "$(grep -c 'READ-BEGIN\|READ-END' VU.v)" = 4 ] ||
  { echo "read markers not found"; exit 1; }
case "$VU_NEGATIVE_CONTROL" in
0) cp VU.v "$src/VU.v" ;;
1) sed '/CLAMP-BEGIN/,/CLAMP-END/d' VU.v >"$src/VU.v" ;;
2) sed '/READ-BEGIN/,/READ-END/d' VU.v >"$src/VU.v" ;;
*) echo "bad VU_NEGATIVE_CONTROL"; exit 1 ;;
esac
diff VU.v "$src/VU.v" || true
cp ToC.v Check.v "$src/"
if grep -nwE 'admit|Admitted|Axiom|Parameter|Hypothesis|Hypotheses' "$src/VU.v"; then
  echo "VU.v holds an admitted proof or an assumption, refused"
  exit 1
fi
cd "$src"

step "2. Rocq proofs"
set +e
rocq compile -q "${flags[@]}" VU.v >check.log 2>&1
status=$?
set -e
grep -v '^\[\|Warning\|deprecated\|abbreviation' check.log || true
if [ "$status" != 0 ]; then
  # The line of the first error in VU.v and whether it lies between a
  # "Proof." and the "Qed." that closes it.
  line=$(awk '/^File / { f = $0 } /^Error/ { print f; exit }' check.log |
    sed -n 's/^File "\.\/VU\.v", line \([0-9]*\),.*/\1/p')
  if [ -n "$line" ] &&
    awk -v l="$line" '
      /^  Proof\./ { start = NR }
      /^  (Qed|Defined)\./ { if (start && start <= l && l <= NR) found = 1; start = 0 }
      END { exit !found }' VU.v; then
    echo "proof rejected (error at line $line, inside a proof)"
    exit "$VU_PROOF_REJECTED"
  fi
  echo "rocq failed outside a proof (status $status)"
  exit 1
fi
echo "VU.v: all proofs checked"

step "3. assumptions"
rocq compile -q "${flags[@]}" Check.v >assumptions.log 2>&1
cat assumptions.log
n=$(grep -c '^Closed under the global context' assumptions.log || true)
[ "$n" = 7 ] || { echo "expected 7 closed theorems, found $n"; exit 1; }
echo "assumptions: none (7 theorems closed under the global context)"
[ "$VU_NEGATIVE_CONTROL" != 0 ] && { step "done"; exit 0; }

step "4. C code (ToCString)"
rocq compile -q "${flags[@]}" ToC.v
COQFLAGS="${flags[*]}" python3 -I "$b2/etc/bytedump.py" VU.ToC.vu_c_bytes >vu.c
echo "generated vu.c: $(wc -l <vu.c) lines, sha256 $(sha256sum vu.c | cut -d' ' -f1)"
grep -E '^br_word_t b2_' vu.c

step "5. compile"
cflags=(-std=c11 -O2 -Wall -Wextra -Werror -I "$VU_HARNESS" -I "$here")
# The generated code: unused locals and parameters are Bedrock2's.
cc "${cflags[@]}" -Wno-unused-parameter -Wno-unused-variable \
  -Wno-unused-but-set-variable -include b2ext.h -c vu.c -o "$VU_OUT/vu.o"
for f in abi shim layout; do
  cc "${cflags[@]}" -Wpedantic -c "$here/$f.c" -o "$VU_OUT/$f.o"
done
ar rcs "$VU_OUT/libvu.a" "$VU_OUT/vu.o" "$VU_OUT/abi.o" "$VU_OUT/shim.o"
nm -g --defined-only "$VU_OUT/libvu.a" | awk 'NF == 3 {print "exported:", $3}'
nm -u "$VU_OUT/vu.o" | awk '{print "external:", $2}'
cd "$here"
step "done"
