#!/usr/bin/env bash
# build.sh: VST + CompCert prototype of experiment #5, under run.sh's
# contract (see ../run.sh): translates vu.c to Clight with clightgen,
# checks verif_vu.v with Rocq and VST, compiles vu.c with CompCert and
# leaves VU_OUT/libvu.a.
#
# Steps, each timed in the log:
#   1. copy vu.c and verif_vu.v to VU_OUT/src; with VU_NEGATIVE_CONTROL=1,
#      delete the lines between the CLAMP-BEGIN and CLAMP-END markers in
#      both: the clamp of vu_char_len in vu.c (which then returns the
#      callee's raw result) and the proof steps of its two branches in
#      verif_vu.v (the rest of the proof is unchanged); with
#      VU_NEGATIVE_CONTROL=2, delete the lines between READ-BEGIN and
#      READ-END instead: the upper bound check of vu_get_subject_byte,
#      which may then read past subject_len, and its proof step;
#   2. clightgen -normalize vu.c, then coqc on the generated vu.v;
#   3. coqc on verif_vu.v. A failure located inside a Proof ... Qed block
#      of verif_vu.v exits with VU_PROOF_REJECTED, any other failure with
#      1. The proof text must hold no admit, Admitted, Axiom, Parameter
#      or Hypothesis, and Print Assumptions must list only the axioms in
#      allowed_axioms below;
#   4. compile vu.c with CompCert (ccomp) and archive it.
#
# Environment (from run.sh): VU_HARNESS, VU_OUT, VU_NEGATIVE_CONTROL,
# VU_PROOF_REJECTED; VU_CACHE and VU_OWN_OPAMROOT from <cache>/env.sh
# (the opam switch "vst" lives there). VU_JOBS is not used: Rocq checks
# one file.

set -euo pipefail
: "${VU_HARNESS:?}" "${VU_OUT:?}" "${VU_NEGATIVE_CONTROL:?}"
: "${VU_PROOF_REJECTED:?}" "${VU_CACHE:?}" "${VU_OWN_OPAMROOT:?}"
here=$(pwd)
src=$VU_OUT/src
mkdir -p "$src"
export OPAMROOT=$VU_OWN_OPAMROOT OPAMCOLOR=never
vst=("$VU_CACHE/bin/opam" exec --switch vst --)

# The axioms Print Assumptions may list: Rocq's classical logic and
# extensionality axioms, which VST's soundness proof uses.
allowed_axioms="ClassicalDedekindReals.sig_not_dec
ClassicalDedekindReals.sig_forall_dec
prop_ext
functional_extensionality_dep
Classical_Prop.classic
Ensembles.Extensionality_Ensembles"

t0=$(date +%s)
step() { echo "== $* ($(($(date +%s) - t0)) s)"; }

step "versions"
"${vst[@]}" coqc --version | head -1
"${vst[@]}" clightgen -version | head -1
"${vst[@]}" ccomp -version | head -1
echo "VST $(cat "$("${vst[@]}" coqc -where)/user-contrib/VST/VERSION")"
cc --version | head -1

step "1. sources (negative control: $VU_NEGATIVE_CONTROL)"
for f in vu.c verif_vu.v; do
  [ "$(grep -c 'CLAMP-BEGIN\|CLAMP-END' "$f")" = 2 ] ||
    { echo "clamp markers not found in $f"; exit 1; }
  [ "$(grep -c 'READ-BEGIN\|READ-END' "$f")" = 2 ] ||
    { echo "read markers not found in $f"; exit 1; }
  if [ "$VU_NEGATIVE_CONTROL" = 1 ]; then
    sed '/CLAMP-BEGIN/,/CLAMP-END/d' "$f" >"$src/$f"
    diff "$f" "$src/$f" || true
  elif [ "$VU_NEGATIVE_CONTROL" = 2 ]; then
    sed '/READ-BEGIN/,/READ-END/d' "$f" >"$src/$f"
    diff "$f" "$src/$f" || true
  else
    cp "$f" "$src/$f"
  fi
done
if grep -nwE 'admit|Admitted|Axiom|Parameter|Hypothesis' "$src/verif_vu.v"; then
  echo "verif_vu.v holds an admitted proof or an assumption, refused"
  exit 1
fi
cd "$src"

step "2. clightgen and Clight check"
"${vst[@]}" clightgen -normalize -I "$VU_HARNESS" vu.c
echo "generated vu.v: $(wc -l <vu.v) lines, $(wc -c <vu.v) bytes," \
  "sha256 $(sha256sum vu.v | cut -d' ' -f1)"
"${vst[@]}" coqc -Q . VU vu.v

step "3. VST proofs"
set +e
"${vst[@]}" coqc -Q . VU verif_vu.v >check.log 2>&1
status=$?
set -e
cat check.log
if [ "$status" != 0 ]; then
  # The line of the first error in verif_vu.v (the File line just above
  # the first "Error"; the other File lines are warnings), and whether it
  # lies between a "Proof." and the "Qed." that closes it.
  line=$(awk '
    /^File / { f = $0 }
    /^Error/ { print f; exit }' check.log |
    sed -n 's/^File "\.\/verif_vu\.v", line \([0-9]*\),.*/\1/p')
  if [ -n "$line" ] &&
    awk -v l="$line" '
      /^Proof\./ { start = NR }
      /^(Qed|Defined)\./ { if (start && start <= l && l <= NR) found = 1; start = 0 }
      END { exit !found }' verif_vu.v; then
    echo "proof rejected (error at line $line, inside a proof)"
    exit "$VU_PROOF_REJECTED"
  fi
  echo "coqc failed outside a proof (status $status)"
  exit 1
fi
# Print Assumptions: the names between "Axioms:" and the end of the log.
axioms=$(sed -n '/^Axioms:/,$p' check.log |
  sed -n 's/^\([A-Za-z_][A-Za-z0-9_.]*\) :.*/\1/p' | sort -u)
[ -n "$axioms" ] || { echo "no Print Assumptions output"; exit 1; }
extra=$(comm -23 <(printf '%s\n' "$axioms") \
  <(printf '%s\n' "$allowed_axioms" | sort -u))
if [ -n "$extra" ]; then
  echo "unexpected axioms: $extra"
  exit 1
fi
echo "axioms: only the allowed ones ($(printf '%s\n' "$axioms" | wc -l))"

step "4. CompCert compile"
"${vst[@]}" ccomp -O -I "$VU_HARNESS" -c vu.c -o "$VU_OUT/vu.o"
ar rcs "$VU_OUT/libvu.a" "$VU_OUT/vu.o"
nm -g --defined-only "$VU_OUT/vu.o" | awk '{print "exported:", $3}'
echo "libvu.a: $(wc -c <"$VU_OUT/libvu.a") bytes," \
  "sha256 $(sha256sum "$VU_OUT/libvu.a" | cut -d' ' -f1)"
cd "$here"
step "done"
