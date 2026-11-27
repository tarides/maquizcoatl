#!/bin/sh
# Issue #22 provenance (experiment #12's provenance.sh, extended).
# Records no host name, address, user name or absolute path.
# Usage: CACHE=<cache> EXP=<exp> provenance.sh RUNID
set -u
. "$CACHE/env.sh"
RID=${1:?run-id}
O=$EXP/out/$RID
echo "repo_commit: $(git -C "$EXP/repo" rev-parse --short HEAD)"
echo "upstream_commit: $(git -C "$EXP/repo/upstream" rev-parse --short HEAD)"
echo "experiment_9_commit: e1b9936; $(cat "$O/extract/source-check.txt" 2>/dev/null)"
echo "rocq: $(head -1 "$O/extract/rocq-version.txt" 2>/dev/null | tr '\n' ' ')"
echo "rocq_packages (provers): $(opam list --switch=provers -i --columns=name,version --short rocq-core rocq-stdlib 2>/dev/null | tr '\n' ' ')"
echo "rocq_extraction: Extract.v (ExtrOcamlBasic, ExtrOcamlNatInt), rocq compile -R . S on Syntax Sem Compile Vm Extract"
echo "fstar: $(tr '\n' ' ' < "$O/extract/fstar-version.txt" 2>/dev/null)"
echo "fstar_extraction: fstar.exe --cache_checked_modules --cache_dir cache --z3version 5.3.0 --codegen OCaml, --custard_entry Compile.compile Vm.vm Sem.sem Syntax.ncap Syntax.search Spec2.search Spec2.search_from Spec2.lookup Spec2.fuel0, Extract.fst"
echo "extracted_sha256:"; sed 's/^/  /' "$O/extract/sha256.txt" 2>/dev/null
for b in release noopt dbgc; do
  c="$EXP/build/onig-$b/CMakeCache.txt"
  echo "onig-$b: $(grep -E '^CMAKE_BUILD_TYPE:' "$c" | cut -d= -f2) C_FLAGS='$(grep -E '^CMAKE_C_FLAGS:' "$c" | cut -d= -f2-)' C_FLAGS_RELEASE='$(grep -E '^CMAKE_C_FLAGS_RELEASE:' "$c" | cut -d= -f2-)' C_FLAGS_DEBUG='$(grep -E '^CMAKE_C_FLAGS_DEBUG:' "$c" | cut -d= -f2-)'"
done
echo "gcc: $(gcc --version | head -1)"
echo "cmake: $(cmake --version | head -1)"
echo "python: $(python3 --version)"
echo "opam: $(opam --version)"
echo "switch ffi: $(opam exec --switch=ffi -- ocamlopt -version) $(opam exec --switch=ffi -- ocamlopt -config | grep -E '^(flambda|flat_float_array|architecture|system):' | tr '\n' ' ')"
echo "  packages: $(opam list --switch=ffi -i --columns=name,version --short dune ctypes ctypes-foreign mtime conf-libffi zarith yojson ppx_deriving ppx_deriving_yojson conf-gmp cppo ocaml-compiler-libs ppx_derivers ppxlib sexplib0 2>/dev/null | tr '\n' ' ')"
if opam list --switch=ffi-flambda -i --short zarith >/dev/null 2>&1 && [ -x "$EXP/bin/main-ffi-flambda.exe" ]; then
  echo "switch ffi-flambda (run 2, decision 8): $(opam exec --switch=ffi-flambda -- ocamlopt -version) $(opam exec --switch=ffi-flambda -- ocamlopt -config | grep -E '^(flambda|flat_float_array|architecture|system):' | tr '\n' ' ')"
  echo "  packages: $(opam list --switch=ffi-flambda -i --columns=name,version --short dune ctypes ctypes-foreign mtime conf-libffi zarith yojson ppx_deriving ppx_deriving_yojson conf-gmp cppo ocaml-compiler-libs ppx_derivers ppxlib sexplib0 2>/dev/null | tr '\n' ' ')"
fi
echo "libffi: $(pkg-config --modversion libffi)"
echo "gmp: $(pkg-config --modversion gmp 2>/dev/null || echo '?')"
echo "cpu: $(lscpu | sed -n 's/^Model name: *//p')"
echo "cpus_online: $(nproc --all)"
echo "ram: $(free -g | awk '/^Mem:/{print $2" GiB"}')"
echo "kernel: $(uname -sr)"
echo "os: $(. /etc/os-release; echo "$PRETTY_NAME")"
echo "cpu2_governor: $(cat /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor 2>/dev/null)"
echo "timing_cpu: 2; build_cpus: 0-3,32-35 (nice -n 10)"
echo "gc: defaults, OCAMLRUNPARAM ${OCAMLRUNPARAM:+set}${OCAMLRUNPARAM:-unset}"
echo "loadavg: $(cut -d' ' -f1-3 /proc/loadavg)"
echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
