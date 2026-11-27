#!/bin/sh
# run 1 series, in order (reduction: large ranks 1-10 per source)
export EXP=$(pwd)
P="python3 -I repo/lab/22-extracted-ocaml/run22.py"
$P short x1 10 && $P repeat x1 short && $P cata x1 10 && $P large x1 10 10 && $P repeat x1 large
echo SERIES-DONE $(date -u +%FT%TZ)
