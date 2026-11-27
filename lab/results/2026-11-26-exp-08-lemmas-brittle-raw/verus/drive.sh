#!/bin/bash
# Issue #34, run 4: the Verus brittleness matrix (experiment #9's run 14),
# serial, one check at a time, through brittle.sh verus.
#   BENCH_WORKDIR=<bench-workdir> drive.sh
# Order: 4.16.0 (bundled), the refusal cell (5.3.0 without the opt-out),
# 5.3.0, 4.15.3; seeds default, 1..10.  A cell with a directory is skipped
# (so a relaunch never reruns a recorded cell); no cell is retried.
# Before each cell: the load average and the threads last seen on the pinned
# CPUs 24-27,56-59 (ps -eLo user,psr,pcpu,comm), and the busy share of those
# CPUs over one second (/proc/stat).  If a thread other than ps/awk has
# pcpu above 1% there, or the busy share is above 10%, the driver waits
# 60 s and checks again.  Other accounts' threads are written as "other"
# with no command name.  Prints no host name or absolute path.
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR}"
E=$BENCH_WORKDIR/exp/08-discriminating-lemmas
cd "$E" || exit 2
B=repo/lab/08-discriminating-lemmas/brittle.sh
O=out/r4/verus/brittle
P=out/r4/verus/precheck.txt
mkdir -p "$O"
ME=$(id -un)
pinned() { awk '($2>=24 && $2<=27) || ($2>=56 && $2<=59)'; }
busy_threads() {
  ps -eLo user:32,psr,pcpu,comm --no-headers | pinned \
    | awk -v me="$ME" '$3>1.0 && $4!="ps" && $4!="awk" { print (($1==me) ? "self " $4 : "other") "@cpu" $2 " " $3 "%" }'
}
busy_share() {
  snap() { for c in 24 25 26 27 56 57 58 59; do awk -v c="cpu$c" '$1==c{t=0; for(i=2;i<=NF;i++) t+=$i; print t, $5+$6}' /proc/stat; done; }
  local a b; a=$(snap); sleep 1; b=$(snap)
  paste <(echo "$a") <(echo "$b") | awk '{t+=$3-$1; i+=$4-$2} END{printf "%.1f", 100*(t-i)/t}'
}
precheck() { # tag
  local n=0 th bs
  while :; do
    th=$(busy_threads | paste -sd, -); bs=$(busy_share)
    { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $1 load $(cut -d' ' -f1-3 /proc/loadavg) busy ${bs}% threads>1%: [${th}]"; } >> "$P"
    if [ -z "$th" ] && awk -v b="$bs" 'BEGIN{exit !(b<=10)}'; then return 0; fi
    n=$((n+1)); echo "   busy, waiting 60 s (attempt $n)" | tee -a "$P"; sleep 60
  done
}
cell() { # version seed [env]
  local v=$1 s=$2; shift 2
  local tag=${v}_$s; [ "$*" = VERSION_CHECK=keep ] && tag=${tag}_nooptout
  precheck "$tag"
  echo "== $tag $(date -u +%H:%M:%SZ) load $(cut -d' ' -f1-3 /proc/loadavg)"
  env "$@" flock timed.lock "$B" verus "$v" "$s" r4 | cut -f1-3,12-15,21-23
}
for s in default 1 2 3 4 5 6 7 8 9 10; do [ -e "$O/4.16.0_$s" ] || cell 4.16.0 "$s"; done
[ -e "$O/5.3.0_default_nooptout" ] || cell 5.3.0 default VERSION_CHECK=keep
for v in 5.3.0 4.15.3; do
  for s in default 1 2 3 4 5 6 7 8 9 10; do [ -e "$O/${v}_$s" ] || cell "$v" "$s"; done
done
echo "== done $(date -u +%H:%M:%SZ)"
