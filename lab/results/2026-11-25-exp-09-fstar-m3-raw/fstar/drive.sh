#!/bin/bash
export BENCH_WORKDIR=$HOME/maquizcoatl-work
cd $BENCH_WORKDIR/exp/09-representative-proof
for v in 5.3.0 4.15.3 4.13.3; do
  for s in default 1 2 3 4 5 6 7 8 9 10; do
    [ -e out/r13/fstar/brittle/${v}_$s ] && continue
    echo "== $v $s $(date -u +%H:%M:%SZ)"
    flock timed.lock repo/lab/09-representative-proof/brittle.sh fstar $v $s r13
  done
done
echo "== done $(date -u +%H:%M:%SZ)"
