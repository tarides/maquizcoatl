#!/usr/bin/env bash
# Recorded run i30-run1 of issue #30 (bench host), timed CPU set 24-27,56-59.
set -u
E=$HOME/maquizcoatl-work/exp/05-isabelle-llvm-client
H=$E/repo/experiments/05-unverified-calls
snap() {
  echo "== $1: $(date -u +%FT%TZ)"
  echo "load average: $(cut -d' ' -f1-3 /proc/loadavg)"
  echo "ps -eLo user,psr,pcpu,comm on 24-27,56-59 (pcpu > 0.5):"
  ps -eLo user,psr,pcpu,comm --no-headers |
    awk '(($2>=24&&$2<=27)||($2>=56&&$2<=59)) && $3>0.5 {print "  " $2, $3, $4, ($1==ENVIRON["USER"]?"(this account)":"(other account)")}'
  echo "df: $(df -BG --output=avail "$HOME" | tail -1 | tr -d ' ') free"
}
git -C $E/repo pull -q --ff-only
echo "commit: $(git -C $E/repo rev-parse HEAD)"
echo "cpu: $(lscpu | sed -n 's/^Model name: *//p'), nproc $(nproc)"
snap before
export VU_EXP=$E VU_CACHE=$HOME/maquizcoatl-work/cache/exp05-view VU_CPUS=24-27,56-59 VU_JOBS=4
for m in "" -n -r; do
  echo "== run.sh $m isabelle-llvm i30-run1: $(date -u +%FT%TZ)"
  $H/run.sh $m isabelle-llvm i30-run1
  echo "exit: $?"
done
snap after
