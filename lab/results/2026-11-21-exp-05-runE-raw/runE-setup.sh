#!/usr/bin/env bash
# launches one setup-pipeline.sh run: MILESTONE COMPONENT CPUS JOBS
export VU_SHARED_CACHE=${BENCH_WORKDIR:?}/cache VU_EXP=${BENCH_WORKDIR:?}/exp/05-unverified-calls
export VU_CPUS=$3 VU_JOBS=$4
cd $VU_EXP/dev-runE
exec ./setup-pipeline.sh $1 $2 > $VU_EXP/runE-setup-$2.console 2>&1
