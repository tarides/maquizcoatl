#!/usr/bin/env bash
# run E: the RefinedRust frontend steps of setup.sh step_refinedrust, run early (same commands, same
# directories) while the switch builds the stdlib; setup.sh then finds them done.
set -euo pipefail
export VU_CACHE=${BENCH_WORKDIR:?}/cache/exp05-view VU_EXP=${BENCH_WORKDIR:?}/exp/05-unverified-calls
. $VU_CACHE/env.sh
export OPAMROOT=$VU_OWN_OPAMROOT OPAMSWITCH=refinedrust
src=$VU_CACHE/refinedrust/src
tc=$(sed -n "s/^channel = \"\(.*\)\"/\1/p" "$src/rr_frontend/rust-toolchain.toml")
echo "frontend toolchain: $tc"
nice -n 10 taskset -c 24-27,56-59 rustup toolchain install "$tc" --profile minimal --component cargo,llvm-tools-preview,rustc,rustc-dev
cd "$src/rr_frontend" && CARGO_TARGET_DIR=$VU_EXP/build/refinedrust-target CARGO_BUILD_JOBS=4 nice -n 10 taskset -c 24-27,56-59 opam exec -- ./refinedrust build
