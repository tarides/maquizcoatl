#!/bin/sh
# Provenance for experiment #12 (no host name, address, user name or path).
# Usage: CACHE=<cache> EXP=<exp> provenance.sh
set -u
. "$CACHE/env.sh"
echo "repo_commit: $(git -C "$EXP/repo" rev-parse --short HEAD)"
echo "upstream_commit: $(git -C "$EXP/repo/upstream" rev-parse --short HEAD)"
for b in release debug; do
  c="$EXP/build/onig-$b/CMakeCache.txt"
  echo "onig-$b: $(grep -E '^CMAKE_BUILD_TYPE:' "$c" | cut -d= -f2) C_FLAGS='$(grep -E '^CMAKE_C_FLAGS:' "$c" | cut -d= -f2-)' C_FLAGS_RELEASE='$(grep -E '^CMAKE_C_FLAGS_RELEASE:' "$c" | cut -d= -f2-)' C_FLAGS_DEBUG='$(grep -E '^CMAKE_C_FLAGS_DEBUG:' "$c" | cut -d= -f2-)'"
done
echo "gcc: $(gcc --version | head -1)"
echo "cmake: $(cmake --version | head -1)"
echo "python: $(python3 --version)"
echo "opam: $(opam --version)"
echo "opam_repo_default: $(tar xzOf "$OPAMROOT/repo/default.tar.gz" --wildcards '*/repo' 2>/dev/null | head -1)"
for sw in ffi ffi-flambda; do
  echo "switch $sw: $(opam exec --switch=$sw -- ocamlopt -version)" \
    "$(opam exec --switch=$sw -- ocamlopt -config | grep -E '^(flambda|flat_float_array):' | tr '\n' ' ')"
  echo "  packages: $(opam list --switch=$sw -i --columns=name,version --short dune ctypes ctypes-foreign re mtime conf-libffi 2>/dev/null | tr '\n' ' ')"
done
echo "libffi: $(pkg-config --modversion libffi)"
echo "cpu: $(lscpu | sed -n 's/^Model name: *//p')"
echo "cpus_online: $(nproc --all)"
echo "ram: $(free -g | awk '/^Mem:/{print $2" GiB"}')"
echo "kernel: $(uname -sr)"
echo "os: $(. /etc/os-release; echo "$PRETTY_NAME")"
echo "cpu2_governor: $(cat /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor 2>/dev/null)"
echo "timing_cpu: 2; build_cpus: 0-3,32-35"
echo "loadavg: $(cut -d' ' -f1-3 /proc/loadavg)"
echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
