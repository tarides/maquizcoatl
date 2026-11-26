#!/bin/bash
# Experiment #9: provenance for the notebook (CPU, kernel, OS, tool and
# solver versions, commits).  Adapted from experiment #8's provenance.sh
# (lab/08-hard-features/provenance.sh, main at 6630262).
# Prints no hostnames, addresses or absolute paths.
#   BENCH_WORKDIR=<bench-workdir> provenance.sh
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
CACHE=$BENCH_WORKDIR/cache; EXP=${EXP:-$BENCH_WORKDIR/exp/09-representative-proof}
. "$CACHE/env.sh"; . "$CACHE/verus-env.sh"
echo "cpu: $(lscpu | sed -n 's/^Model name: *//p'), $(nproc) logical CPUs, $(free -g | awk '/Mem:/{print $2}') GiB RAM"
echo "kernel: $(uname -sr)"; echo "os: $(. /etc/os-release; echo "$PRETTY_NAME")"
echo "branch commit (bench clone): $(git -C "$EXP/repo" rev-parse --short HEAD); upstream: $(git -C "$EXP/repo/upstream" rev-parse --short HEAD)"
echo "opam: $(opam --version); rocq: $(opam exec --switch=provers -- rocq --version | head -1); rocq-stdlib: $(opam list --switch=provers --installed -s --columns=version rocq-stdlib 2>/dev/null); ocaml (switch provers): $(opam exec --switch=provers -- ocamlc -version); ocamlfind: $(opam list --switch=provers --installed -s --columns=version ocamlfind 2>/dev/null)"
echo "fstar: $(fstar.exe --version | head -1) (commit $(fstar.exe --version | sed -n 's/^commit=//p' | cut -c1-12))"
echo "z3 bundled with F*: $(for d in "$CACHE"/fstar/lib/fstar/z3-*; do printf '%s ' "$("$d/bin/z3" --version | awk '{print $3}')"; done)"
echo "verus: $(verus --version 2>&1 | sed -n 's/^ *Version: //p'); rust toolchain: $(sed -n 's/.*"toolchain": *"\([^" ]*\).*/\1/p' "$CACHE/verus/version.json"); z3 (bundled with Verus): $("$CACHE/verus/z3" --version)"
echo "gcc: $(gcc --version | head -1); cmake: $(cmake --version | head -1); python: $(python3 --version)"
echo "C library: Release, static (-DBUILD_SHARED_LIBS=OFF), out of tree in <exp>/build/onig"
echo "timed checks: taskset -c 28-31,60-63, /usr/bin/time -v, systemd-run --user --scope -p MemoryMax=16G (cgroup v2); untimed: nice -n 10, taskset -c 4-7"
