#!/bin/bash
# Experiment #11, step 10: run conditions. Records no hostname, address,
# user name or path.  Usage: provenance.sh full|sample <label>
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
CPU=${TIME_CPU:-4}
sample() {
  echo "sample $1 time $(date -u +%Y-%m-%dT%H:%M:%SZ) load $(cut -d' ' -f1-3 /proc/loadavg) cur_freq_khz $(cat /sys/devices/system/cpu/cpu$CPU/cpufreq/scaling_cur_freq)"
  grep -E '^cpu(4|36|5|6|7|37|38|39) ' /proc/stat | sed "s/^/sample $1 stat /"
}
if [ "$1" = sample ]; then sample "$2"; exit 0; fi
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
f=/sys/devices/system/cpu/cpu$CPU/cpufreq
echo "cpu_model $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')"
echo "kernel $(uname -r)"
echo "os $(. /etc/os-release; echo "$PRETTY_NAME")"
echo "logical_cpus $(nproc)"
echo "timing_cpu $CPU (taskset -c $CPU); SMT sibling and L3 neighbours observed: 36 5-7 37-39"
echo "governor $(cat $f/scaling_governor)"
echo "boost $(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || echo n/a)"
for k in scaling_min_freq scaling_max_freq cpuinfo_min_freq cpuinfo_max_freq; do echo "$k $(cat $f/$k)"; done
echo "gcc $(gcc --version | head -1)"
echo "g++ $(g++ --version | head -1)"
echo "cmake $(cmake --version | head -1)"
echo "python $(python3 --version)"
echo "rustc $(rustc --version 2>/dev/null)"
echo "cargo $(cargo --version 2>/dev/null)"
echo "ocaml $(opam exec -- ocamlopt -version 2>/dev/null)"
echo "opam_packages $(opam list --columns=name,version re mtime dune 2>/dev/null | grep -v '^#' | tr -s ' \n' ' ')"
echo "c_flags -O3 -DNDEBUG (CMake Release; harnesses compiled with the same)"
echo "rust_flags cargo --release (opt-level 3)"
echo "ocaml_flags dune --release, ocamlopt -unsafe -inline 200"
echo "repo_commit $(git -C "$REPO" rev-parse HEAD)"
echo "upstream_commit $(git -C "$REPO/upstream" rev-parse HEAD)"
echo "workloads_commit $(cat "$BENCH/workloads/COMMIT" 2>/dev/null)"
sample "$2"
