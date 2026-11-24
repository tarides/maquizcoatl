#!/usr/bin/env bash
# final-c-corr.sh: check run after the review of run C (hax/build.sh step 3 trace, disk helpers)
set -uo pipefail
E=$HOME/maquizcoatl-work/exp/05-unverified-calls
cd $E/repo && echo "repo_commit: $(git rev-parse --short HEAD)"
export VU_EXP=$E VU_CACHE=$HOME/maquizcoatl-work/cache/exp05-view VU_SHARED_CACHE=$HOME/maquizcoatl-work/cache VU_CPUS=20-23,52-55 VU_JOBS=4
H=$E/repo/experiments/05-unverified-calls
mkdir -p $E/out/runC-corr
cd $H
echo "uptime: $(uptime)"
echo "disk_free_start: $(df -BM --output=avail ~ | tail -1)"
nice -n 10 ./provenance.sh runC-corr start >/dev/null || echo "provenance status $?"
nice -n 10 ./run.sh hax-fstar runC-corr; echo "run.sh hax-fstar: status $?"
. ./lib.sh
echo "vu_du (old disk.txt measure): $(vu_du "$VU_CACHE")"
echo "vu_du_links (new): $(vu_du_links "$VU_CACHE")"
echo "vu_free (new): $(vu_free "$VU_CACHE")"
nice -n 10 ./provenance.sh runC-corr end >/dev/null; echo "uptime end: $(uptime)"
echo "disk_free_end: $(df -BM --output=avail ~ | tail -1)"
