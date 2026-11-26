#!/usr/bin/env bash
# usage: i30-dev.sh [-n|-r] RUN_ID  (runs on the bench host)
set -u
MODE=""; [ "$1" = -n ] || [ "$1" = -r ] && { MODE=$1; shift; }
ID=$1
E=$HOME/maquizcoatl-work/exp/05-isabelle-llvm-client
git -C $E/repo pull -q --ff-only
git -C $E/repo log --oneline -1
VU_EXP=$E VU_CACHE=$HOME/maquizcoatl-work/cache/exp05-view VU_CPUS=20-23,52-55 VU_JOBS=4 \
  $E/repo/experiments/05-unverified-calls/run.sh $MODE isabelle-llvm "$ID" 2>&1 | tail -5
