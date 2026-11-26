#!/bin/bash
# Experiment #8 follow-up (issue #34, plans/08-discriminating-lemmas.md):
# the axiom/admit report.  Copied from experiment #9's axioms.sh
# (lab/09-representative-proof/axioms.sh); its F* case is dropped, since
# this experiment has no F* files.
#   BENCH_WORKDIR=<bench-workdir> axioms.sh <tool> <run-id>     tool: rocq | verus
# rocq: a clean build of Fold FoldProof Absent Desugar AbsentMono
# AbsentProof, then "Print Assumptions" of FoldProof.sharp_s_sym,
# AbsentProof.absent_desugar_eq, and (from run 5, decision 8)
# AbsentProof.m_term and AbsentProof.absent_desugar_total (expected:
# "Closed under the global context"), and a scan of the sources for Admitted, admit, Axiom,
# Parameter, Conjecture, Hypothesis and Abort (any hit is printed with
# its file and line; comments are not stripped, so hits are read by hand).
# verus: a full check of the crate lib.rs (the eight files of verus/; no
# --verify-* option, so every item is checked; expected "0 errors"), a
# second full check with --no-cheating (refuses assume, admit,
# external_body and the like), and a scan of the crate's sources for
# assume, admit, external_body, verifier::external, assume_specification,
# exec_allows_no_decreases_clause, no_verify and rlimit (hits printed with
# file and line; comments are not stripped).  It also prints the version
# of the Z3 that Verus runs: the z3 binary bundled next to verus, or
# $VERUS_Z3_PATH when set (Verus's own lookup).
# Untimed: nice -n 10, CPUs 8-11.  Output: <exp>/out/<run-id>/<tool>/axioms.txt.
# Prints no hostnames, addresses or absolute paths.
set -euo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory}"
T=${1:?tool} RID=${2:?run-id}
CACHE=$BENCH_WORKDIR/cache; EXP=$BENCH_WORKDIR/exp/08-discriminating-lemmas
L=$EXP/repo/lab/08-discriminating-lemmas
OUT=$EXP/out/$RID/$T; mkdir -p "$OUT"
. "$CACHE/env.sh"
case $T in
rocq)
  FILES="Fold FoldProof Absent Desugar AbsentMono AbsentProof"
  B=$EXP/build/rocq/$RID-axioms; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  for f in $FILES; do cp "$L/rocq/$f.v" .; done
  printf 'From S Require FoldProof AbsentProof.\nPrint Assumptions FoldProof.sharp_s_sym.\nPrint Assumptions AbsentProof.absent_desugar_eq.\nPrint Assumptions AbsentProof.m_term.\nPrint Assumptions AbsentProof.absent_desugar_total.\n' > Axioms.v
  {
    echo "== rocq --version"; opam exec --switch provers -- rocq --version
    for f in $FILES Axioms; do
      echo "== rocq compile -R . S $f.v"
      nice -n 10 taskset -c 8-11 opam exec --switch provers -- rocq compile -R . S "$f.v" 2>&1
    done
    echo "== scan (Admitted|admit|Axiom|Parameter|Conjecture|Hypothesis|Abort) in $FILES"
    for f in $FILES; do
      grep -nwE 'Admitted|admit|Axiom|Axioms|Parameter|Parameters|Conjecture|Hypothesis|Hypotheses|Abort' "$f.v" \
        | sed "s|^|$f.v:|" || true
    done
    echo "== end of scan"
  } > "$OUT/axioms.txt" 2>&1
  cat "$OUT/axioms.txt" ;;
verus)
  . "$CACHE/verus-env.sh"
  FILES="lib fold fold_proof absent desugar absent_mono absent_proof cases"
  B=$EXP/build/verus/$RID-axioms; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  for f in $FILES; do cp "$L/verus/$f.rs" .; done
  {
    echo "== verus --version"; verus --version
    Z3=${VERUS_Z3_PATH:-$(dirname "$(command -v verus)")/z3}
    echo "== z3 --version (${VERUS_Z3_PATH:+VERUS_Z3_PATH}${VERUS_Z3_PATH:-bundled with verus})"; "$Z3" --version
    for opt in "" "--no-cheating"; do
      echo "== verus --crate-type=lib --num-threads 4 $opt lib.rs"
      rc=0; nice -n 10 taskset -c 8-11 verus --crate-type=lib --num-threads 4 $opt lib.rs 2>&1 || rc=$?
      echo "exit code $rc"
    done
    echo "== scan (assume|admit|external_body|verifier::external|assume_specification|exec_allows_no_decreases_clause|no_verify|rlimit) in $FILES"
    for f in $FILES; do
      grep -nE 'assume|admit|external_body|verifier::external|assume_specification|exec_allows_no_decreases_clause|no_verify|rlimit' "$f.rs" \
        | sed "s|^|$f.rs:|" || true
    done
    echo "== end of scan"
  } > "$OUT/axioms.txt" 2>&1
  sed -i "s|$BENCH_WORKDIR|<bench-workdir>|g; s|$HOME|~|g" "$OUT/axioms.txt"
  cat "$OUT/axioms.txt" ;;
*) echo "unknown tool $T" >&2; exit 2 ;;
esac
