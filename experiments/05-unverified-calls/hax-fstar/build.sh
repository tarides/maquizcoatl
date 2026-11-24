#!/usr/bin/env bash
# build.sh: hax, F* backend (experiment #5, milestone 3), under run.sh's
# contract. The prototype is in ../hax (shared with the Rocq backend);
# the sha256 of its files are printed first, since run.sh hashes only
# this directory.
set -euo pipefail
: "${VU_HARNESS:?}"
echo "== ../hax sources (sha256)"
(cd "$VU_HARNESS" && find hax -type f -not -path 'hax/target/*' -print0 |
  LC_ALL=C sort -z | xargs -0 sha256sum)
# F*: the release hax pins (pins.json .hax.fstar, installed by setup.sh
# step hax-fstar into <cache>/hax/fstar-<version>), since F* 2026.11.15
# of milestone 1 cannot check hax v0.5.0's output (run C). Run E.
: "${VU_CACHE:?}"
v=$(jq -r .hax.fstar "$VU_HARNESS/pins.json")
export VU_HAX_FSTAR=${VU_HAX_FSTAR:-$VU_CACHE/hax/fstar-$v/fstar}
[ -x "$VU_HAX_FSTAR/bin/fstar.exe" ] || { echo "no F* $v: run setup.sh 3 hax-fstar"; exit 1; }
exec "$VU_HARNESS/hax/build.sh" fstar
