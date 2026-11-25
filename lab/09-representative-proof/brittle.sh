#!/bin/bash
# Experiment #9, done-criterion 4 (plan step 7, M3): SMT brittleness.
# One call = one full clean proof check for one (solver version, seed).
#   BENCH_WORKDIR=<bench-workdir> brittle.sh fstar <z3-version> <seed> <run-id> [label]
#     z3-version: one of the Z3 versions bundled with the F* release
#                 (5.3.0 is the baseline the proof was written with)
#     seed:       default (no --z3seed option: F*'s default seed) or N
#     label:      optional tag for a replication row (rerun of the same
#                 configuration), recorded in the label column; never
#                 used to replace a row.
# fstar (run 13): the nine modules Syntax Sem Compile Vm Statement ProofA
# ProofSem ProofSim Proof are copied into a fresh directory with a fresh
# cache/ and checked one file at a time in dependency order, each against
# the .checked files of the ones before it (as timed.sh and axioms.sh), with
#   --z3version V [--z3seed N] --admit_smt_queries false --query_stats
# and no other option: the rlimits, fuel and ifuel are the #push-options
# the proof was written with (not raised).  A module that fails does not
# stop the check: the later modules are still run, and the per-module rows
# say which ones failed.  A later module whose dependency failed does
# not fail on the missing .checked file: F* reports Warning 241 (cannot
# load the dependency's .checked file, will recheck it), rechecks the
# dependency without sending its queries to the solver, checks the module
# itself, reports Warning 247 (its own .checked file not written) and
# exits 0.  Its row then has exit 0, and its failing column carries
# dep-missing:<Dep>(Warning241) and not-written:<Module>(Warning247).
# Pinning: taskset -c $CPUS (default 28-31,60-63, one L3 complex),
# /usr/bin/time -v (CPU time includes the Z3 child), 16G cgroup memory
# cap (as timed.sh), a 30-minute timeout per module (exit 124).  Before
# the check: the 1-minute load average and the busy share of the pinned
# CPUs over one second (from /proc/stat).  Run it under
# flock <exp>/timed.lock, one check at a time.
# Output, under <exp>/out/<run-id>/fstar/brittle/:
#   checks.tsv   one row per call (header written once): version, seed,
#                label, z3 binary version (z3 --version of the binary
#                F* started, read from its "Creating new z3proc" line),
#                start UTC, load1, busy share of the pinned CPUs, exit
#                status (0 if every module checked), modules ok/9, wall
#                s, user s, sys s (sums over the nine modules), peak RSS
#                kB, queries (Query-stats lines), failed query attempts,
#                failing items (module: items of the modules.tsv
#                failing column, for each module that has any or exits
#                non-zero),
#                SHA-256 of the nine sources concatenated in order;
#   modules.tsv  one row per call and module: version, seed, label,
#                module, exit status, wall, user, sys, RSS, SHA-256 of
#                the file, queries, failed attempts, failing items:
#                failed:<definition>,<index>,goal<n> xK for a query (the
#                Query-stats key) that never succeeded after K failed
#                attempts, recovered:<key> xK for one that succeeded on
#                F*'s own fuel/ifuel retry after K failed attempts,
#                Error<n>@<file>(<range>) for each reported error, and
#                dep-missing:<Dep>(Warning241) / not-written:<M>(Warning247)
#                when a dependency's .checked file was missing;
#   <version>_<seed>[_<label>]/<module>.log  the checker's output
#                (query stats and errors), <module>.time (time -v).
# Prints no hostnames, addresses or absolute paths (the work directory
# is replaced by <bench-workdir> in the logs).
set -euo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory}"
T=${1:?tool} V=${2:?z3 version} SEED=${3:?seed} RID=${4:?run-id} LABEL=${5:-}
[ "$T" = fstar ] || { echo "brittle.sh: only fstar is implemented (run 13)" >&2; exit 2; }
case $SEED in default|[0-9]*) ;; *) echo "bad seed $SEED" >&2; exit 2 ;; esac
CACHE=$BENCH_WORKDIR/cache; EXP=$BENCH_WORKDIR/exp/09-representative-proof
L=$EXP/repo/lab/09-representative-proof
CPUS=${CPUS:-28-31,60-63}
OUT=$EXP/out/$RID/$T/brittle; mkdir -p "$OUT"
TAG=${V}_${SEED}${LABEL:+_$LABEL}
D=$OUT/$TAG; [ -e "$D" ] && { echo "brittle.sh: $TAG already recorded; use a label for a replication" >&2; exit 2; }
mkdir -p "$D"
. "$CACHE/env.sh"
MODS="Syntax Sem Compile Vm Statement ProofA ProofSem ProofSim Proof"
SEEDOPT=(); [ "$SEED" = default ] || SEEDOPT=(--z3seed "$SEED")
[ -f "$OUT/checks.tsv" ] || printf 'version\tseed\tlabel\tz3_version\tstart_utc\tload1\tpinned_busy_pct\texit\tmodules_ok\twall_s\tuser_s\tsys_s\tmax_rss_kb\tqueries\tfailed_attempts\tfailing\tsha256_sources\n' > "$OUT/checks.tsv"
[ -f "$OUT/modules.tsv" ] || printf 'version\tseed\tlabel\tmodule\texit\twall_s\tuser_s\tsys_s\tmax_rss_kb\tsha256\tqueries\tfailed_attempts\tfailing\n' > "$OUT/modules.tsv"
[ -f "$OUT/version.txt" ] || fstar.exe --version > "$OUT/version.txt"

# busy share of the pinned CPUs over one second, from /proc/stat
cpulist() { local IFS=,; for r in $CPUS; do case $r in *-*) seq "${r%-*}" "${r#*-}";; *) echo "$r";; esac; done; }
snap() { for c in $(cpulist); do awk -v c="cpu$c" '$1==c{t=0; for(i=2;i<=NF;i++) t+=$i; print c, t, $5+$6}' /proc/stat; done; }
s1=$(snap); sleep 1; s2=$(snap)
BUSY=$(paste <(echo "$s1") <(echo "$s2") | awk '{t+=$5-$2; i+=$6-$3} END{printf "%.1f", 100*(t-i)/t}')
LOAD=$(cut -d' ' -f1 /proc/loadavg)
START=$(date -u +%Y-%m-%dT%H:%M:%SZ)

B=$EXP/build/fstar/$RID-brittle-$TAG; rm -rf "$B"; mkdir -p "$B/cache"; cd "$B"
for m in $MODS; do cp "$L/fstar/$m.fst" .; done
SHA_ALL=$(for m in $MODS; do cat "$m.fst"; done | sha256sum | cut -c1-64)
fail_items() { # from one log: queries that never succeeded (failed:),
  # queries that failed and then succeeded on F*'s own fuel/ifuel retry
  # (recovered:), both by Query-stats key (definition, index, goal) with the
  # number of failed attempts, the reported errors (Error<n>@<file>(<range>)),
  # and the missing-dependency warnings 241 and 247 (see the header)
  awk -F'\t' '/Query-stats/ { n=$2; sub(/.*Query-stats \(/, "", n); sub(/\).*/, "", n); sub(/, /, ",", n)
                 g=$3; sub(/^goal /, "", g); sub(/ .*/, "", g); k=n",goal"g
                 if ($3 ~ /succeeded/) ok[k]=1; else bad[k]++ }
       /^\* Error [0-9]+ at / { e=$0; sub(/^\* Error /, "Error", e); sub(/ at /, "@", e); sub(/:$/, "", e); err[++ne]=e }
       /^\* Warning (241|247) at / { split($0, a, " "); f=a[5]; sub(/\.fst\(.*/, "", f); wl=a[3]; next }
       wl==241 && /\.checked does not exist/ { print "dep-missing:" f "(Warning241)"; wl=""; next }
       wl==247 && /Reason: checked file .*\.checked does not exist/ { print "not-written:" f "(Warning247)"; wl=""; next }
       /^\* / { wl="" }
       END { for (k in bad) printf "%s:%s x%d\n", (k in ok) ? "recovered" : "failed", k, bad[k]
             for (i=1;i<=ne;i++) print err[i] }' "$1" | sort -u | paste -sd';' | sed 's/;/; /g'
}
EXIT=0 OK=0 W=0 U=0 S=0 RSS=0 Q=0 F=0 FAILING=""
for m in $MODS; do
  set +e
  systemd-run --user --scope --quiet -p MemoryMax=16G -p MemorySwapMax=0 \
    /usr/bin/time -v -o "$D/$m.time" \
      taskset -c "$CPUS" timeout 1800 fstar.exe --cache_checked_modules --cache_dir cache \
        --z3version "$V" "${SEEDOPT[@]}" --admit_smt_queries false --query_stats "$m.fst" \
      > "$D/$m.log" 2>&1
  rc=$?
  set -e
  sed -i "s|$BENCH_WORKDIR|<bench-workdir>|g" "$D/$m.log"
  [ $rc -eq 0 ] && OK=$((OK+1)) || EXIT=1
  t() { sed -n "s/.*$1: //p" "$D/$m.time"; }
  wall=$(t 'Elapsed (wall clock) time (h:mm:ss or m:ss)' | awk -F: '{s=0; for(i=1;i<=NF;i++) s=s*60+$i; printf "%.2f", s}')
  user=$(t 'User time (seconds)'); sys=$(t 'System time (seconds)'); rss=$(t 'Maximum resident set size (kbytes)')
  q=$(grep -c 'Query-stats' "$D/$m.log" || true)
  f=$(grep 'Query-stats' "$D/$m.log" | grep -vc 'succeeded' || true)   # failed attempts, retries included
  items=$(fail_items "$D/$m.log")
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$V" "$SEED" "$LABEL" "$m" "$rc" "$wall" "$user" "$sys" "$rss" \
    "$(sha256sum "$m.fst" | cut -c1-64)" "$q" "$f" "$items" >> "$OUT/modules.tsv"
  W=$(echo "$W + $wall" | bc); U=$(echo "$U + $user" | bc); S=$(echo "$S + $sys" | bc)
  [ "$rss" -gt "$RSS" ] && RSS=$rss
  Q=$((Q+q)); F=$((F+f))
  [ -n "$items" ] && FAILING="${FAILING:+$FAILING; }$m: $items"
  [ $rc -eq 0 ] || [ -n "$items" ] || FAILING="${FAILING:+$FAILING; }$m: exit $rc"
done
# the Z3 binary F* actually started, and its own --version
Z3BIN=$(grep -h -o 'Creating new z3proc (cmd=\[("[^"]*"' "$D"/*.log | head -1 | sed 's/.*("//; s/"$//; s|<bench-workdir>|'"$BENCH_WORKDIR"'|')
Z3VER=$([ -n "$Z3BIN" ] && "$Z3BIN" --version || echo "no z3 process started")
grep -h -o 'Creating new z3proc ([^)]*)[^)]*)' "$D"/*.log | sort | uniq -c > "$D/z3procs.txt" || true
echo "$Z3VER" >> "$D/z3procs.txt"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s/9\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$V" "$SEED" "$LABEL" "$Z3VER" "$START" "$LOAD" "$BUSY" \
  "$EXIT" "$OK" "$W" "$U" "$S" "$RSS" "$Q" "$F" "${FAILING:--}" "$SHA_ALL" >> "$OUT/checks.tsv"
tail -1 "$OUT/checks.tsv"
