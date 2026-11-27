#!/bin/sh
# run 2 series, in order (issue #22 decisions 7 and 8)
export EXP=$(pwd)
P="python3 -I repo/lab/22-extracted-ocaml/run22.py"
FLAMBDA=1 $P short x2 10 && FLAMBDA=1 $P repeat x2 short && $P large x2 10 ">10" && $P repeat x2 large && $P catafuel x2 10 512
echo SERIES-DONE $(date -u +%FT%TZ)
