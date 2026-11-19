#!/bin/sh
# Run the 8 test binaries of build/<tests|arith> in parallel, collecting
# stdout and every sanitizer report. Usage: run-tests.sh tests|arith
set -u
. "$(dirname "$0")/env.sh"
n=$1
D=$LOGS/$n
mkdir -p "$D"
cd "$B/$n/test"
for t in test_utf8 test_back testc testcu test_syntax test_options test_regset testp; do
  (
    ASAN_OPTIONS=halt_on_error=0:detect_leaks=1:log_path=$D/$t.asan \
    UBSAN_OPTIONS=halt_on_error=0:print_stacktrace=1:log_path=$D/$t.ubsan \
    taskset -c "$CPUS" ./$t > "$D/$t.out" 2> "$D/$t.err"
    echo "exit $?" > "$D/$t.exit"
  ) &
done
wait
for t in test_utf8 test_back testc testcu test_syntax test_options test_regset testp; do
  printf '%-13s %s | %s | reports: %s\n' "$t" "$(grep -a 'RESULT' "$D/$t.out" | tail -1)" "$(cat "$D/$t.exit")" \
    "$(cat "$D/$t".asan.* "$D/$t".ubsan.* 2>/dev/null | grep -acE 'runtime error|ERROR: (Address|Leak)Sanitizer')"
done
