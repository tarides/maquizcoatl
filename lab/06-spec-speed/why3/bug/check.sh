#!/bin/bash
# Experiment #6 milestone 2, WP H (optional, untimed): build Why3's
# current master in a separate opam switch `why3-master` (the `provers`
# switch is left untouched) and run the reproducer with Why3 1.9.0 and
# with master.  Nothing is filed upstream without the maintainer's approval.
#   check.sh <run-id>
set -uo pipefail
: "${BENCH_WORKDIR:?set BENCH_WORKDIR to the bench work directory, <bench-workdir>}"
EXP=${EXP:-$BENCH_WORKDIR/exp/06-spec-speed}
L=$(cd "$(dirname "$0")" && pwd)
. "$BENCH_WORKDIR/cache/env.sh"
OUT=$EXP/m2/out/$1/why3-bug; mkdir -p "$OUT"
B=$EXP/m2/build/why3-bug; mkdir -p "$B"; cp "$L/bug.mlw" "$B/"
run() { # switch label
  for e in "some_list ()" "cons_pair ()" "some_q ()"; do
    echo "== $2: $e"
    ( cd "$B" && opam exec --switch="$1" -- why3 execute -L . bug.mlw --use=Bug "$e" ) 2>&1 | head -5
  done
}
{ echo "why3 (provers): $(opam exec --switch=provers -- why3 --version)"; run provers "1.9.0"; } > "$OUT/provers.txt" 2>&1
if ! opam switch list --short | grep -qx why3-master; then
  opam switch create why3-master ocaml-base-compiler.5.4.1 --no-switch -y -j 12 > "$OUT/switch.log" 2>&1
fi
opam pin add --switch=why3-master -y -n why3 "git+https://gitlab.inria.fr/why3/why3.git#master" >> "$OUT/switch.log" 2>&1
opam install --switch=why3-master -y -j 12 why3 >> "$OUT/switch.log" 2>&1
{ echo "why3 (master): $(opam exec --switch=why3-master -- why3 --version)"
  echo "commit: $(opam show --switch=why3-master why3 -f source-hash,pin 2>/dev/null | tr '\n' ' ')"
  run why3-master "master"; } > "$OUT/master.txt" 2>&1
du -sh "$(opam var --switch=why3-master prefix)" | cut -f1 > "$OUT/switch-size.txt"
