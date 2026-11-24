#!/usr/bin/env bash
# final-f.sh RUN_ID CPUS TOOL...: recorded run F on the bench host, from <exp>/repo at the pushed commit
set -uo pipefail
E=${BENCH_WORKDIR:?}/exp/05-unverified-calls
R=$1 C=$2; shift 2
cd $E/repo && git fetch -q origin && git checkout -q exp/05-unverified-calls && git merge -q --ff-only origin/exp/05-unverified-calls && git submodule update -q
echo "repo_commit: $(git rev-parse --short HEAD)"
export VU_EXP=$E VU_CACHE=${BENCH_WORKDIR:?}/cache/exp05-view VU_SHARED_CACHE=${BENCH_WORKDIR:?}/cache VU_CPUS=$C VU_JOBS=${VU_JOBS:-4} VU_TIMEOUT=${VU_TIMEOUT:-2400}
H=$E/repo/experiments/05-unverified-calls
O=$E/out/$R
mkdir -p $O
cd $H
echo "uptime: $(uptime)"
echo "disk_free_start: $(df -BM --output=avail ~ | tail -1)"
nice -n 10 ./provenance.sh $R start >/dev/null || echo "provenance status $?"
[ -d $O/reference ] || nice -n 10 ./run.sh reference $R
for t in "$@"; do
  case $t in
  miri:*) VU_MIRI_TOOLS="${t#miri:}" nice -n 10 taskset -c $VU_CPUS ./miri/miri.sh $E/build/$R/miri > $O/miri.raw 2>&1; echo "miri status $?"
     . ./lib.sh; vu_redact < $O/miri.raw > $O/miri.log; rm $O/miri.raw ;;
  rrprobe) nice -n 10 taskset -c $VU_CPUS ./refinedrust/probe.sh $E/build/$R/rr-probe 2>&1 | (. ./lib.sh; vu_redact) > $O/refinedrust-probe.log; echo "rr probe status $?" ;;
  *:*:*) # TOOL:CPUS_N:CPUS_R: the two negative controls in parallel
     IFS=: read -r tt cn cr <<<"$t"
     nice -n 10 ./run.sh $tt $R; echo "run.sh $tt: status $?"
     VU_CPUS=$cn nice -n 10 ./run.sh -n $tt $R > $O/.n-$tt.console 2>&1 &
     VU_CPUS=$cr nice -n 10 ./run.sh -r $tt $R > $O/.r-$tt.console 2>&1 &
     wait; cat $O/.n-$tt.console $O/.r-$tt.console; rm -f $O/.n-$tt.console $O/.r-$tt.console
     grep -h '^build_status\|^mode' $O/$tt-control/result.txt $O/$tt-control-read/result.txt ;;
  *) nice -n 10 ./run.sh $t $R; echo "run.sh $t: status $?"
     nice -n 10 ./run.sh -n $t $R; echo "run.sh -n $t: status $?"
     nice -n 10 ./run.sh -r $t $R; echo "run.sh -r $t: status $?" ;;
  esac
done
./count-trusted.sh > $O/trusted.tsv
nice -n 10 ./provenance.sh $R end >/dev/null; echo "uptime end: $(uptime)"
echo "disk_free_end: $(df -BM --output=avail ~ | tail -1)"
