#!/usr/bin/env bash
# count-trusted.sh: counts the trusted lines of each prototype.
#
# Usage: count-trusted.sh [TOOL...]   (default: every TOOL/TRUSTED)
#
# TOOL/TRUSTED lists one entry per line, relative to TOOL's directory:
#   FILE            the whole file
#   FILE:START-END  lines START to END (inclusive)
# Text after "#" and blank lines are ignored.
#
# A line counts when it is not blank once comments are removed. Comment
# syntax by extension:
#   c    .c .h                 "//" to end of line, "/* */" (not nested)
#   rust .rs                   "//" to end of line, "/* */" (nested)
#   fstar .fst .fsti           "//" to end of line, "(* *)" (nested):
#                              F*, Pulse
#   ml   .mlw .why .drv .v .thy .ml .mli
#                              "(* *)" (nested): WhyML, Why3 drivers,
#                              Rocq, Isabelle, OCaml
#   lean .lean                 "--" to end of line, "/- -/" (nested)
# Any other extension is counted as raw non-blank lines, marked "raw".
# Comment markers inside string literals are not recognised, and
# Isabelle's text blocks and \<comment> are counted as code.
#
# Output (tab-separated): tool, file, range, language, counted lines,
# sha256 of the whole file; then one "TOTAL" line per tool.

set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

lang_of() {
  case "$1" in
  *.c | *.h) echo c ;;
  *.rs) echo rust ;;
  *.fst | *.fsti) echo fstar ;;
  *.mlw | *.why | *.drv | *.v | *.thy | *.ml | *.mli) echo ml ;;
  *.lean) echo lean ;;
  *) echo raw ;;
  esac
}

# count FILE LANG START END: lines START..END of FILE that are not blank
# after comment removal. Comment state is tracked from line 1.
count() {
  awk -v lang="$2" -v start="$3" -v end="$4" '
    BEGIN {
      depth = 0
      if (lang == "c") { open_ = "/*"; close_ = "*/"; lc = "//"; nest = 0 }
      else if (lang == "rust") { open_ = "/*"; close_ = "*/"; lc = "//"; nest = 1 }
      else if (lang == "ml") { open_ = "(*"; close_ = "*)"; lc = ""; nest = 1 }
      else if (lang == "fstar") { open_ = "(*"; close_ = "*)"; lc = "//"; nest = 1 }
      else if (lang == "lean") { open_ = "/-"; close_ = "-/"; lc = "--"; nest = 1 }
      else { open_ = ""; close_ = ""; lc = ""; nest = 0 }
    }
    function strip(line,   out, i, n, two) {
      out = ""; i = 1; n = length(line)
      while (i <= n) {
        two = substr(line, i, 2)
        if (depth > 0) {
          if (nest && two == open_) { depth++; i += 2; continue }
          if (two == close_) { depth--; i += 2; continue }
          i++; continue
        }
        if (lc != "" && two == lc) break
        if (open_ != "" && two == open_) { depth = 1; i += 2; continue }
        out = out substr(line, i, 1); i++
      }
      return out
    }
    {
      code = strip($0)
      if (NR >= start && NR <= end && code ~ /[^ \t\r]/) n++
    }
    END { print n + 0 }' "$1"
}

if [ $# -eq 0 ]; then
  set --
  for t in "$here"/*/TRUSTED; do
    [ -f "$t" ] || continue
    d=${t%/TRUSTED}
    set -- "$@" "${d##*/}"
  done
fi

printf 'tool\tfile\trange\tlanguage\tlines\tsha256\n'
for tool in "$@"; do
  list=$here/$tool/TRUSTED
  [ -f "$list" ] || { echo "error: no $tool/TRUSTED" >&2; exit 1; }
  total=0
  while IFS= read -r entry || [ -n "$entry" ]; do
    entry=${entry%%#*}
    entry=$(printf '%s' "$entry" | tr -d ' \t\r')
    [ -n "$entry" ] || continue
    file=${entry%%:*}
    path=$here/$tool/$file
    [ -f "$path" ] || { echo "error: $tool/$file: no such file" >&2; exit 1; }
    range=all
    start=1
    end=2147483647
    if [ "$file" != "$entry" ]; then
      range=${entry#*:}
      if ! printf '%s\n' "$range" | grep -Eqx '[0-9]+-[0-9]+'; then
        echo "error: bad range (START-END expected): $entry" >&2
        exit 1
      fi
      start=$((10#${range%-*}))
      end=$((10#${range#*-}))
      lines=$(awk 'END { print NR }' "$path")
      if [ "$start" -lt 1 ] || [ "$start" -gt "$end" ] || [ "$end" -gt "$lines" ]; then
        echo "error: range outside 1-$lines or reversed: $entry" >&2
        exit 1
      fi
    fi
    lang=$(lang_of "$file")
    n=$(count "$path" "$lang" "$start" "$end")
    total=$((total + n))
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$tool" "$file" "$range" "$lang" "$n" \
      "$(sha256sum "$path" | cut -d' ' -f1)"
  done <"$list"
  printf '%s\tTOTAL\t-\t-\t%s\t-\n' "$tool" "$total"
done
