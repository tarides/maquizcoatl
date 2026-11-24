#!/usr/bin/env bash
# fstar-master.sh: builds F* master (with the Pulse and KaRaMeL it carries)
# from source in a scratch directory, for the check of issue #29 (the
# eta-reduction found while building the Pulse prototype), then runs
# eta.sh against it.
#
# Usage: fstar-master.sh DIR [COMMIT]
#   DIR     scratch directory, outside the shared toolchain cache; it gets
#           its own opam root (DIR/opam), so no shared switch is touched.
#   COMMIT  F* commit to build (default: the master head when run).
# Environment: VU_JOBS (default 4); VU_Z3_DIR, a directory holding the
#   bundled z3-<version> directories of an F* binary release (only Z3 is
#   taken from it). Needs opam on PATH, git, gcc, make, GMP headers.
#
# Build: `make ADMIT=1 3` then `make install`, the build the F* opam
# package uses (ADMIT=1 skips SMT checks of the libraries; eta.sh's own
# module is fully checked).
set -euo pipefail
d=$(mkdir -p "$1" && cd "$1" && pwd)
commit=${2:-}
jobs=${VU_JOBS:-4}
: "${VU_Z3_DIR:?}"
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
log() { printf '== %s %s\n' "$(date -u +%H:%M:%S)" "$*"; }

export OPAMROOT="$d/opam" OPAMYES=1 OPAMNOENVNOTICE=1 OPAMJOBS=$jobs
echo "cpu_set: $(taskset -pc $$ | sed 's/.*: //')"
echo "nice: $(nice)"
echo "jobs: $jobs"

if [ ! -d "$d/src/.git" ]; then
  log clone
  git clone -q https://github.com/FStarLang/FStar "$d/src"
fi
cd "$d/src"
if [ -n "$commit" ]; then git checkout -q "$commit"; fi
git submodule update -q --init --recursive
echo "fstar_commit: $(git rev-parse HEAD)"
echo "fstar_commit_date: $(git log -1 --format=%cI)"
git submodule status | sed 's/^/submodule: /'

if [ ! -d "$OPAMROOT" ]; then
  log opam init
  opam init -q --bare --disable-sandboxing -n
  opam switch create -q fm ocaml-base-compiler.5.4.1
fi
log opam deps
opam install -q --switch=fm --deps-only ./fstar.opam
opam exec --switch=fm -- ocaml -version

log build
opam exec --switch=fm -- make -j "$jobs" ADMIT=1 3
log install
opam exec --switch=fm -- make install PREFIX="$d/install"
for z in "$VU_Z3_DIR"/z3-*; do
  ln -sfn "$z" "$d/install/lib/fstar/$(basename "$z")"
done
"$d/install/bin/fstar.exe" --version
"$d/install/bin/krml" -version || true

log eta
rm -rf "$d/eta"
set +e
PATH="$d/install/bin:$PATH" VU_FSTAR_HOME="$d/install" \
  bash "$here/eta.sh" "$d/eta"
echo "eta_status=$?"
log end
