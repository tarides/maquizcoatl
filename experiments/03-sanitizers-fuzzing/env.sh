# Common settings for experiment #3. Source it; HOSTDIR defaults to the
# work directory on the bench host.
HOSTDIR=${HOSTDIR:-$HOME/maquizcoatl-work/exp/03-sanitizers-fuzzing}
SRC=$HOSTDIR/src/maquizcoatl
UP=$SRC/upstream
EXP=$SRC/experiments/03-sanitizers-fuzzing
TC=$HOSTDIR/toolchain/LLVM-21.1.8-Linux-X64
B=$HOSTDIR/build
H=$HOSTDIR/harness
LOGS=$HOSTDIR/logs
# CPUs used by this experiment: the bench host is shared; #11 pins CPUs
# 4-7 and their SMT siblings 36-39, so stay on 8-31 and 40-63.
CPUS=${CPUS:-8-31,40-63}
export CC=$TC/bin/clang CXX=$TC/bin/clang++
export ASAN_SYMBOLIZER_PATH=$TC/bin/llvm-symbolizer
export UBSAN_SYMBOLIZER_PATH=$TC/bin/llvm-symbolizer
