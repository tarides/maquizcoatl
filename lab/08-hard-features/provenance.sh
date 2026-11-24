#!/bin/bash
# Provenance for the notebook: CPU, kernel, OS, tool versions, commit.
# Prints no hostnames, addresses or absolute paths.
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
CACHE=$BENCH_WORKDIR/cache; EXP=${EXP:-$BENCH_WORKDIR/exp/08-hard-features}
. "$CACHE/env.sh"; . "$CACHE/verus-env.sh"
echo "cpu: $(lscpu | sed -n 's/^Model name: *//p'), $(nproc) logical CPUs, $(free -g | awk '/Mem:/{print $2}') GiB RAM"
echo "kernel: $(uname -sr)"; echo "os: $(. /etc/os-release; echo "$PRETTY_NAME")"
echo "branch commit: $(git -C "$EXP/repo" rev-parse --short HEAD); upstream: $(git -C "$EXP/repo/upstream" rev-parse --short HEAD)"
echo "rocq: $(opam exec --switch=provers -- rocq --version | head -1); ocaml switch provers: $(opam exec --switch=provers -- ocamlc -version)"
echo "lean: $(cd "$EXP/build/lean" 2>/dev/null && lean --version)"
echo "fstar: $(fstar.exe --version | head -1) ($(fstar.exe --version | sed -n 's/^commit=//p' | cut -c1-12)); z3 used by F*: $(fstar.exe --help 2>&1 | grep -A1 -- '--z3version' | sed -n 's/.*Default: //p')"
echo "verus: $(verus --version 2>&1 | sed -n 's/^ *Version: //p'); rust toolchain: $(sed -n 's/.*"toolchain": *"\([^" ]*\).*/\1/p' "$CACHE/verus/version.json"); z3 (bundled): $("$CACHE/verus/z3" --version)"
echo "gcc: $(gcc --version | head -1); cmake: $(cmake --version | head -1); python: $(python3 --version)"
echo "memory cap mechanism: systemd-run --user --scope -p MemoryMax (cgroup v2)"
