#!/usr/bin/env bash
# probe.sh WORKDIR: run E's RefinedRust probes. (1) probe/, char_len
# alone with EncLen's trait specification: cargo refinedrust, then dune
# checks the generated proof (Qed, no admit). (2) the draft prototype of
# src/: cargo refinedrust only, which reports the unsupported slice
# index of get_subject_byte when its #[rr::skip] is removed. Environment:
# VU_CACHE (its env.sh is sourced). Output on stdout, redacted by the
# caller.
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
: "${VU_CACHE:?}"
. "$VU_CACHE/env.sh"
export OPAMROOT=$VU_OWN_OPAMROOT OPAMSWITCH=refinedrust
w=$1
tc=$(sed -n 's/^channel = "\(.*\)"/\1/p' "$VU_CACHE/refinedrust/src/rr_frontend/rust-toolchain.toml")
rm -rf "$w"; mkdir -p "$w"
echo "refinedrust source: $(git -C "$VU_CACHE/refinedrust/src" rev-parse HEAD), toolchain $tc"
cp -r "$here/probe" "$w/probe"
(cd "$w/probe" && opam exec -- cargo "+$tc" refinedrust 2>&1 | grep -v '^ *Compiling\|^ *Checking')
echo "translate probe: status ${PIPESTATUS[0]}"
(cd "$w/probe/output" && opam exec -- dune build 2>&1)
echo "dune probe: status $?"
grep -rn 'Admitted\|admit' "$w/probe/output" --include=*.v || echo "no Admitted or admit in the probe's Rocq files"
mkdir -p "$w/draft"
cp -r "$here/Cargo.toml" "$here/RefinedRust.toml" "$here/src" "$w/draft/"
python3 -I -c "import sys; p=sys.argv[1]; s=open(p).read(); s=s.replace('#[rr::skip]\npub fn get_subject_byte(','pub fn get_subject_byte('); open(p,'w').write(s)" "$w/draft/src/lib.rs"
(cd "$w/draft" && opam exec -- cargo "+$tc" refinedrust 2>&1 | grep -E '^error' -A4)
echo "translate draft (get_subject_byte not skipped): status ${PIPESTATUS[0]}"
