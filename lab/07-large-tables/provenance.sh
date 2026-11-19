#!/bin/bash
# Provenance for experiment #7: CPU model, cores, RAM, kernel, OS, tool
# versions, commits.  No hostname, address, user name or absolute path.
EXP=${EXP:-$HOME/maquizcoatl-work/exp/07-large-tables}
. "$HOME/maquizcoatl-work/cache/env.sh"
X="opam exec --switch=provers --"
echo "cpu: $(lscpu | sed -n 's/^Model name: *//p'), $(nproc) hardware threads"
echo "ram: $(free -g | awk '/Mem:/{print $2}') GB"
echo "kernel: $(uname -r)"; echo "os: $(lsb_release -ds)"
echo "scripts commit: ${SCRIPTS_COMMIT:-unknown} (branch exp/07-large-tables)"
echo "upstream commit: $(git -C "$EXP/repo/upstream" rev-parse --short HEAD)"
echo "opam: $(opam --version)"; echo "ocaml: $($X ocamlfind ocamlopt -version)"
echo "rocq: $($X rocq --version | head -1)"
echo "rocq-stdlib: $(opam show --switch=provers -f installed-version rocq-stdlib 2>/dev/null)"
echo "why3: $($X why3 --version)"
echo "alt-ergo: $(opam show --switch=provers -f installed-version alt-ergo 2>/dev/null)"
echo "fstar: $(fstar.exe --version | tr '\n' ' ')"
echo "krml: $(krml -version 2>&1 | head -1)"
echo "lean: $(cd "$EXP/build/lean" 2>/dev/null; echo leanprover/lean4:v4.36.0 > /dev/null; elan run leanprover/lean4:v4.36.0 lean --version)"
echo "elan: $(elan --version)"
echo "gcc: $(gcc --version | head -1)"; echo "cmake: $(cmake --version | head -1)"; echo "python: $(python3 --version)"
echo "timing CPUs: 28-31,60-63 (L3 complex 7); exploratory runs on complexes 2-6; CPUs 4-7,36-39 (experiment #11) unused"
