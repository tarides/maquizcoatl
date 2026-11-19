#!/bin/sh
# Start the fork-mode campaign, one nohup'd process per target of
# split.tsv, pinned to $CPUS. Usage: fuzz.sh [seconds]
set -eu
. "$(dirname "$0")/env.sh"
T=${1:-6600}
mkdir -p "$LOGS/fuzz"
tail -n +2 "$EXP/split.tsv" | while IFS="$(printf '\t')" read -r t w d m; do
  mkdir -p "$HOSTDIR/corpus/$t" "$HOSTDIR/artifacts/$t" "$HOSTDIR/work/$t"
  ML=""; [ "$m" != 0 ] && ML="-max_len=$m"
  ( cd "$HOSTDIR/work/$t" &&
    ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=print_stacktrace=1 \
    nohup taskset -c "$CPUS" "$H/$t" -fork="$w" -ignore_crashes=1 -ignore_timeouts=1 \
      -ignore_ooms=1 -max_total_time="$T" -timeout=30 -rss_limit_mb=2048 \
      -print_final_stats=1 -artifact_prefix="$HOSTDIR/artifacts/$t/" \
      -dict="$H/$d" $ML "$HOSTDIR/corpus/$t" > "$LOGS/fuzz/$t.log" 2>&1 & )
  echo "started $t ($w workers)"
done
