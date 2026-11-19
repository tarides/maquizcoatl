#!/bin/bash
# Timed runs (criterion 2) for one tool: three clean runs one after another,
# serialised across tools by a lock (Decision 3), pinned to the timing CPUs.
# Usage: timed.sh <tool>   (lean|rocq|why3|fstar)
EXP=${EXP:-$HOME/maquizcoatl-work/exp/07-large-tables}
L=$(cd "$(dirname "$0")" && pwd)
exec 9> "$EXP/timed.lock"; flock 9
for r in 1 2 3; do
  mkdir -p "$EXP/out/timed/$1"
  { date -u +%FT%TZ; uptime | sed 's/.*load average/load average/'; } >> "$EXP/out/timed/$1/uptime.txt"
  RUN=$r TCPUS=28-31,60-63 "$L/$1/$1.sh" timed
done
