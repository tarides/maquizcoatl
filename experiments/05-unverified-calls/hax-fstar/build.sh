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
exec "$VU_HARNESS/hax/build.sh" fstar
