#!/bin/bash
# Experiment #9, correction 8: re-derive the failing columns of run 13's
# modules.tsv and checks.tsv from run 13's own logs with the amended
# fail_items of brittle.sh (nothing is re-run).  Every other column is
# copied unchanged.
#   rederive.sh <repo> <out-dir>
set -euo pipefail
REPO=$1 O=$2 U=$'\x1f'
R=$REPO/lab/results/2026-11-25-exp-09-fstar-m3-raw/fstar
L=$(mktemp -d); trap 'rm -rf "$L"' EXIT
tar xJf "$R/logs.tar.xz" -C "$L"
eval "$(sed -n '/^fail_items() {/,/^}/p' "$REPO/lab/09-representative-proof/brittle.sh")"
mkdir -p "$O"
{ head -1 "$R/modules.tsv"; tail -n +2 "$R/modules.tsv" | while IFS= read -r line; do
    IFS=$U read -r v s l m rc w u sy rss sha q f _ <<< "${line//$'\t'/$U}"
    it=$(fail_items "$L/${v}_${s}${l:+_$l}/$m.log")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$v" "$s" "$l" "$m" "$rc" "$w" "$u" "$sy" "$rss" "$sha" "$q" "$f" "$it"
  done; } > "$O/modules.tsv"
{ head -1 "$R/checks.tsv"; tail -n +2 "$R/checks.tsv" | while IFS= read -r line; do
    IFS=$U read -r -a c <<< "${line//$'\t'/$U}"; FAILING=""
    while IFS= read -r ml; do IFS=$U read -r _ _ _ m rc _ _ _ _ _ _ _ it <<< "${ml//$'\t'/$U}"
      [ -n "$it" ] && FAILING="${FAILING:+$FAILING; }$m: $it"
      [ "$rc" -eq 0 ] || [ -n "$it" ] || FAILING="${FAILING:+$FAILING; }$m: exit $rc"
    done < <(awk -F'\t' -v v="${c[0]}" -v s="${c[1]}" -v l="${c[2]}" '$1==v && $2==s && $3==l' "$O/modules.tsv")
    c[15]=${FAILING:--}; (IFS=$'\t'; echo "${c[*]}")
  done; } > "$O/checks.tsv"
