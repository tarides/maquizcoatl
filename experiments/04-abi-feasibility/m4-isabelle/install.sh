#!/usr/bin/env bash
# install.sh CACHE CPUS JOBS [COMPONENT...]
# Mechanism 4 toolchain for experiment #4: Isabelle2026, the AFP
# release afp-2026-11-19, Isabelle-LLVM (branch 2026, commit e42f4781,
# session Isabelle_LLVM) and the LLVM 23.1.5 release binaries, installed
# into CACHE (experiment #4's own copy, decision (a) on issue #7).
#
# Adapted from experiment #5's experiments/05-unverified-calls/setup.sh
# (branch exp/05-unverified-calls, commit 1dcc3dc), milestone 2
# components isabelle-llvm and llvm, with the pins of its pins.json and
# its lab entry lab/results/2026-11-20-exp-05-toolchains-m2.md. Same
# URLs, versions, sha256 and steps. Differences, all decision-free:
#   - the pins are inlined (the bench host has no jq, and experiment #5's
#     lib.sh is not needed);
#   - CPU pinning comes from the CPUS argument (taskset), JOBS caps the
#     session build: isabelle build -j JOBS/4 -o threads=4 (experiment #5
#     used 12 jobs: -j 3 -o threads=4);
#   - no smoke test here: mechanism 4's own stub (build.sh) exercises
#     export_llvm, clang and the link with C;
#   - output is not redacted by this script; the caller redacts logs
#     before they go into the repository.
# Components: isabelle llvm (default: both, in that order).
set -euo pipefail
[ $# -ge 3 ] || { echo "usage: install.sh CACHE CPUS JOBS [COMPONENT...]" >&2; exit 2; }
CACHE=$1 CPUS=$2 JOBS=$3; shift 3
comps=("$@"); [ ${#comps[@]} -gt 0 ] || comps=(isabelle llvm)
taskset -pc "$CPUS" $$ >/dev/null
renice -n 10 -p $$ >/dev/null

ISABELLE_VERSION=Isabelle2026
ISABELLE_URL=https://www.cl.cam.ac.uk/research/hvg/Isabelle/dist/Isabelle2026_linux.tar.gz
ISABELLE_SHA256=858c995b32216b3876bf395c3be843147d1f1eee404bc6c958d7534ee335e48d
AFP_VERSION=afp-2026-11-19
AFP_URL=https://isa-afp.org/release/afp-2026-11-19.tar.gz
AFP_SHA256=9fe7a2e108e92080a5f9c80e56e7d019424fc4a7f7c431541131b699626de38a
ILLVM_REPO=https://github.com/lammich/isabelle_llvm.git
ILLVM_BRANCH=2026
ILLVM_COMMIT=e42f478118988ff38676ff01215be26f3018f015
ILLVM_SESSION=Isabelle_LLVM
LLVM_VERSION=23.1.5
LLVM_URL=https://github.com/llvm/llvm-project/releases/download/llvmorg-23.1.5/LLVM-23.1.5-Linux-X64.tar.xz
LLVM_SHA256=f72edb0b36580ece7f52e23858f00c18fad4e87395ea7ad05d7e55c39f8fc78a

mkdir -p "$CACHE/dl"
fetch() { # URL SHA256 DEST
  if [ ! -f "$3" ] || [ "$(sha256sum "$3" | cut -d' ' -f1)" != "$2" ]; then
    curl -fsSL --retry 3 -o "$3.part" "$1"
    mv "$3.part" "$3"
  fi
  [ "$(sha256sum "$3" | cut -d' ' -f1)" = "$2" ] || { echo "sha256 mismatch: $(basename "$3")" >&2; exit 1; }
  echo "fetched $(basename "$3") sha256 ok"
}
untar() { # URL SHA256 NAME DIR
  [ -d "$4" ] && return 0
  fetch "$1" "$2" "$CACHE/dl/$3"
  rm -rf "$4.tmp"; mkdir -p "$4.tmp"
  tar -xf "$CACHE/dl/$3" -C "$4.tmp"
  mv "$4.tmp" "$4"
}

step_isabelle() {
  local root=$CACHE/isabelle dist afp llvm par
  dist=$root/dist/$ISABELLE_VERSION
  mkdir -p "$root/home" "$root/bin"
  untar "$ISABELLE_URL" "$ISABELLE_SHA256" "${ISABELLE_VERSION}_linux.tar.gz" "$root/dist"
  [ -x "$dist/bin/isabelle" ] || { echo "no bin/isabelle" >&2; exit 1; }
  # Isabelle keeps settings and heaps under $HOME/.isabelle: the wrapper
  # points HOME into the cache so the account's home is untouched.
  cat >"$root/bin/isabelle" <<WRAPPER
#!/bin/sh
HOME="\$(dirname "\$0")/../home" exec "\$(dirname "\$0")/../dist/$ISABELLE_VERSION/bin/isabelle" "\$@"
WRAPPER
  chmod +x "$root/bin/isabelle"
  "$root/bin/isabelle" version
  untar "$AFP_URL" "$AFP_SHA256" "$AFP_VERSION.tar.gz" "$root/$AFP_VERSION"
  afp=$root/$AFP_VERSION/$AFP_VERSION
  [ -d "$afp/thys" ] || { echo "no thys in $AFP_VERSION" >&2; exit 1; }
  echo "afp release: $AFP_VERSION"
  llvm=$root/isabelle_llvm
  [ -d "$llvm/.git" ] || git clone --quiet --branch "$ILLVM_BRANCH" "$ILLVM_REPO" "$llvm"
  git -C "$llvm" checkout --quiet "$ILLVM_COMMIT"
  echo "isabelle_llvm commit: $(git -C "$llvm" rev-parse HEAD)"
  par=$((JOBS / 4)); [ "$par" -ge 1 ] || par=1
  /usr/bin/time -v "$root/bin/isabelle" build -b -j "$par" -o threads=4 \
    -d "$afp/thys" -d "$llvm/thys" "$ILLVM_SESSION"
  echo "isabelle tree: $(du -sh "$root" | cut -f1)"
}

step_llvm() {
  local dir=$CACHE/llvm/$LLVM_VERSION bin
  mkdir -p "$CACHE/llvm"
  untar "$LLVM_URL" "$LLVM_SHA256" "LLVM-$LLVM_VERSION-Linux-X64.tar.xz" "$dir"
  bin=$(find "$dir" -name llc -type f -executable | sort | head -n 1)
  [ -n "$bin" ] || { echo "no llc in the LLVM release" >&2; exit 1; }
  ln -sfn "$(dirname "$bin")" "$CACHE/llvm/current"
  "$CACHE/llvm/current/clang" --version | sed -n 1p
  "$CACHE/llvm/current/llc" --version | sed -n 2p
  echo "llvm: $(du -sh "$dir" | cut -f1)"
}

for c in "${comps[@]}"; do
  t0=$(date +%s)
  echo "== $c"
  "step_$c"
  echo "== $c done in $(( $(date +%s) - t0 )) s; cache $(du -sh "$CACHE" | cut -f1); free $(df -h "$CACHE" | awk 'NR==2{print $4}')"
done
echo "INSTALL-END status=0"
