#!/bin/bash
# Experiment #9, Rocq M1.  BENCH_WORKDIR=<bench-workdir> rocq/rocq.sh <phase> <run-id>
# phases: build  check the definitions, extract, compile the driver,
#                run it on the fragment's cases and the extra probes
#                (untimed: nice -n 10, CPUs 4-7)
#         time   three clean checks of the definitions (Syntax, Sem,
#                Compile, Vm, Statement), one at a time, pinned to
#                CPUS (default 28-31,60-63), /usr/bin/time -v, 16G memory
#                cap (cgroup v2 MemoryMax: OCaml 5 reserves more address
#                space than ulimit -v 16G allows)
# The proof files (ProofA, ProofSem, ProofSim, Proof; run 4) are checked by
# ../axioms.sh rocq and timed by ../timed.sh rocq (ROCQ_FILES), not here.
# Prints no hostnames, addresses or absolute paths.
set -euo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory}"
PHASE=${1:?phase} RID=${2:?run-id}
CACHE=$BENCH_WORKDIR/cache; EXP=$BENCH_WORKDIR/exp/09-representative-proof
L=$EXP/repo/lab/09-representative-proof; E06=$EXP/repo/lab/06-spec-speed/rocq
OUT=$EXP/out/$RID/rocq; mkdir -p "$OUT"
. "$CACHE/env.sh"
X="opam exec --switch provers --"
DEFS="Syntax Sem Compile Vm Statement"
fresh() { rm -rf "$1"; mkdir -p "$1"; cp "$L"/rocq/*.v "$L/rocq/main.ml" "$1/"
          cp "$E06/Spec2.v" "$1/"; cp "$1/TablesStub.v" "$1/Tables.v"; }
case $PHASE in
build)
  B=$EXP/build/rocq/$RID; fresh "$B"; cd "$B"
  U="nice -n 10 taskset -c 4-7"
  $X rocq --version > "$OUT/version.txt" 2>&1
  { for f in $DEFS Tables Spec2 Extract ExtractSpec2; do
      echo "== $f"; $U $X rocq compile -R . S "$f.v"; done
    $U $X ocamlfind ocamlopt -package unix -linkpkg frag.mli frag.ml spec2.mli spec2.ml main.ml -o rocq_e09
  } > "$OUT/build.log" 2>&1
  for c in fragment extra; do $U ./rocq_e09 "$L/cases/$c.tsv" > "$OUT/$c.verdicts.txt"; done
  wc -l "$OUT"/*.verdicts.txt | sed 's|/.*/||' ;;
time)
  CPUS=${CPUS:-28-31,60-63}
  for r in 1 2 3; do
    B=$EXP/build/rocq/$RID-t$r; fresh "$B"; cd "$B"
    for f in $DEFS; do
      echo "$r $f $(uptime | sed 's/.*load average: //')" >> "$OUT/time.load"
      systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 \
        /usr/bin/time -v -o "$OUT/time.$r.$f" \
          taskset -c "$CPUS" $X rocq compile -R . S "$f.v" >> "$OUT/time.log" 2>&1
      printf '%s\t%s\t%s\t%s\n' "$r" "$f" \
        "$(sed -n 's/.*Elapsed (wall clock) time (h:mm:ss or m:ss): //p' "$OUT/time.$r.$f")" \
        "$(sed -n 's/.*Maximum resident set size (kbytes): //p' "$OUT/time.$r.$f")" >> "$OUT/time.tsv"
    done
  done
  cat "$OUT/time.tsv" ;;
esac
