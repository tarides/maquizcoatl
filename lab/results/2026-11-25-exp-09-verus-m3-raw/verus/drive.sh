#!/bin/bash
# Experiment #9 run 14: the Verus brittleness matrix, serial, one check at a time.
export BENCH_WORKDIR=$HOME/maquizcoatl-work
cd $BENCH_WORKDIR/exp/09-representative-proof
B=repo/lab/09-representative-proof/brittle.sh
O=out/r14/verus/brittle
running() { # processes in state R last seen on a pinned CPU (other than this check's)
  ps -eo stat=,psr=,comm= | awk '$1 ~ /^R/ && ($2>=28 && $2<=31 || $2>=60 && $2<=63) {print $3"@cpu"$2}' | grep -v -E '^(ps|awk)@' | paste -sd, ; }
cell() { # version seed [env]
  local v=$1 s=$2; shift 2
  echo "== $v $s $* $(date -u +%H:%M:%SZ) load $(cut -d' ' -f1-3 /proc/loadavg) running-on-pinned: [$(running)]"
  env "$@" flock timed.lock $B verus $v $s r14 | cut -f1-3,12-14,15,23
}
for s in default 1 2 3 4 5 6 7 8 9 10; do [ -e $O/4.16.0_$s ] || cell 4.16.0 $s; done
[ -e $O/5.3.0_default_nooptout ] || cell 5.3.0 default VERSION_CHECK=keep
for v in 5.3.0 4.15.3; do
  for s in default 1 2 3 4 5 6 7 8 9 10; do [ -e $O/${v}_$s ] || cell $v $s; done
done
echo "== done $(date -u +%H:%M:%SZ)"
