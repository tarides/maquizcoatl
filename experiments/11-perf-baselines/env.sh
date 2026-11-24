# Sourced by every script of experiment #11 on the bench host.
# Keeps all toolchains under $BENCH; the account's own opam root,
# rustup and PATH are not touched.
: "${BENCH:=$HOME/maquizcoatl-work/exp/11-perf-baselines}"
export BENCH
export RUSTUP_HOME="$BENCH/toolchains/rustup"
export CARGO_HOME="$BENCH/toolchains/cargo"
export OPAMROOT="$BENCH/toolchains/opam"
export OPAMSWITCH=e11
export OPAMYES=1
export PATH="$CARGO_HOME/bin:$BENCH/prefix/bin:$PATH"
# CPUs used for builds (another L3 complex than the timing CPU 4).
: "${BUILD_CPUS:=16-19}"
export BUILD_CPUS
