#!/usr/bin/env bash
# build.sh: the RefinedC prototype of experiment #5 (run E), under
# run.sh's contract (see ../run.sh).
#
# 1. checks that vu_rc.h, without its [[rc::...]] attributes and its
#    head comment, is ../proto.h (whitespace aside), so that the
#    annotated copy cannot change the interface or the layout;
# 2. copies vu.c and vu_rc.h into a RefinedC project in VU_OUT/rc (with
#    VU_NEGATIVE_CONTROL=1 the clamp between the CLAMP markers is
#    removed; with 2 the upper bound test between the READ markers);
#    refuses a proof escape (rc::trust_me, rc::manual_proof, Admitted,
#    admit, Axiom) in vu.c;
# 3. refinedc check: RefinedC generates the Rocq model, specifications
#    and proofs and checks them with Rocq (Lithium automation, plus the
#    rc::tactics of vu.c). A failed proof ("Cannot solve side
#    condition", "Type system got stuck", an incomplete proof) exits
#    with VU_PROOF_REJECTED; any other failure with 1;
# 4. Print Assumptions of each proof: the standard axioms only;
# 5. the C compiler: vu.c into VU_OUT/libvu.a (normal run only).
set -euo pipefail
: "${VU_HARNESS:?}" "${VU_OUT:?}" "${VU_NEGATIVE_CONTROL:?}" "${VU_PROOF_REJECTED:?}"
: "${VU_OWN_OPAMROOT:?}"
export OPAMROOT=$VU_OWN_OPAMROOT OPAMCOLOR=never
rc() { opam exec --switch refinedc -- "$@"; }
here=$VU_HARNESS/refinedc

echo "refinedc source: $(git -C "$VU_CACHE/refinedc/src" rev-parse HEAD)"
rc refinedc --version
rc rocq --version | head -n 1
opam list --switch refinedc --installed --columns=name,version refinedc coq-lithium cerberus-lib rocq-iris rocq-stdpp 2>/dev/null

echo "== 1. vu_rc.h against proto.h"
strip_h() { sed -E 's/\[\[rc::[^]]*\]\]//g' "$1" | tr -d ' \t\n'; }
if [ "$(awk 'f; /^   byte for byte. \*\/$/ { f = 1 }' "$here/vu_rc.h" | sed -E 's/\[\[rc::[^]]*\]\]//g' | tr -d ' \t\n')" != \
  "$(tr -d ' \t\n' <"$VU_HARNESS/proto.h")" ]; then
  echo "vu_rc.h differs from proto.h beyond its rc attributes"
  exit 1
fi
echo "vu_rc.h is proto.h plus rc attributes"

echo "== 2. project (negative control: $VU_NEGATIVE_CONTROL)"
d=$VU_OUT/rc/vu_rc
rm -rf "$VU_OUT/rc"
mkdir -p "$d"
cp "$here/vu_rc.h" "$d/"
case "$VU_NEGATIVE_CONTROL" in
0) cp "$here/vu.c" "$d/vu.c" ;;
1) sed '/CLAMP-BEGIN/,/CLAMP-END/d' "$here/vu.c" >"$d/vu.c"; echo "negative control: clamp removed" ;;
2) sed '/READ-BEGIN/,/READ-END/d' "$here/vu.c" >"$d/vu.c"; echo "negative control: upper bound test of vu_get_subject_byte removed" ;;
*) echo "bad VU_NEGATIVE_CONTROL"; exit 1 ;;
esac
if [ "$VU_NEGATIVE_CONTROL" != 0 ] && cmp -s "$here/vu.c" "$d/vu.c"; then
  echo "markers not found in vu.c"; exit 1
fi
diff -u --label vu.c --label control/vu.c "$here/vu.c" "$d/vu.c" | sed 's/^/  /' || true
if grep -nE 'rc::trust_me|rc::manual_proof|\bAdmitted\b|\badmit\b|\bAxiom\b' "$d/vu.c"; then
  echo "proof escape in vu.c: refused"; exit 1
fi
(cd "$d" && rc refinedc init >/dev/null)

echo "== 3. refinedc check"
set +e
(cd "$d" && rc refinedc check vu.c) >"$VU_OUT/check.log" 2>&1
st=$?
set -e
grep -vE '^(at |Case distinction)' "$VU_OUT/check.log"
echo "refinedc status: $st"
if [ "$st" != 0 ]; then
  if grep -qE 'Cannot solve side condition|Type system got stuck|Attempt to save an incomplete proof' "$VU_OUT/check.log"; then
    echo "proof rejected"
    exit "$VU_PROOF_REJECTED"
  fi
  echo "RefinedC failed for another reason than a rejected proof"
  exit 1
fi

echo "== 4. assumptions"
{
  echo 'From refinedc.project.vu_rc.vu Require Import generated_code generated_spec.'
  for f in vu_char_len vu_callout_step vu_i_apply vu_fold_all vu_get_slot vu_set_slot vu_get_subject_byte; do
    echo "From refinedc.project.vu_rc.vu Require Import generated_proof_$f."
    echo "Print Assumptions type_$f."
  done
} >"$d/proofs/vu/assumptions.v"
(cd "$d" && rc dune build ./proofs/vu/generated_proof_vu_char_len.vo >/dev/null 2>&1 || true)
set +e
(cd "$d" && rc rocq compile -R _build/default/proofs/vu refinedc.project.vu_rc.vu proofs/vu/assumptions.v) >"$VU_OUT/assumptions.log" 2>&1
st=$?
set -e
cat "$VU_OUT/assumptions.log"
[ "$st" = 0 ] || { echo "Print Assumptions failed"; exit 1; }
if grep -E '^[A-Za-z_.]+ *:' "$VU_OUT/assumptions.log" | grep -vE \
  '^(FunctionalExtensionality\.functional_extensionality_dep|ClassicalEpsilon\.constructive_indefinite_description|Classical_Prop\.classic|PropExtensionality\.propositional_extensionality|ProofIrrelevance\.proof_irrelevance|Eqdep\.Eq_rect_eq\.eq_rect_eq|JMeq\.JMeq_eq)\b'; then
  echo "an assumption beyond the standard axioms"
  exit 1
fi
echo "assumptions: standard axioms only"
[ "$VU_NEGATIVE_CONTROL" != 0 ] && exit 0

echo "== 5. cc"
inc=$(rc sh -c 'echo "$OPAM_SWITCH_PREFIX/lib/refinedc/include"')
cc -std=gnu2x -O2 -Wall -Wextra -Werror -Wno-attributes -Wno-unused-parameter -Wno-unused-value \
  -I "$inc" -I "$d" -c "$d/vu.c" -o "$VU_OUT/vu.o"
ar rcs "$VU_OUT/libvu.a" "$VU_OUT/vu.o"
nm -g --defined-only "$VU_OUT/libvu.a" | awk '$3 ~ /^vu_/ { print "exported:", $3 }'
