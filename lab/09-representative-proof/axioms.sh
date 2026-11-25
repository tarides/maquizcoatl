#!/bin/bash
# Experiment #9, done-criterion 1 (plan step 5): the axiom/admit report.
#   BENCH_WORKDIR=<bench-workdir> axioms.sh <tool> <run-id>     tool: rocq
# rocq: a clean build of every .v file of rocq/ that the proof needs
# (definitions, then ProofA, ProofSem, ProofSim, Proof), then
# "Print Assumptions main_theorem." (expected: "Closed under the global
# context"), and a scan of the sources for Admitted, admit, Axiom,
# Parameter, Conjecture, Hypothesis and Abort (any hit is printed with
# its file and line; comments are not stripped, so hits are read by hand).
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
*) echo "unknown tool $T" >&2; exit 2 ;;
esac
