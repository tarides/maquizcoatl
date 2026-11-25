#!/bin/bash
# Experiment #9, done-criterion 1 (plan step 5): the axiom/admit report.
#   BENCH_WORKDIR=<bench-workdir> axioms.sh <tool> <run-id>     tool: rocq | fstar | verus
# rocq: a clean build of every .v file of rocq/ that the proof needs
# (definitions, then ProofA, ProofSem, ProofSim, Proof), then
# "Print Assumptions main_theorem." (expected: "Closed under the global
# context"), and a scan of the sources for Admitted, admit, Axiom,
# Parameter, Conjecture, Hypothesis and Abort (any hit is printed with
# its file and line; comments are not stripped, so hits are read by hand).
# fstar (run 7): a clean check of the definitions and the proof modules
# (ProofA, ProofSem, ProofSim, Proof), one file at a time in dependency
# order, with --admit_smt_queries false given explicitly (it is the
# default) and Z3 5.3.0, then a scan of the sources for admit, assume
# (also "assume val"), magic, --admit_smt_queries true, --lax and #lang-
# (hits printed with file and line; comments are not stripped).
# verus (run 10, plan step 5): a full check of the crate lib.rs
# (definitions and the proof modules proof_a, proof_sem, proof_sim,
# proof; no --verify-* option, so every item is checked; expected
# "0 errors"), a second full check with --no-cheating (refuses assume,
# admit, external_body and the like), and a scan of the crate's sources
# for assume, admit, external_body, verifier::external,
# assume_specification, exec_allows_no_decreases_clause, no_verify and
# rlimit (hits printed with file and line; comments are not stripped).
# From correction 7 (run-10 review) it also prints the version of the Z3
# that Verus runs: the z3 binary bundled next to verus in the release
# directory, or $VERUS_Z3_PATH when set (Verus's own lookup).
# Untimed: nice -n 10, CPUs 4-7.  Output: <exp>/out/<run-id>/<tool>/axioms.txt.
# Prints no hostnames, addresses or absolute paths.
set -euo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory}"
T=${1:?tool} RID=${2:?run-id}
CACHE=$BENCH_WORKDIR/cache; EXP=$BENCH_WORKDIR/exp/09-representative-proof
L=$EXP/repo/lab/09-representative-proof
OUT=$EXP/out/$RID/$T; mkdir -p "$OUT"
. "$CACHE/env.sh"
case $T in
rocq)
  FILES="Syntax Sem Compile Vm Statement ProofA ProofSem ProofSim Proof"
  B=$EXP/build/rocq/$RID-axioms; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  for f in $FILES; do cp "$L/rocq/$f.v" .; done
  printf 'From S Require Import Proof.\nPrint Assumptions main_theorem.\n' > Axioms.v
  {
    echo "== rocq --version"; opam exec --switch provers -- rocq --version
    for f in $FILES Axioms; do
      echo "== rocq compile -R . S $f.v"
      nice -n 10 taskset -c 4-7 opam exec --switch provers -- rocq compile -R . S "$f.v" 2>&1
    done
    echo "== scan (Admitted|admit|Axiom|Parameter|Conjecture|Hypothesis|Abort) in $FILES"
    for f in $FILES; do
      grep -nwE 'Admitted|admit|Axiom|Axioms|Parameter|Parameters|Conjecture|Hypothesis|Hypotheses|Abort' "$f.v" \
        | sed "s|^|$f.v:|" || true
    done
    echo "== end of scan"
  } > "$OUT/axioms.txt" 2>&1
  cat "$OUT/axioms.txt" ;;
fstar)
  FILES="Syntax Sem Compile Vm Statement ProofA ProofSem ProofSim Proof"
  B=$EXP/build/fstar/$RID-axioms; rm -rf "$B"; mkdir -p "$B/cache"; cd "$B"
  for f in $FILES; do cp "$L/fstar/$f.fst" .; done
  {
    echo "== fstar.exe --version"; fstar.exe --version
    for f in $FILES; do
      echo "== fstar.exe --cache_checked_modules --cache_dir cache --z3version 5.3.0 --admit_smt_queries false $f.fst"
      nice -n 10 taskset -c 4-7 fstar.exe --cache_checked_modules --cache_dir cache \
        --z3version 5.3.0 --admit_smt_queries false "$f.fst" 2>&1
    done
    echo "== scan (admit|assume|magic|admit_smt_queries true|--lax|#lang-) in $FILES"
    for f in $FILES; do
      grep -nE '\badmit|\bassume\b|\bmagic\b|admit_smt_queries[[:space:]]+true|--lax|#lang-' "$f.fst" \
        | sed "s|^|$f.fst:|" || true
    done
    echo "== end of scan"
  } > "$OUT/axioms.txt" 2>&1
  sed -i "s|$BENCH_WORKDIR|<bench-workdir>|g" "$OUT/axioms.txt"
  cat "$OUT/axioms.txt" ;;
verus)
  . "$CACHE/verus-env.sh"
  FILES="lib syntax sem compile vm statement proof_a proof_sem proof_sim proof"
  B=$EXP/build/verus/$RID-axioms; rm -rf "$B"; mkdir -p "$B"; cd "$B"
  for f in $FILES; do cp "$L/verus/$f.rs" .; done
  {
    echo "== verus --version"; verus --version
    Z3=${VERUS_Z3_PATH:-$(dirname "$(command -v verus)")/z3}
    echo "== z3 --version (${VERUS_Z3_PATH:+VERUS_Z3_PATH}${VERUS_Z3_PATH:-bundled with verus})"; "$Z3" --version
    for opt in "" "--no-cheating"; do
      echo "== verus --crate-type=lib --num-threads 4 $opt lib.rs"
      rc=0; nice -n 10 taskset -c 4-7 verus --crate-type=lib --num-threads 4 $opt lib.rs 2>&1 || rc=$?
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
