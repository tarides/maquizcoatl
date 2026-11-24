# Timing helper for experiment #6 (copied from experiment #7's lab/07-large-tables/tm.sh),
# sourced by the per-tool scripts.
# tm <label> <cmd...>: run under /usr/bin/time -v, pinned to $TCPUS, with
# ulimit -v 64G, ulimit -s unlimited and a 20-minute timeout.  Appends
# label, run, exit status, wall-clock, peak RSS (KB) and the load average
# before the run to $OUT/times.tsv.  Prints nothing identifying the host.
TCPUS=${TCPUS:-28-31,60-63}
RUN=${RUN:-x}
: "${OUT:?}"
mkdir -p "$OUT"
tm() {
  local label=$1; shift
  local load; load=$(cut -d' ' -f1-3 /proc/loadavg)
  local f="$OUT/$label.$RUN.time"
  local st=0
  ( ulimit -v $((64*1024*1024)); ulimit -s unlimited
    exec timeout "${TMO:-1200}" /usr/bin/time -v -o "$f" taskset -c "$TCPUS" "$@" ) > "$OUT/$label.$RUN.log" 2>&1 || st=$?
  local wall rss
  wall=$(awk -F': ' '/Elapsed \(wall/{print $2}' "$f" 2>/dev/null)
  rss=$(awk -F': ' '/Maximum resident/{print $2}' "$f" 2>/dev/null)
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$label" "$RUN" "$st" "$wall" "$rss" "$load" >> "$OUT/times.tsv"
  printf '%s run %s: status %s wall %s rss %sKB load %s\n' "$label" "$RUN" "$st" "$wall" "$rss" "$load"
  return 0
}
