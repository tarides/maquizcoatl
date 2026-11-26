#!/bin/bash
# Experiment #8 follow-up (issue #34, plans/08-discriminating-lemmas.md):
# three clean full checks of one tool's files, pinned to CPUS (default
# 24-27,56-59), /usr/bin/time -v, 16G memory cap (cgroup v2 MemoryMax:
# OCaml 5 tools reserve more address space than ulimit -v 16G allows),
# load average before each check.  Copied from experiment #9's timed.sh
# (lab/09-representative-proof/timed.sh); its F* case is dropped, since
# this experiment has no F* files.  Run under flock <exp>/timed.lock.
#   BENCH_WORKDIR=<bench-workdir> timed.sh <tool> <run-id>     tool: rocq | verus
# rocq: ROCQ_FILES (default Fold FoldProof Absent Desugar AbsentMono
# AbsentProof, in dependency order), one file at a time.
# verus: the whole crate lib.rs (the eight files of verus/) as one unit,
# VERUS_THREADS verifier threads (default 7, under the 8 pinned CPUs);
# also writes version.txt, the output of verus --version and of the z3
# Verus runs (the binary bundled next to verus, or $VERUS_Z3_PATH).
# Output: <exp>/out/<run-id>/<tool>/time.{tsv,load,log,<r>.<file>}.
# time.log holds the checker's output (rocq: one "Checked <file>.v" line
# per file and run, printed by chk after rocq compile succeeds; verus: one
# "verification results" line per run).  time.tsv's columns are run,
# file, wall clock, max RSS (kB), user time (s), system time (s).
# Prints no hostnames, addresses or absolute paths.
set -euo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory}"
T=${1:?tool} RID=${2:?run-id}
CACHE=$BENCH_WORKDIR/cache; EXP=$BENCH_WORKDIR/exp/08-discriminating-lemmas
L=$EXP/repo/lab/08-discriminating-lemmas
OUT=$EXP/out/$RID/$T; mkdir -p "$OUT"
CPUS=${CPUS:-24-27,56-59}
. "$CACHE/env.sh"
case $T in
  rocq)  DEFS=${ROCQ_FILES:-Fold FoldProof Absent Desugar AbsentMono AbsentProof}
         fresh() { rm -rf "$1"; mkdir -p "$1"; cp "$L"/rocq/*.v "$1/"; }
         chk() { opam exec --switch provers -- rocq compile -R . S "$1.v" && echo "Checked $1.v"; } ;;
  verus) DEFS="lib"
         . "$CACHE/verus-env.sh"
         { verus --version; "${VERUS_Z3_PATH:-$(dirname "$(command -v verus)")/z3}" --version; } > "$OUT/version.txt" 2>&1
         fresh() { rm -rf "$1"; mkdir -p "$1"; cp "$L"/verus/{lib,fold,fold_proof,absent,desugar,absent_mono,absent_proof,cases}.rs "$1/"; }
         chk() { verus --crate-type=lib --num-threads "${VERUS_THREADS:-7}" "$1.rs"; } ;;
  *) echo "unknown tool $T" >&2; exit 2 ;;
esac
export -f chk
for r in 1 2 3; do
  B=$EXP/build/$T/$RID-t$r; fresh "$B"; cd "$B"
  for f in $DEFS; do
    echo "$r $f $(uptime | sed 's/.*load average: //')" >> "$OUT/time.load"
    systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 \
      /usr/bin/time -v -o "$OUT/time.$r.$f" \
        taskset -c "$CPUS" bash -c "chk $f" >> "$OUT/time.log" 2>&1
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$r" "$f" \
      "$(sed -n 's/.*Elapsed (wall clock) time (h:mm:ss or m:ss): //p' "$OUT/time.$r.$f")" \
      "$(sed -n 's/.*Maximum resident set size (kbytes): //p' "$OUT/time.$r.$f")" \
      "$(sed -n 's/.*User time (seconds): //p' "$OUT/time.$r.$f")" \
      "$(sed -n 's/.*System time (seconds): //p' "$OUT/time.$r.$f")" >> "$OUT/time.tsv"
  done
done
cat "$OUT/time.tsv"
