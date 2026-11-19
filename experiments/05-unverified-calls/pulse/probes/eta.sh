#!/usr/bin/env bash
# eta.sh: reproduces the eta-reduction found while building the Pulse
# prototype. EtaD.eta_d g a is verified to return g a; F* extraction
# eta-reduces its body to g, so both C emitters (KaRaMeL and Custard's
# direct C) give eta_d one parameter and make it return g itself.
# eta_caller.c calls it with proto's two arguments: it links, g is never
# called and the result is a truncated pointer.
#
# Usage: eta.sh WORKDIR (an empty or absent directory). Needs F* and
# krml on PATH and VU_FSTAR_HOME (<cache>/env.sh).
set -euo pipefail
: "${VU_FSTAR_HOME:?}"
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
w=$1
mkdir -p "$w/cache"
cp "$here/EtaD.fst" "$here/eta_caller.c" "$w/"
cd "$w"
fstar=(fstar.exe --cache_checked_modules --cache_dir cache)
"${fstar[@]}" EtaD.fst
echo "== KaRaMeL"
"${fstar[@]}" --codegen KrmlC --custard_entry_module EtaD EtaD.fst --odir krml
krml -skip-compilation -no-prefix EtaD -tmpdir kc krml/Custard.krml >krml.log 2>&1
sed -n '/eta_d/,$p' kc/Custard.c
echo "== Custard direct C"
"${fstar[@]}" --codegen C --custard_entry_module EtaD \
  --custard_c_no_prefix EtaD EtaD.fst --odir dc
sed -n '/eta_d/,$p' dc/Custard.c
echo "== C caller against the KaRaMeL output"
cc -std=gnu11 -Wall -Wextra -I kc -I "$VU_FSTAR_HOME/include/krml" \
  -I "$VU_FSTAR_HOME/lib/krml/dist/minimal" -c kc/Custard.c -o etad.o
cc -std=c11 -Wall -Wextra -Werror eta_caller.c etad.o -o eta_caller
set +e
./eta_caller
echo "eta_caller status=$?"
