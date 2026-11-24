#!/bin/bash
# Provenance for experiment #6 (adapted from experiment #7's): CPU model,
# cores, RAM, kernel, OS, tool versions, commits, CPU pinning of other
# experiments.  No hostname, address, user name or absolute path.
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
. "$BENCH_WORKDIR/cache/env.sh"
X="opam exec --switch=provers --"
echo "cpu: $(lscpu | sed -n 's/^Model name: *//p'), $(nproc) hardware threads"
echo "ram: $(free -g | awk '/Mem:/{print $2}') GB"
echo "kernel: $(uname -r)"; echo "os: $(lsb_release -ds)"
echo "scripts commit: ${SCRIPTS_COMMIT:-unknown} (branch exp/06-spec-speed)"
echo "experiment #7 scripts (idle rerun): ${E07_COMMIT:-unknown} (main, lab/07-large-tables)"
echo "upstream: f95747b (copy of the submodule, read only)"
echo "upstream test_utf8 (Release build): $(cat "$EXP/out/${RID:-m1}/g/test_utf8.txt" 2>/dev/null)"
echo "onig CMAKE_C_FLAGS_RELEASE: $(sed -n 's/^CMAKE_C_FLAGS_RELEASE:STRING=//p' "$EXP/build/onig/CMakeCache.txt")"
echo "opam: $(opam --version)"; echo "ocaml: $($X ocamlfind ocamlopt -version)"
echo "zarith: $(opam show --switch=provers -f installed-version zarith 2>/dev/null)"
echo "rocq: $($X rocq --version | head -1)"
echo "rocq-stdlib: $(opam show --switch=provers -f installed-version rocq-stdlib 2>/dev/null)"
echo "rocq-native: $(opam show --switch=provers -f installed-version rocq-native 2>/dev/null)"
echo "why3: $($X why3 --version)"
echo "fstar: $(fstar.exe --version | tr '\n' ' ')"
echo "lean: $(elan run leanprover/lean4:v4.36.0 lean --version)"
echo "lake: $(elan run leanprover/lean4:v4.36.0 lake --version)"
echo "elan: $(elan --version)"
echo "gcc: $(gcc --version | head -1)"; echo "cmake: $(cmake --version | head -1)"; echo "python: $(python3 --version)"
echo "timing CPUs: 28-31,60-63 (L3 complex 7); untimed work on CPUs 4-7 under nice -n 10"
echo "load average at provenance time: $(cut -d' ' -f1-3 /proc/loadavg)"
