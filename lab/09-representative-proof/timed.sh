#!/bin/bash
# Experiment #9: three clean full checks of one tool's definition files,
# one file at a time, pinned to CPUS (default 28-31,60-63, one L3
# complex), /usr/bin/time -v, 16G memory cap (cgroup v2 MemoryMax, as
# rocq/rocq.sh time: OCaml 5 tools reserve more address space than
# ulimit -v 16G allows), load average before each check.  Adapted from
# experiment #8's timed.sh and check.sh.  Run under flock <exp>/timed.lock.
#   BENCH_WORKDIR=<bench-workdir> timed.sh <tool> <run-id>     tool: fstar
# (Rocq's timed checks are rocq/rocq.sh time, run 1.)
# Output: <exp>/out/<run-id>/<tool>/time.{tsv,load,log,<r>.<file>}.
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
  fstar) DEFS="Syntax Sem Compile Vm Statement"
         fresh() { rm -rf "$1"; mkdir -p "$1/cache"; cp "$L"/fstar/{Syntax,Sem,Compile,Vm,Statement}.fst "$1/"; }
         chk() { fstar.exe --cache_checked_modules --cache_dir cache --z3version 5.3.0 "$1.fst"; } ;;
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
    printf '%s\t%s\t%s\t%s\n' "$r" "$f" \
      "$(sed -n 's/.*Elapsed (wall clock) time (h:mm:ss or m:ss): //p' "$OUT/time.$r.$f")" \
      "$(sed -n 's/.*Maximum resident set size (kbytes): //p' "$OUT/time.$r.$f")" >> "$OUT/time.tsv"
  done
done
cat "$OUT/time.tsv"
