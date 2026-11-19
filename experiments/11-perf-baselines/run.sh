#!/bin/bash
# Experiment #11, steps 6-8 on the bench host.
# Usage: run.sh <run-label> [check|time|worst|all]
#
# Every output of a run goes under out/<run-label>/, so runs with
# different labels (r1, r2, r3, r4, ...) never share a file. The time
# phase reads the pattern lists written by the check phase of the same
# label, so a run is `run.sh rN all`, or `run.sh rN check` then
# `run.sh rN time`, then `run.sh rN worst`. Before any phase starts,
# run.sh refuses to overwrite an earlier run's timing or worst-case
# outputs, or to redo the check under timing outputs of the same label.
#
# In the time phase, each cell's search is timed by one harness process
# (`time` mode, output in time/) and, in the engine's own column, its
# compilation by another one (`compile` mode, output in compile/, run
# after the search), so that the compile loop cannot change the state
# the search is timed in. A cell with subject bytes is repeated once
# when the range of its repetition times (max - min over median)
# exceeds 10% (spread.py decides). A harness that exits with an error,
# or a time file with fewer than two repetitions, is logged as a
# WARNING line and the run goes on.
#
# The time phase also writes raw-times.tsv: every C, W, T and S line of
# every cell, prefixed by the run label and the cell name (the time or
# compile file's name without .txt; both files of a cell share it). It
# is meant to be committed with the results: `cut -f3-` of one cell's
# rows gives back every line of that cell that spread.py and
# summarise.py read.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/env.sh"
LABEL=${1:-}
[[ $LABEL =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "usage: run.sh <run-label> [check|time|worst|all]" >&2; exit 2; }
RUN="$BENCH/out/$LABEL"; PHASE=${2:-all}
BIN="$BENCH/bin"; WL="$BENCH/workloads/prepared"
ENGINES="onig-threaded onig-switch pcre2-interp pcre2-jit re2 rust-regex ocaml-re"
WORKLOADS="jq php php-legacy vscode vscode-subst"
CPU=${TIME_CPU:-4}
case $PHASE in check|time|worst|all) ;; *) echo "unknown phase $PHASE" >&2; exit 2;; esac
mkdir -p "$RUN"/{check,time,compile,worst}
cd "$RUN"   # harness output never contains paths; relative names only
# Never overwrite an earlier run's results, nor the check outputs they
# were computed from; checked before any phase starts. raw-times.tsv
# counts only once it has a cell row, not just its header.
timed() { grep -q '^[^#]' raw-times.tsv 2>/dev/null || [ -n "$(ls time)$(ls compile)" ]; }
case $PHASE in
  check|time) timed && { echo "STOP: run $LABEL already has timing outputs; use a new run label"; exit 1; } ;;
  worst) [ -s worst/worst.csv ] && { echo "STOP: run $LABEL already has worst-case outputs; use a new run label"; exit 1; } ;;
  all) { timed || [ -s worst/worst.csv ]; } && { echo "STOP: run $LABEL already has results; use a new run label"; exit 1; } ;;
esac
# Run conditions header, once per run label; later phases append samples,
# each with the repository commit and a hash of the binaries then in use.
[ -s provenance.txt ] || "$HERE/provenance.sh" full start > provenance.txt

# Gate before each column. The plan's gate (1-min load average <= 2)
# assumed an idle host; experiment #3's fuzzers share it, pinned to CPUs
# 8-31,40-63, which keeps the global load average far above 2. The gate
# is therefore on the CPUs that matter: the timing CPU, its SMT sibling
# and its L3 complex (4-7, 36-39) must be under 10% busy over 5 s; the
# global load average is still recorded with every sample.
GATE_CPUS="4 5 6 7 36 37 38 39"
busy() { # percent busy of GATE_CPUS over 5 s
  local a b
  a=$(for c in $GATE_CPUS; do grep "^cpu$c " /proc/stat; done)
  sleep 5
  b=$(for c in $GATE_CPUS; do grep "^cpu$c " /proc/stat; done)
  paste <(echo "$a") <(echo "$b") | awk '{n=NF/2; t0=0; t1=0; for(i=2;i<=n;i++){t0+=$i; t1+=$(i+n)}; i0=$5+$6; i1=$(5+n)+$(6+n); T+=t1-t0; I+=i1-i0} END{printf "%d", T? 100*(T-I)/T : 0}'
}
wait_load() {
  local i=0 b
  while b=$(busy); [ "$b" -ge 10 ]; do
    [ $i -ge 20 ] && { echo "gate CPUs still ${b}% busy after 10 min"; return 0; }
    sleep 25; i=$((i+1))
  done
  echo "gate: CPUs $GATE_CPUS ${b}% busy; load $(cut -d' ' -f1-3 /proc/loadavg)"
}

if [ "$PHASE" = check ] || [ "$PHASE" = all ]; then
  "$HERE/provenance.sh" sample before-check >> provenance.txt
  for e in $ENGINES; do for w in $WORKLOADS; do
    echo "taskset -c $BUILD_CPUS $e check $w"
  done; done | xargs -P 4 -I{} sh -c 'set -- {}; taskset -c "$3" "'"$BIN"'/$4" check "'"$WL"'/$6" > "check/$4.$6.txt" 2> "check/$4.$6.err"'
  python3 -I -S "$HERE/agree.py" "$RUN" "$WL" > agree.log || { echo "STOP: switch build differs"; exit 1; }
  # Projection of the timed phase from the one-pass durations.
  python3 -I -S - "$RUN" <<'PY'
import csv, sys
rows = list(csv.DictReader(open(sys.argv[1] + '/agreement.csv')))
tot = 0
for r in rows:
    t = float(r['one_pass_seconds'] or 0); n = int(r['timed_patterns'])
    if n == 0: continue
    # Warm-up, then 5 repetitions that stop on the first pass ending
    # after 0.5 s (so at most 0.5 + t each); x2 for the onig-on-subset run.
    search = (t + (0.5 + t) * 5) * 2
    compile_ = n * 0.02                     # assumes about 20 ms per pattern (N=1000 or 10 ms)
    tot += search + compile_
print('projected timed phase: %.0f s (%.1f min), plus possible repeats and the start of each process'
      ' (workload load and one untimed compilation of every pattern, twice per own cell)' % (tot, tot / 60))
PY
fi

keep_raw() { # time-or-compile-file: append its C, W, T and S lines to raw-times.tsv
  awk -v p="$LABEL\t$(basename "$1" .txt)\t" '/^(C|W|T|S)\t/ { print p $0 }' "$1" >> raw-times.tsv
}

harness() { # mode engine workload only-file outfile: one pinned harness process, stderr appended to the cell's .err
  local m=$1 e=$2 w=$3 only=$4 o=$5 err="${5%.txt}.err" st=0
  case $o in *.repeat.txt) err="${o%.repeat.txt}.err";; esac
  taskset -c $CPU "$BIN/$e" $m "$WL/$w" "$only" > "$o" 2>> "$err" || st=$?
  [ $st = 0 ] || echo "WARNING: $e $m $w exited with status $st; see $err"
  keep_raw "$o"
}

run_cell() { # engine workload only-file outfile: search timing, repeated once by the rule of spread.py
  local e=$1 w=$2 only=$3 o=$4 med iqr sp rng rep
  harness time $e $w "$only" "$o"
  read med iqr sp rng rep < <(python3 -I -S "$HERE/spread.py" "$o")
  case $rep in
    no) ;;
    yes) echo "repeat $e $w range $rng"
         harness time $e $w "$only" "${o%.txt}.repeat.txt" ;;
    *) echo "WARNING: $o has fewer than two repetitions; not repeated" ;;
  esac
}

compile_cell() { # engine workload only-file outfile: compile timing, in its own process
  harness compile "$@"
}

if [ "$PHASE" = time ] || [ "$PHASE" = all ]; then
  [ -n "$(ls only 2>/dev/null)" ] || { echo "STOP: run $LABEL has no pattern lists; run its check phase first"; exit 1; }
  printf '# run\tcell\tC pid compile_ns n | W warmup_s min_rep_s | T rep s_per_pass passes | S key=value...\n' > raw-times.tsv
  for e in $ENGINES; do
    wait_load
    "$HERE/provenance.sh" sample "before-$e" >> provenance.txt
    for w in $WORKLOADS; do
      only="only/$e.$w.txt"
      [ -s "$only" ] || { echo "skip $e $w: no timed pattern"; continue; }
      echo "$(date -u +%H:%M:%S) time $e $w"
      run_cell $e $w "$only" "time/$e.$w.txt"
      compile_cell $e $w "$only" "compile/$e.$w.txt"
      # Oniguruma threaded on this engine's subset (like-for-like ratio);
      # search only: its compile times are those of its own column.
      case $e in onig-*) ;; *) run_cell onig-threaded $w "$only" "time/onig-threaded@$e.$w.txt" ;; esac
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
echo "run $LABEL done"
