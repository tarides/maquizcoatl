#!/bin/sh
# opcodes.sh: optional step. Run probe files through a harness linked
# against an upstream build compiled with -DONIG_DEBUG_COMPILE (see
# probes/README.md), keep the bytecode dumps, and extract, per probe, the
# empty-check and lookbehind opcodes actually emitted.
#
# Usage: probes/opcodes.sh HARNESS OUT_DIR AREA...
#   HARNESS is the harness-debug binary built against the
#   ONIG_DEBUG_COMPILE build. For each AREA (e.g. empty-iterations),
#   OUT_DIR receives <area>.dbgc.stderr (the raw dumps, one block per
#   probe after an "@@probe <id>" line) and <area>.opcodes.tsv with the
#   columns: id, result, empty_check, lookbehind.
#   empty_check: the OP_EMPTY_CHECK_END* opcodes, in code order.
#   lookbehind: the distinct lookbehind-related opcodes (move,
#   step-back-*, mark, cut-to-mark, pop-to-mark, check-position), in
#   order of first appearance. "-" means none; a compile error has no dump.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
H=$1
OUT=$2
shift 2
mkdir -p "$OUT"
for area in "$@"; do
  f="$HERE/$area.tsv"
  "$H" "$f" > "$OUT/$area.dbgc.tsv" 2> "$OUT/$area.dbgc.stderr"
  awk -F'\t' '
    FNR == 1 { file++ }
    file == 1 {
      if ($0 ~ /^@@probe /) { id = substr($0, 9); next }
      if ($0 ~ /^ *[0-9]+: /) {
        split($0, w, " "); op = w[2]
        if (op ~ /^empty-check-end/) ec[id] = ec[id] (ec[id] == "" ? "" : ",") op
        if (op ~ /^(move|step-back-start|step-back-next|mark|cut-to-mark|pop-to-mark|check-position)$/ \
            && index("," lb[id] ",", "," op ",") == 0)
          lb[id] = lb[id] (lb[id] == "" ? "" : ",") op
      }
      next
    }
    $1 == "id" { print "id\tresult\tempty_check\tlookbehind"; next }
    { print $1 "\t" $10 "\t" (ec[$1] == "" ? "-" : ec[$1]) "\t" (lb[$1] == "" ? "-" : lb[$1]) }
  ' "$OUT/$area.dbgc.stderr" "$OUT/$area.dbgc.tsv" > "$OUT/$area.opcodes.tsv"
  rm "$OUT/$area.dbgc.tsv"
done
