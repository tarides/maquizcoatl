#!/usr/bin/env bash
# build.sh: Isabelle-LLVM prototype of experiment #5, under run.sh's
# contract (see ../run.sh): checks VU.thy with Isabelle, which also
# exports vu.ll (export_llvm), checks the ABI of vu.ll against proto.h,
# compiles vu.ll with clang and the shim with cc, and leaves
# VU_OUT/libvu.a.
#
# Steps, each timed in the log:
#   1. copy ROOT and VU.thy to VU_OUT/src; with VU_NEGATIVE_CONTROL=1,
#      replace the lines between CLAMP-BEGIN and CLAMP-END (the clamp of
#      vu_char_len) by a definition that returns the callee's raw
#      result;
#   2. isabelle build of the session VU (a clean build, -c, so that
#      export_llvm writes vu.ll again). A failed build whose errors are
#      all failed proofs exits with VU_PROOF_REJECTED, any other failure
#      with 1;
#   3. ABI: the declare and define lines of vu.ll must equal
#      abi.expected, and layout.c must compile against proto.h;
#   4. compile vu.ll (clang) and shim.c (cc), and archive both.
#
# Environment (from run.sh): VU_HARNESS, VU_OUT, VU_JOBS,
# VU_NEGATIVE_CONTROL, VU_PROOF_REJECTED; VU_CACHE and PATH (isabelle,
# clang) from <cache>/env.sh. VU_JOBS is Isabelle's thread count (one
# session, so one job).

set -euo pipefail
: "${VU_HARNESS:?}" "${VU_OUT:?}" "${VU_JOBS:?}" "${VU_NEGATIVE_CONTROL:?}"
: "${VU_PROOF_REJECTED:?}" "${VU_CACHE:?}"
here=$(pwd)
src=$VU_OUT/src
mkdir -p "$src"

# shellcheck source=../lib.sh
. "$VU_HARNESS/lib.sh"
isa=$VU_CACHE/isabelle
afp=$isa/$(vu_pin .afp.version)/$(vu_pin .afp.version)
llvm_thys=$isa/isabelle_llvm/thys
session=VU

t0=$(date +%s)
step() { echo "== $* ($(($(date +%s) - t0)) s)"; }

step "versions"
isabelle version
echo "isabelle_llvm commit: $(git -C "$isa/isabelle_llvm" rev-parse HEAD)"
echo "afp: $(vu_pin .afp.version)"
clang --version | head -1
cc --version | head -1

step "1. source (negative control: $VU_NEGATIVE_CONTROL)"
cp ROOT "$src/ROOT"
if [ "$VU_NEGATIVE_CONTROL" = 1 ]; then
  [ "$(grep -c 'CLAMP-BEGIN\|CLAMP-END' VU.thy)" = 2 ] ||
    { echo "clamp markers not found"; exit 1; }
  sed '/CLAMP-BEGIN/,/CLAMP-END/c\
definition vu_clamp :: "32 word \\<Rightarrow> 32 word \\<Rightarrow> 32 word \\<Rightarrow> 32 word llM" where [llvm_inline]:\
  "vu_clamp r mn mx \\<equiv> Mreturn r"' VU.thy >"$src/VU.thy"
  diff VU.thy "$src/VU.thy" || true
else
  cp VU.thy "$src/VU.thy"
fi

step "2. isabelle build (proofs and export_llvm)"
set +e
isabelle build -c -j 1 -o threads="$VU_JOBS" -d "$afp/thys" -d "$llvm_thys" \
  -D "$src" >"$src/build.log" 2>&1
status=$?
set -e
cat "$src/build.log"
if [ "$status" != 0 ]; then
  # The build output keeps only the end of long error messages: the
  # session's own log has every error.
  isabelle build_log -H Error "$session" >"$src/errors.log" 2>&1 || true
  echo "-- errors of session $session"
  cat "$src/errors.log"
  # The first line of each error message starts with "*** " and a
  # capital letter. Goals ("*** goal", "***  1."), locations ("*** At
  # command") and the "A total of N subgoals" note are not messages. The
  # log lists an error under its theory and again under "Build errors".
  heads=$(grep -E '^\*\*\* [A-Z]' "$src/errors.log" |
    grep -v -E '^\*\*\* (At command|A total of [0-9]+ subgoals)' |
    sort -u || true)
  others=$(printf '%s\n' "$heads" | grep -v -E \
    '^\*\*\* Failed to (finish proof|apply (initial |terminal )?proof method)' || true)
  if [ -n "$heads" ] && [ -z "$others" ]; then
    echo "proof rejected: $(printf '%s\n' "$heads" | wc -l) failed proof(s), no other error"
    exit "$VU_PROOF_REJECTED"
  fi
  echo "isabelle build failed for another reason than a failed proof"
  exit 1
fi
ll=$src/vu.ll
[ -f "$ll" ] || { echo "export_llvm wrote no vu.ll"; exit 1; }
echo "generated vu.ll: $(wc -l <"$ll") lines, $(wc -c <"$ll") bytes," \
  "sha256 $(sha256sum "$ll" | cut -d' ' -f1)"

step "3. ABI checks"
# abi.expected is the hand-written mapping from proto.h to the LLVM that
# Isabelle-LLVM emits (trusted, listed in TRUSTED): int and unsigned int
# are i32, int64_t is i64 (x86-64 SysV, no extension attribute for
# 32-bit arguments); every pointer, including a client C function
# pointer (i8* in VU.thy) and void *, is a pointer: LLVM 23 reads the
# typed pointers of vu.ll as its opaque ptr, so pointee types do not
# reach the ABI. The pointee structs are the nested pairs of VU.thy,
# whose layout layout.c compares with proto.h. The verified functions
# are emitted as VU_<name> and renamed in step 4.
grep -E '^(declare|define) ' "$ll" | sed 's/ #0 {$//' >"$src/abi.txt"
diff "$here/abi.expected" "$src/abi.txt"
echo "abi: vu.ll declares and defines what abi.expected lists"
cflags=(-std=c11 -O2 -Wall -Wextra -Wpedantic -Werror)
cc "${cflags[@]}" -I "$VU_HARNESS" -c "$here/layout.c" -o "$src/layout.o"
echo "layout: same"

step "4. compile"
# The triple of vu.ll, so that clang does not override it.
triple=$(sed -n 's/^target triple = "\(.*\)"$/\1/p' "$ll")
clang --target="$triple" -O2 -Werror -c "$ll" -o "$VU_OUT/vu.o"
# export_llvm prefixes the names with the theory name: VU_vu_char_len.
renames=()
for f in vu_char_len vu_callout_step vu_i_apply vu_fold_all vu_get_slot \
  vu_set_slot; do
  renames+=(--redefine-sym "VU_$f=$f")
done
objcopy "${renames[@]}" "$VU_OUT/vu.o"
cc "${cflags[@]}" -I "$VU_HARNESS" -c "$here/shim.c" -o "$VU_OUT/shim.o"
ar rcs "$VU_OUT/libvu.a" "$VU_OUT/vu.o" "$VU_OUT/shim.o"
nm -g --defined-only "$VU_OUT/vu.o" "$VU_OUT/shim.o" |
  awk 'NF == 3 {print "exported:", $3}'
nm -u "$VU_OUT/vu.o" | awk '{print "external:", $2}'
step "done"
