#!/bin/bash
# Experiment #9: three clean full checks of one tool's definition files
# (rocq and fstar: one file at a time; verus: the whole crate lib.rs as
# one unit, VERUS_THREADS verifier threads, default 7), pinned to CPUS (default 28-31,60-63, one L3
# complex), /usr/bin/time -v, 16G memory cap (cgroup v2 MemoryMax, as
# rocq/rocq.sh time: OCaml 5 tools reserve more address space than
# ulimit -v 16G allows), load average before each check.  Adapted from
# experiment #8's timed.sh and check.sh.  Run under flock <exp>/timed.lock.
#   BENCH_WORKDIR=<bench-workdir> timed.sh <tool> <run-id>     tool: rocq | fstar | verus
# rocq: ROCQ_FILES (default the five definition files, as rocq/rocq.sh time
# of run 1; run 4 added this case so that Rocq's time.tsv has the user and
# system columns and its time.log one "Checked" line per file and run).
# fstar: FSTAR_FILES (default the five definition files; run 7 passes the
# definitions and the proof modules ProofA ProofSem ProofSim Proof, in
# dependency order, each file checked against the .checked files of the
# ones before it).
# Output: <exp>/out/<run-id>/<tool>/time.{tsv,load,log,<r>.<file>}.
# time.log holds the checker's output (rocq: one "Checked <file>.v" line
# per file and run, printed by chk after rocq compile succeeds; fstar: one "Verified module" line
# per file and run, 15 in all; verus: one "verification results" line
# per run, 3 in all, since Verus checks the crate lib.rs as one unit);
# time.tsv's columns are run, file, wall clock, max RSS (kB), user time
# (s), system time (s) (user and system added in correction 3, entry 8;
# run 3 ran Verus on its default, 7 threads under the 8 pinned CPUs,
# now passed explicitly as --num-threads); time.tsv, time.load and
# time.log are copied to the run's lab/results/<entry>-raw/<tool>/ raw set.
# Prints no hostnames, addresses or absolute paths.
set -euo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory}"
T=${1:?tool} RID=${2:?run-id}
CACHE=$BENCH_WORKDIR/cache; EXP=$BENCH_WORKDIR/exp/09-representative-proof
L=$EXP/repo/lab/09-representative-proof
OUT=$EXP/out/$RID/$T; mkdir -p "$OUT"
CPUS=${CPUS:-28-31,60-63}
. "$CACHE/env.sh"
case $T in
  rocq)  DEFS=${ROCQ_FILES:-Syntax Sem Compile Vm Statement}
         fresh() { rm -rf "$1"; mkdir -p "$1"; cp "$L"/rocq/*.v "$1/"; }
         chk() { opam exec --switch provers -- rocq compile -R . S "$1.v" && echo "Checked $1.v"; } ;;
  fstar) DEFS=${FSTAR_FILES:-Syntax Sem Compile Vm Statement}
         fresh() { rm -rf "$1"; mkdir -p "$1/cache"; for f in $DEFS; do cp "$L/fstar/$f.fst" "$1/"; done; }
         chk() { fstar.exe --cache_checked_modules --cache_dir cache --z3version 5.3.0 "$1.fst"; } ;;
  verus) DEFS="lib"
         . "$CACHE/verus-env.sh"
         fresh() { rm -rf "$1"; mkdir -p "$1"; cp "$L"/verus/{lib,syntax,sem,compile,vm,statement}.rs "$1/"; }
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
