#!/bin/bash
# Experiment #11, steps 6-8 on the bench host.
# Usage: run.sh <run-id> [check|time|worst|all]
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/env.sh"
RUN="$BENCH/out/$1"; PHASE=${2:-all}
BIN="$BENCH/bin"; WL="$BENCH/workloads/prepared"
ENGINES="onig-threaded onig-switch pcre2-interp pcre2-jit re2 rust-regex ocaml-re"
WORKLOADS="jq php php-legacy vscode vscode-subst"
CPU=${TIME_CPU:-4}
mkdir -p "$RUN"/{check,time,worst}
cd "$RUN"   # harness output never contains paths; relative names only

wait_load() { # the run is not started while the 1-min load average exceeds 2
  local i=0
  while awk '{exit !($1 > 2)}' /proc/loadavg; do
    [ $i -ge 20 ] && { echo "load still above 2 after 10 min: $(cut -d' ' -f1-3 /proc/loadavg)"; return 0; }
    sleep 30; i=$((i+1))
  done
}

if [ "$PHASE" = check ] || [ "$PHASE" = all ]; then
  "$HERE/provenance.sh" full start > provenance.txt
  for e in $ENGINES; do for w in $WORKLOADS; do
    echo "taskset -c $BUILD_CPUS $e check $w"
  done; done | xargs -P 4 -I{} sh -c 'set -- {}; taskset -c "$3" "'"$BIN"'/$4" check "'"$WL"'/$6" > "check/$4.$6.txt" 2> "check/$4.$6.err"'
  python3 -I "$HERE/agree.py" "$RUN" "$WL" > agree.log || { echo "STOP: switch build differs"; exit 1; }
  # Projection of the timed phase from the one-pass durations.
  python3 -I - "$RUN" <<'PY'
import csv, sys
rows = list(csv.DictReader(open(sys.argv[1] + '/agreement.csv')))
tot = 0
for r in rows:
    t = float(r['one_pass_seconds'] or 0); n = int(r['timed_patterns'])
    if n == 0: continue
    search = max(t, 0.5) * 6 * 2            # warm-up + 5 reps, x2 for the onig-on-subset run
    compile_ = n * 0.02                     # assumes about 20 ms per pattern (N=1000 or 10 ms)
    tot += search + compile_
print('projected timed phase: %.0f s (%.1f min), plus possible repeats' % (tot, tot / 60))
PY
fi

run_cell() { # engine workload only-file outfile [extra env]
  local e=$1 w=$2 only=$3 o=$4; shift 4
  env "$@" taskset -c $CPU "$BIN/$e" time "$WL/$w" "$only" > "$o" 2> "${o%.txt}.err"
  read med iqr sp < <(python3 -I "$HERE/spread.py" "$o")
  if awk -v s="$sp" 'BEGIN{exit !(s > 0.10)}'; then
    echo "repeat $e $w spread $sp"
    env "$@" taskset -c $CPU "$BIN/$e" time "$WL/$w" "$only" > "${o%.txt}.repeat.txt" 2>> "${o%.txt}.err"
  fi
}

if [ "$PHASE" = time ] || [ "$PHASE" = all ]; then
  for e in $ENGINES; do
    wait_load
    "$HERE/provenance.sh" sample "before-$e" >> provenance.txt
    for w in $WORKLOADS; do
      only="only/$e.$w.txt"
      [ -s "$only" ] || { echo "skip $e $w: no timed pattern"; continue; }
      echo "$(date -u +%H:%M:%S) time $e $w"
      run_cell $e $w "$only" "time/$e.$w.txt"
      # Oniguruma threaded on this engine's subset (like-for-like ratio);
      # its compile times are those of its own column.
      case $e in onig-*) ;; *) run_cell onig-threaded $w "$only" "time/onig-threaded@$e.$w.txt" E11_NO_COMPILE=1 ;; esac
    done
    "$HERE/provenance.sh" sample "after-$e" >> provenance.txt
  done
fi

if [ "$PHASE" = worst ] || [ "$PHASE" = all ]; then
  wait_load
  "$HERE/provenance.sh" sample before-worst >> provenance.txt
  "$HERE/worst.sh" "$RUN/worst" > worst/worst.csv
  "$HERE/provenance.sh" sample after-worst >> provenance.txt
fi
"$HERE/provenance.sh" sample end >> provenance.txt
echo "run $1 done"
