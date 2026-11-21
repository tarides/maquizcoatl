#!/usr/bin/env bash
# setup.sh: installs and smoke-tests the toolchains of one milestone of
# experiment #5. Idempotent: what is already installed and checked is
# kept.
#
# Usage: setup.sh MILESTONE [COMPONENT...]
#
#   Milestone 1 components: base fstar why3 rust verus smoke-why3
#                           smoke-pulse smoke-verus
#   Milestone 2 components: base aeneas aeneas-lean vst isabelle-llvm llvm
#                           smoke-aeneas smoke-vst smoke-isabelle-llvm
#   Milestone 3 components: base hax smoke-hax hax-fstar hax-lean creusot
#                           refinedrust (added by run C of the pipeline)
#   Milestone 4 components: base bedrock2 cn refinedc (added by run D of
#                           the pipeline: disk checks only, installs not
#                           written)
#   (default: all of the milestone, in that order; "base" always runs)
#
# Environment:
#   VU_CACHE         this account's toolchain cache (written; <cache>)
#   VU_EXP           the experiment directory (written; <exp>)
#   VU_SHARED_CACHE  experiment #7's toolchain cache, used read only
#                    (Why3 and Alt-Ergo in its opam switch "provers", and
#                    its opam binary); optional for milestone 2. Its F*
#                    is not used: its checked library files are readable
#                    only by their owner, so F* (same release, with krml
#                    and Z3) is installed into VU_CACHE
#   VU_CPUS          CPU list (required), checked against the reserved
#                    CPUs and the CPUs other processes pin, at start and
#                    again before vst and isabelle-llvm; the script pins
#                    itself to it and lowers its priority, so that every
#                    command it runs is pinned and niced
#   VU_JOBS          parallel jobs, capped by lib.sh (12 for vst and
#                    isabelle-llvm, 4 otherwise)
#   VU_ISABELLE_LLVM_OK=1  required for isabelle-llvm: the operator has
#                    checked on issue #7 that experiment #4's mechanism 4
#                    is not running
#   VU_MIN_FREE_GB   (default 20) milestone 3 and 4 steps refuse to install
#                    when less than this many GB would remain free after
#                    the install, estimated by pins.json's disk_gb
#
# Logs go to VU_EXP/out/setup-m<MILESTONE>/<component>.log, disk use
# (through the links of a view) and free space to disk.txt there.
# Nothing printed names the host, a user or an absolute
# path. The last line printed is "SETUP-END m<N> status=<0|1>", also when
# the arguments or the environment are refused.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

status=1
trap 'echo "SETUP-END m${milestone:-?} status=$status"' EXIT
[ $# -ge 1 ] || vu_die "usage: setup.sh MILESTONE [COMPONENT...]"
milestone=$1
shift
case "$milestone" in
1) all=(fstar why3 rust verus smoke-why3 smoke-pulse smoke-verus) ;;
2) all=(aeneas aeneas-lean vst isabelle-llvm llvm smoke-aeneas smoke-vst
  smoke-isabelle-llvm) ;;
3) all=(hax smoke-hax hax-fstar hax-lean creusot refinedrust) ;;
4) all=(bedrock2 cn refinedc) ;;
*) vu_die "unknown milestone: $milestone" ;;
esac
if [ $# -eq 0 ]; then
  components=("${all[@]}")
else
  components=("$@")
fi

vu_need_env VU_CACHE VU_EXP VU_CPUS
vu_check_cpus "$VU_CPUS" || vu_die "VU_CPUS refused (see above)"
taskset -pc "$VU_CPUS" $$ >/dev/null
renice -n 10 -p $$ >/dev/null
logdir=$VU_EXP/out/setup-m$milestone
mkdir -p "$VU_CACHE/dl" "$VU_EXP/build" "$VU_EXP/out" "$logdir"
vu_need_jq

# step_header NAME: the head of each step log: when it started, the CPU
# set and priority the step runs with, and its job count (added after
# the review of run A, which found these only in the replays' logs).
step_header() {
  echo "step: $1"
  echo "start_utc: $(date -u +%FT%TZ)"
  echo "cpu_set: $(taskset -pc "$BASHPID" | sed 's/.*: //')"
  echo "nice: $(nice)"
  echo "VU_JOBS: ${VU_JOBS:-unset} (jobs for this step: $(vu_jobs "$1"))"
}

# step NAME FUNCTION: runs FUNCTION with its output in NAME.log
# (redacted), then records its time and the disk use of the cache.
failed=()
step() {
  local name=$1 fn=$2 start rc
  start=$(date +%s)
  vu_log "== $name"
  set +e
  ( set -euo pipefail; step_header "$name"; "$fn" ) 2>&1 | vu_redact >"$logdir/$name.log"
  rc=${PIPESTATUS[0]}
  set -e
  # The cache may be a view (a directory of links, see setup-pipeline.sh):
  # vu_du_links measures through them (review of run C, problem 6).
  vu_log "$name: status=$rc time=$(($(date +%s) - start))s cache=$(vu_du_links "$VU_CACHE") free=$(vu_free "$VU_CACHE")"
  printf '%s\t%s\t%s\t%s\n' "$name" "$(date -u +%FT%TZ)" "$(vu_du_links "$VU_CACHE")" \
    "$(vu_free "$VU_CACHE")" >>"$logdir/disk.txt"
  [ "$rc" = 0 ] || failed+=("$name")
}

# need_cpus: re-checks VU_CPUS before a heavy step, since another
# experiment may have pinned CPUs since the start.
need_cpus() {
  vu_check_cpus "$VU_CPUS" || vu_die "VU_CPUS refused (see above)"
}

# ---------------------------------------------------------------- base

# find_exe DIR NAME: the first executable file called NAME under DIR.
find_exe() {
  find "$1" -name "$2" -type f -executable 2>/dev/null | sort | head -n 1
}

# untar URL SHA256 NAME DIR: fetches URL into the download cache and
# extracts it into DIR (once). It extracts into a temporary directory
# and renames it, so an interrupted extraction is redone on the next
# run.
untar() {
  local url=$1 sum=$2 name=$3 dir=$4
  [ -d "$dir" ] && return 0
  vu_fetch "$url" "$sum" "$VU_CACHE/dl/$name"
  rm -rf "$dir.tmp"
  mkdir -p "$dir.tmp"
  tar -xf "$VU_CACHE/dl/$name" -C "$dir.tmp"
  mv "$dir.tmp" "$dir"
}

write_env() {
  if [ -n "${VU_SHARED_CACHE:-}" ]; then
    [ -r "$VU_SHARED_CACHE" ] || vu_die "VU_SHARED_CACHE is not readable"
  fi
  mkdir -p "$VU_CACHE/why3/bin" "$VU_CACHE/bin"
  {
    echo '# env.sh: generated by setup.sh of experiment #5; sourced by every'
    echo '# command of the experiment. Regenerated on each setup run.'
    echo 'VU_CACHE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)'
    echo 'export VU_CACHE'
    printf 'export VU_SHARED_CACHE=%q\n' "${VU_SHARED_CACHE:-}"
    echo 'export RUSTUP_HOME="$VU_CACHE/rustup" CARGO_HOME="$VU_CACHE/cargo"'
    echo 'export ELAN_HOME="$VU_CACHE/elan"'
    echo 'export WHY3CONFIG="$VU_CACHE/why3/why3.conf"'
    echo 'export VU_OWN_OPAMROOT="$VU_CACHE/opam"'
    echo 'export VU_FSTAR_HOME="$VU_CACHE/fstar/current"'
    echo 'export VU_WHY3_Z3="$VU_CACHE/why3/bin/z3"'
    echo '_vu_path() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH" ;; esac; }'
    if [ -n "${VU_SHARED_CACHE:-}" ]; then
      echo '_vu_path "$VU_SHARED_CACHE/opam/provers/bin"'
    fi
    echo '_vu_path "$VU_FSTAR_HOME/bin"'
    echo '_vu_path "$VU_CACHE/why3/bin"'
    echo '_vu_path "$VU_CACHE/bin"'
    echo '_vu_path "$CARGO_HOME/bin"'
    echo '_vu_path "$ELAN_HOME/bin"'
    echo '_vu_path "$VU_CACHE/verus/current"'
    echo '_vu_path "$VU_CACHE/aeneas/current/bin"'
    echo '_vu_path "$VU_CACHE/llvm/current"'
    echo '_vu_path "$VU_CACHE/isabelle/bin"'
    echo '_vu_path "$VU_CACHE/hax/current/bin"'
    echo 'export PATH'
  } >"$VU_CACHE/env.sh.new"
  mv "$VU_CACHE/env.sh.new" "$VU_CACHE/env.sh"
}

step_base() {
  write_env
  echo "env.sh written"
  echo "gcc: $(gcc --version | head -n 1)"
  echo "cmake: $(cmake --version | head -n 1)"
  echo "shared cache: ${VU_SHARED_CACHE:+set}"
  df -h "$VU_CACHE" | tail -n 1 | awk '{ print "disk free: " $4 }'
}

# ------------------------------------------------------------ milestone 1

# F* binary release, with its krml and its Z3 versions, in
# VU_CACHE/fstar/VERSION; VU_CACHE/fstar/current points to its root.
step_fstar() {
  local v dir bin
  v=$(vu_pin .fstar.version)
  dir=$VU_CACHE/fstar/$v
  mkdir -p "$VU_CACHE/fstar"
  untar "$(vu_pin .fstar.url)" "$(vu_pin .fstar.sha256)" \
    "fstar-$v-Linux-x86_64.tar.gz" "$dir"
  bin=$(find_exe "$dir" fstar.exe)
  [ -n "$bin" ] || vu_die "no fstar.exe in the F* release"
  ln -sfn "$(dirname "$(dirname "$bin")")" "$VU_CACHE/fstar/current"
  fstar.exe --version
  krml -version
  find "$VU_FSTAR_HOME/" -name z3 -type f -executable | sort |
    while IFS= read -r z; do echo "bundled: $("$z" --version)"; done
  echo "fstar: $(vu_du "$dir")"
}

# The Z3 that Why3 1.9.0 accepts (4.8.x-4.15.x): 4.15.3, else 4.13.3,
# from the F* bundle.
find_why3_z3() {
  local z v want
  for want in $(vu_pin '.why3.z3[]'); do
    while IFS= read -r z; do
      v=$("$z" --version 2>/dev/null || true)
      case "$v" in *"version $want "*) echo "$z"; return 0 ;; esac
    done < <(find "$VU_FSTAR_HOME/" -name z3 -type f -executable | sort)
  done
  return 1
}

step_why3() {
  local z3
  vu_need_env VU_SHARED_CACHE
  command -v why3 >/dev/null || vu_die "why3 not found in the switch provers"
  why3 --version
  echo "alt-ergo --version: $(alt-ergo --version)"
  z3=$(find_why3_z3) || vu_die "no Z3 4.15.3 or 4.13.3 in the F* bundle: run setup.sh 1 fstar"
  ln -sfn "$z3" "$VU_WHY3_Z3"
  echo "z3 for why3: $("$VU_WHY3_Z3" --version)"
  # Detection takes the first z3 on PATH; Verus's directory, also on
  # PATH, holds a Z3 that Why3 1.9.0 does not know.
  if [ ! -f "$WHY3CONFIG" ]; then
    PATH="$(dirname "$VU_WHY3_Z3"):$PATH" why3 config detect
  fi
  why3 config list-provers
  local want
  want=$("$VU_WHY3_Z3" --version | awk '{ print $3 }')
  why3 config list-provers | grep -qx "Z3 $want" ||
    vu_die "Why3's Z3 is not $want: remove <cache>/why3/why3.conf and rerun"
}

step_rust() {
  local init
  init=$VU_CACHE/dl/rustup-init-$(vu_pin .rustup.version)
  if [ ! -x "$CARGO_HOME/bin/rustup" ]; then
    vu_fetch "$(vu_pin .rustup.url)" "$(vu_pin .rustup.sha256)" "$init"
    chmod +x "$init"
    "$init" -y --no-modify-path --profile minimal --default-toolchain none
  fi
  rustup --version
  local tc comps
  tc=$(vu_pin .verus.rust)
  comps=$(vu_pin '.verus.rust_components | join(",")')
  vu_pinned rustup toolchain install "$tc" --profile minimal --component "$comps"
  rustup toolchain list
  echo "rustup+cargo: $(vu_du "$RUSTUP_HOME") $(vu_du "$CARGO_HOME")"
}

step_verus() {
  local v zip dir
  v=$(vu_pin .verus.version)
  zip=$VU_CACHE/dl/verus-$v-x86-linux.zip
  dir=$VU_CACHE/verus/$v
  if [ ! -d "$dir" ]; then
    vu_fetch "$(vu_pin .verus.url)" "$(vu_pin .verus.sha256)" "$zip"
    rm -rf "$dir.tmp"
    mkdir -p "$dir.tmp"
    unzip -q "$zip" -d "$dir.tmp"
    mv "$dir.tmp" "$dir"
  fi
  local bin
  bin=$(find_exe "$dir" verus)
  [ -n "$bin" ] || vu_die "no verus binary in the release"
  ln -sfn "$(dirname "$bin")" "$VU_CACHE/verus/current"
  verus --version
  echo "verus: $(vu_du "$dir")"
}

smoke_why3() {
  local d=$VU_EXP/build/smoke/why3
  rm -rf "$d"
  mkdir -p "$d"
  cat >"$d/smoke.mlw" <<'EOF'
module Smoke
  use int.Int
  use mach.int.Int32

  let add1 (x: int32) : int32
    requires { x < 100 }
    ensures { result = x + 1 }
  = x + 1
end
EOF
  why3 prove -P alt-ergo "$d/smoke.mlw"
  why3 prove -P z3 "$d/smoke.mlw"
  why3 extract -D c -o "$d/smoke.c" "$d/smoke.mlw"
  cc -std=c11 -c "$d/smoke.c" -o "$d/smoke.o"
  echo "why3 smoke: ok"
}

smoke_pulse() {
  local d=$VU_EXP/build/smoke/pulse
  rm -rf "$d"
  mkdir -p "$d"
  cat >"$d/Smoke.fst" <<'EOF'
module Smoke
#lang-pulse
open Pulse

fn add1 (x: UInt32.t)
  requires pure (UInt32.v x < 100)
  returns r: UInt32.t
  ensures pure (UInt32.v r == UInt32.v x + 1)
{
  UInt32.add x 1ul
}
EOF
  # The commands of experiment #7 for F* v2026.11.15: check (which
  # writes the .checked file extraction needs), extract to krml's AST
  # (one Custard.krml for the entry points), krml to C, compile.
  local fstar=(fstar.exe --cache_checked_modules --cache_dir cache)
  (cd "$d" && mkdir cache && "${fstar[@]}" Smoke.fst)
  (cd "$d" && "${fstar[@]}" --codegen KrmlC --custard_entry Smoke.add1 \
    Smoke.fst --odir krml)
  (cd "$d" && krml -skip-compilation -tmpdir kc krml/Custard.krml)
  # gnu11: krmllib's endianness macros use htole64 and friends, which
  # glibc declares only outside strict ISO C.
  (cd "$d" && cc -std=gnu11 -c -I kc -I "$VU_FSTAR_HOME/include/krml" \
    -I "$VU_FSTAR_HOME/lib/krml/dist/minimal" kc/Custard.c -o smoke.o)
  grep -n 'add1' "$d/kc/Custard.c"
  echo "pulse smoke: ok"
}

smoke_verus() {
  local d=$VU_EXP/build/smoke/verus
  rm -rf "$d"
  mkdir -p "$d"
  cat >"$d/smoke.rs" <<'EOF'
use vstd::prelude::*;

verus! {

fn add1(x: u32) -> (r: u32)
    requires x < 100,
    ensures r == x + 1,
{
    x + 1
}

fn main() {
    let _ = add1(1);
}

} // verus!
EOF
  (cd "$d" && verus smoke.rs)
  (cd "$d" && verus smoke.rs --compile -o smoke && ./smoke)
  echo "verus smoke: ok"
}

# Each smoke test is its own step, so that set -e applies inside it.

# ------------------------------------------------------------ milestone 2

# Aeneas release binaries, with the Charon they bundle (see pins.json:
# the standalone Charon release is not used).
step_aeneas() {
  local root tag f
  tag=$(vu_pin .aeneas.tag)
  root=$VU_CACHE/aeneas/$tag
  mkdir -p "$root" "$VU_CACHE/aeneas/current/bin"
  untar "$(vu_pin .aeneas.url)" "$(vu_pin .aeneas.sha256)" \
    "aeneas-$tag.tar.gz" "$root/aeneas"
  untar "$(vu_pin .aeneas.lean_build_url)" "$(vu_pin .aeneas.lean_build_sha256)" \
    "lean-build-aeneas-$tag.tar.gz" "$root/lean-build"
  for f in charon charon-driver aeneas; do
    [ -x "$root/aeneas/$f" ] || vu_die "no $f in the Aeneas release"
    ln -sfn "$root/aeneas/$f" "$VU_CACHE/aeneas/current/bin/$f"
  done
  case "$(charon version)" in
  *"($(vu_pin .charon.commit))"*) ;;
  *) vu_die "the bundled Charon is not commit $(vu_pin .charon.commit)" ;;
  esac
  # Charon's Rust toolchain.
  [ -x "$CARGO_HOME/bin/rustup" ] || vu_die "rustup missing: run setup.sh 1 rust"
  vu_pinned rustup toolchain install "$(vu_pin .charon.rust)" --profile minimal \
    --component "$(vu_pin '.charon.rust_components | join(",")')"
  # elan and Aeneas's Lean, in this account's cache.
  if [ ! -x "$ELAN_HOME/bin/elan" ]; then
    local e
    e=$VU_CACHE/dl/elan-$(vu_pin .elan.version)
    untar "$(vu_pin .elan.url)" "$(vu_pin .elan.sha256)" \
      "elan-$(vu_pin .elan.version).tar.gz" "$e"
    "$e/elan-init" -y --no-modify-path --default-toolchain none
  fi
  elan --version
  elan toolchain install "$(vu_pin .aeneas.lean)"
  echo "charon $(charon version) toolchain $(charon toolchain-version)"
  # sed, not head: head would close the pipe early and pipefail would
  # turn the SIGPIPE into a failure of the step.
  aeneas -help 2>&1 | sed -n 1p
  echo "aeneas tree: $(vu_du "$root") elan: $(vu_du "$ELAN_HOME")"
}

# Aeneas's Lean library, ready for `lake env lean`: a writable copy of
# the release's backends/lean (the release tree is left as fetched), its
# Lake dependencies at the commits of its lake-manifest.json, Mathlib's
# prebuilt oleans (`lake exe cache get`) and the release's prebuilt
# build of Aeneas itself (lean-build), so that nothing is rebuilt.
step_aeneas_lean() {
  local root lean
  root=$VU_CACHE/aeneas/$(vu_pin .aeneas.tag)
  lean=$root/lean
  [ -d "$root/aeneas/backends/lean" ] || vu_die "run setup.sh 2 aeneas first"
  if [ ! -d "$lean" ]; then
    rm -rf "$lean.tmp"
    cp -r "$root/aeneas/backends/lean" "$lean.tmp"
    mv "$lean.tmp" "$lean"
  fi
  cd "$lean"
  [ "$(cat lean-toolchain)" = "$(vu_pin .aeneas.lean)" ] ||
    vu_die "lean-toolchain is not $(vu_pin .aeneas.lean)"
  if [ ! -d .lake/build/lib ]; then
    mkdir -p .lake
    rm -rf .lake/build.tmp
    cp -r "$root/lean-build" .lake/build.tmp
    mv .lake/build.tmp .lake/build
  fi
  vu_pinned lake exe cache get
  vu_pinned lake build Aeneas AeneasMeta
  echo "mathlib commit: $(git -C .lake/packages/mathlib rev-parse HEAD)"
  echo "aeneas lean: $(vu_du "$lean")"
}

smoke_aeneas() {
  local d=$VU_EXP/build/smoke/aeneas lean
  lean=$VU_CACHE/aeneas/$(vu_pin .aeneas.tag)/lean
  rm -rf "$d"
  mkdir -p "$d"
  cat >"$d/smoke.rs" <<'EOF'
pub fn add1(x: u32) -> u32 {
    if x < 100 { x + 1 } else { x }
}
EOF
  (cd "$d" && charon rustc --preset=aeneas --dest-file smoke.llbc -- \
    --crate-type=lib smoke.rs)
  (cd "$d" && aeneas -backend lean -dest out smoke.llbc)
  # The proof goes after the generated definitions, in the same file.
  cat "$d/out/Smoke.lean" - >"$d/SmokeProof.lean" <<'EOF'

namespace smoke

theorem add1_spec (x : Std.U32) (h : x.val < 100) :
    add1 x ⦃ y => y.val = x.val + 1 ⦄ := by
  unfold add1
  simp only [show x < 100#u32 from by scalar_tac, ite_true]
  step as ⟨y, hy⟩
  scalar_tac

end smoke
EOF
  (cd "$lean" && vu_pinned lake env lean "$d/SmokeProof.lean")
  echo "aeneas smoke: ok"
}

step_vst() {
  need_cpus
  local jobs opam
  jobs=$(vu_jobs vst)
  export OPAMROOT=$VU_OWN_OPAMROOT OPAMYES=1 OPAMCOLOR=never
  opam=$VU_CACHE/bin/opam
  if [ ! -x "$opam" ]; then
    vu_need_env VU_SHARED_CACHE
    install -m 755 "$VU_SHARED_CACHE/bin/opam" "$opam"
  fi
  echo "opam $("$opam" --version) sha256=$(vu_sha256 "$opam")"
  if [ ! -f "$OPAMROOT/config" ]; then
    local sandbox=()
    command -v bwrap >/dev/null || sandbox=(--disable-sandboxing)
    echo "opam sandboxing: ${sandbox[*]:-enabled}"
    "$opam" init --bare --no-setup "${sandbox[@]}" default https://opam.ocaml.org
  fi
  # --no-switch: creating the switch must not change the default switch
  # of a shared opam root (run A did; see the run A corrections entry).
  if ! "$opam" switch list --short | grep -qx vst; then
    "$opam" switch create vst --empty --no-switch
  fi
  if ! "$opam" repo list --this-switch --switch vst --short | grep -qx rocq-released; then
    "$opam" repo add --switch vst --this-switch rocq-released "$(vu_pin .vst.opam_repository)"
  fi
  local pkgs
  read -r -a pkgs <<<"$(vu_pin '.vst.opam_packages | join(" ")')"
  vu_pinned "$opam" install --switch vst --jobs="$jobs" ocaml-base-compiler \
    "${pkgs[@]}"
  "$opam" list --switch vst --installed --columns=name,version \
    ocaml coq coq-core rocq-core coq-compcert coq-vst 2>/dev/null || true
  "$opam" exec --switch vst -- coqc --version
  "$opam" exec --switch vst -- clightgen -version
  echo "opam root: $(vu_du "$OPAMROOT")"
}

# A C function translated by clightgen and proved against a VST funspec.
smoke_vst() {
  local d=$VU_EXP/build/smoke/vst
  export OPAMROOT=$VU_OWN_OPAMROOT OPAMCOLOR=never
  local run=("$VU_CACHE/bin/opam" exec --switch vst --)
  rm -rf "$d"
  mkdir -p "$d"
  cat >"$d/smoke.c" <<'EOF'
int add1(int x) { return x + 1; }
EOF
  cat >"$d/verif_smoke.v" <<'EOF'
Require Import VST.floyd.proofauto.
Require Import Smoke.smoke.
#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition add1_spec : ident * funspec :=
  DECLARE _add1
  WITH x : Z
  PRE [ tint ]
    PROP (Int.min_signed <= x < Int.max_signed)
    PARAMS (Vint (Int.repr x))
    SEP ()
  POST [ tint ]
    PROP () RETURN (Vint (Int.repr (x + 1))) SEP ().

Definition Gprog : funspecs := [add1_spec].

Lemma body_add1 : semax_body Vprog Gprog f_add1 add1_spec.
Proof. start_function. forward. Qed.
EOF
  (cd "$d" && "${run[@]}" clightgen -normalize smoke.c)
  (cd "$d" && vu_pinned "${run[@]}" coqc -Q . Smoke smoke.v)
  (cd "$d" && vu_pinned "${run[@]}" coqc -Q . Smoke verif_smoke.v)
  echo "vst smoke: ok"
}

isabelle_llvm_guard() {
  [ "${VU_ISABELLE_LLVM_OK:-}" = 1 ] ||
    vu_die "set VU_ISABELLE_LLVM_OK=1 once issue #7 says experiment #4's mechanism 4 is not running"
  local others
  others=$(ps -eo comm=,args= |
    awk '$1 == "poly" || $0 ~ /Isabelle20[0-9][0-9]/' | wc -l)
  [ "$others" = 0 ] ||
    vu_die "Isabelle or Poly/ML is already running: experiment #4's mechanism 4 must run alone"
}

step_isabelle_llvm() {
  need_cpus
  isabelle_llvm_guard
  local jobs root v dist afp afpv llvm
  jobs=$(vu_jobs isabelle-llvm)
  root=$VU_CACHE/isabelle
  v=$(vu_pin .isabelle.version)
  dist=$root/dist/$v
  mkdir -p "$root/home" "$root/bin"
  # untar extracts into a temporary directory and renames it, so an
  # interrupted extraction is redone on the next run.
  untar "$(vu_pin .isabelle.url)" "$(vu_pin .isabelle.sha256)" \
    "${v}_linux.tar.gz" "$root/dist"
  [ -x "$dist/bin/isabelle" ] || vu_die "no bin/isabelle in the $v tarball"
  # Isabelle keeps its settings and heaps under $HOME/.isabelle: a
  # wrapper points HOME into the cache so the account's home is
  # untouched.
  cat >"$root/bin/isabelle" <<WRAPPER
#!/bin/sh
HOME="\$(dirname "\$0")/../home" exec "\$(dirname "\$0")/../dist/$v/bin/isabelle" "\$@"
WRAPPER
  chmod +x "$root/bin/isabelle"
  isabelle version
  afpv=$(vu_pin .afp.version)
  untar "$(vu_pin .afp.url)" "$(vu_pin .afp.sha256)" "$afpv.tar.gz" "$root/$afpv"
  afp=$root/$afpv/$afpv
  [ -d "$afp/thys" ] || vu_die "no thys directory in $afpv"
  echo "afp release: $afpv"
  llvm=$root/isabelle_llvm
  if [ ! -d "$llvm/.git" ]; then
    git clone --quiet --branch "$(vu_pin '.["isabelle-llvm"].branch')" \
      "$(vu_pin '.["isabelle-llvm"].repository')" "$llvm"
  fi
  git -C "$llvm" checkout --quiet "$(vu_pin '.["isabelle-llvm"].commit')"
  echo "isabelle_llvm commit: $(git -C "$llvm" rev-parse HEAD)"
  local par=$((jobs / 4))
  [ "$par" -ge 1 ] || par=1
  vu_pinned /usr/bin/time -v isabelle build -b -j "$par" -o threads=4 \
    -d "$afp/thys" -d "$llvm/thys" "$(vu_pin '.["isabelle-llvm"].session')"
  echo "isabelle tree: $(vu_du "$root")"
}

# LLVM release binaries (clang, llc), to compile the LLVM IR that
# Isabelle-LLVM emits: the bench host has no LLVM.
step_llvm() {
  local v dir bin
  v=$(vu_pin .llvm.version)
  dir=$VU_CACHE/llvm/$v
  mkdir -p "$VU_CACHE/llvm"
  untar "$(vu_pin .llvm.url)" "$(vu_pin .llvm.sha256)" "LLVM-$v-Linux-X64.tar.xz" "$dir"
  bin=$(find_exe "$dir" llc)
  [ -n "$bin" ] || vu_die "no llc in the LLVM release"
  ln -sfn "$(dirname "$bin")" "$VU_CACHE/llvm/current"
  clang --version | sed -n 1p
  llc --version | sed -n 2p
  echo "llvm: $(vu_du "$dir")"
}

# An Isabelle-LLVM function with a VCG proof, exported by export_llvm,
# compiled with clang and called from C.
smoke_isabelle_llvm() {
  need_cpus
  isabelle_llvm_guard
  local d=$VU_EXP/build/smoke/isabelle-llvm root afp jobs
  jobs=$(vu_jobs isabelle-llvm)
  root=$VU_CACHE/isabelle
  afp=$root/$(vu_pin .afp.version)/$(vu_pin .afp.version)
  rm -rf "$d"
  mkdir -p "$d"
  cat >"$d/ROOT" <<'EOF2'
session Smoke = Isabelle_LLVM +
  theories Smoke
EOF2
  cat >"$d/Smoke.thy" <<'EOF2'
theory Smoke
  imports Isabelle_LLVM.LLVM_DS_All
begin

definition add1 :: "32 word \<Rightarrow> 32 word llM" where [llvm_code]:
  "add1 x \<equiv> Mreturn (x + unsigned 1)"

lemma add1_correct:
  "llvm_htriple (\<upharpoonleft>uint.assn n x ** \<up>(n + 1 \<in> uints 32))
     (add1 x) (\<lambda>r. \<upharpoonleft>uint.assn (n + 1) r ** \<upharpoonleft>uint.assn n x)"
  unfolding add1_def
  apply vcg_monadify
  apply vcg'
  done

export_llvm add1 is "uint32_t add1 (uint32_t)" file "smoke.ll"

end
EOF2
  cat >"$d/main.c" <<'EOF2'
#include <stdint.h>
#include <stdio.h>
uint32_t add1(uint32_t);
int main(void) { printf("%u\n", add1(41)); return add1(41) != 42; }
EOF2
  # -c: export_llvm writes smoke.ll only when the theory is processed,
  # and an unchanged session would otherwise be skipped.
  vu_pinned isabelle build -c -j 1 -o threads="$jobs" -d "$afp/thys" \
    -d "$root/isabelle_llvm/thys" -D "$d"
  (cd "$d" && clang -c smoke.ll -o smoke.o && cc main.c smoke.o -o smoke && ./smoke)
  echo "isabelle-llvm smoke: ok"
}

# ------------------------------------------------------------ milestone 3

# need_disk NAME GB: refuses step NAME (status 2, "refused") when less
# than VU_MIN_FREE_GB would remain free after an install of about GB.
need_disk() {
  local free floor=${VU_MIN_FREE_GB:-20}
  free=$(df -BG --output=avail "$VU_CACHE/" | tail -n 1 | tr -dc 0-9)
  echo "disk: ${free} GB free, install estimate $2 GB, floor ${floor} GB"
  if [ $((free - $2)) -lt "$floor" ]; then
    echo "REFUSED: $1 would leave $((free - $2)) GB, under the floor of ${floor} GB"
    exit 2
  fi
}

# hax: the full toolchain of the tag, as its setup.sh builds it (the
# release binary is a standalone cargo-hax that only runs the Lean
# backend): the Rust binaries of cli/driver, cli/cargo-hax (feature
# legacy-engine), engine/names/extract and rust-engine, installed with
# cargo install --locked into VU_CACHE/hax/TAG (bin/), and the OCaml
# engine (hax-engine) in the opam switch "hax" (OCaml 5.4.1, as the
# tag's setup.sh requires) of the cache's opam root, created with
# --no-switch so that the root's default switch is untouched. The cargo
# build directory is VU_EXP/build/hax-target, removed after the install
# as the tag's setup.sh does with cargo clean. The release binary
# (sha256 pinned) is kept in the download cache only.
step_hax() {
  local tag dir tc comps src p feat
  export OPAMROOT=$VU_OWN_OPAMROOT OPAMYES=1 OPAMCOLOR=never
  tag=$(vu_pin .hax.version)
  dir=$VU_CACHE/hax/$tag
  src=$dir/src
  mkdir -p "$dir"
  vu_fetch "$(vu_pin .hax.url)" "$(vu_pin .hax.sha256)" "$VU_CACHE/dl/$tag-x86_64-linux.tar.zst"
  if [ ! -d "$src/.git" ]; then
    rm -rf "$src"
    git clone -q -c advice.detachedHead=false --depth 1 --branch "$tag" "$(vu_pin .hax.repository)" "$src"
  fi
  [ "$(git -C "$src" rev-parse HEAD)" = "$(vu_pin .hax.commit)" ] ||
    vu_die "hax clone is not at the pinned commit"
  echo "hax source: $(git -C "$src" rev-parse HEAD)"
  tc=$(vu_pin .hax.rust)
  grep -q "^channel = \"$tc\"" "$src/rust-toolchain.toml" ||
    vu_die "the tag's rust-toolchain.toml is not $tc"
  comps=$(vu_pin '.hax.rust_components | join(",")')
  # The disk check comes before anything is written: the Rust nightly
  # (1.4 GB) is part of the estimate (review of run C, problem 1).
  if [ ! -x "$dir/bin/hax-driver" ] ||
    [ ! -d "$RUSTUP_HOME/toolchains/$tc-x86_64-unknown-linux-gnu" ] ||
    ! opam switch list --short | grep -qx hax; then
    need_disk hax "$(vu_pin '.hax.disk_gb.hax')"
  fi
  vu_pinned rustup toolchain install "$tc" --profile minimal --component "$comps"
  if [ ! -x "$dir/bin/hax-driver" ]; then
    rm -rf "$dir/bin"
    for p in cli/driver cli/cargo-hax engine/names/extract rust-engine; do
      feat=()
      [ "$p" = cli/cargo-hax ] && feat=(--features legacy-engine)
      (cd "$src" && CARGO_TARGET_DIR=$VU_EXP/build/hax-target vu_pinned \
        cargo "+$tc" install --locked --path "$p" "${feat[@]}" \
        --root "$dir" -j "$(vu_jobs hax)")
    done
    echo "cargo build directory before removal: $(vu_du "$VU_EXP/build/hax-target")"
    rm -rf "$VU_EXP/build/hax-target"
  fi
  if ! opam switch list --short | grep -qx hax; then
    vu_pinned opam switch create hax ocaml-base-compiler.5.4.1 --no-switch \
      -j "$(vu_jobs hax)"
  fi
  if ! opam exec --switch hax -- sh -c 'command -v hax-engine' >/dev/null; then
    (cd "$src" && export PATH="$dir/bin:$PATH" OPAMJOBS="$(vu_jobs hax)" \
      OCAMLRUNPARAM=o=20 OPAMERRLOGLEN=0 OPAMASSUMEDEPEXTS=1 &&
      { ulimit -s hard 2>/dev/null || ulimit -s unlimited 2>/dev/null || true; } &&
      vu_pinned opam install --switch hax --yes ./engine)
  fi
  ln -sfn "$tag" "$VU_CACHE/hax/current"
  ls "$dir/bin"
  opam exec --switch hax -- ocamlc -version
  opam exec --switch hax -- sh -c 'command -v hax-engine' | sed 's#.*/opam/#<opam>/#'
  "$dir/bin/cargo-hax" --version 2>&1 || true
  echo "hax: $(vu_du "$dir") switch hax: $(vu_du "$OPAMROOT/hax")" \
    "rust: $(vu_du "$RUSTUP_HOME/toolchains/$tc-x86_64-unknown-linux-gnu")"
}

# F* for hax's F* backend: the plan tries <cache>/fstar (F* of milestone
# 1) first; smoke-hax records whether hax's F* library checks with it.
# This step installs the F* that cargo-hax pins (flake.nix at the tag),
# beside hax, for the case where it does not.
step_hax_fstar() {
  local v dir
  v=$(vu_pin .hax.fstar)
  dir=$VU_CACHE/hax/fstar-$v
  if [ ! -d "$dir" ]; then
    need_disk hax-fstar "$(vu_pin '.hax.disk_gb["hax-fstar"]')"
  fi
  untar "$(vu_pin .hax.fstar_url)" "$(vu_pin .hax.fstar_sha256)" \
    "fstar-$v-Linux-x86_64.tar.gz" "$dir"
  "$(find_exe "$dir" fstar.exe)" --version
  echo "fstar for hax: $(vu_du "$dir")"
}

# smoke-hax: a one-function crate, extracted with each backend. hax's
# Lean backend is the Charon + Aeneas pipeline (hax's README at the tag:
# "Lean (via Aeneas) ... Uses Charon + Aeneas"): on first use, `cargo
# hax into lean` downloads its own Charon (nightly-2026.10.31, 43 MB)
# and Aeneas build (build-2b9e3ea, 562 MB) into
# XDG_CACHE_HOME/hax/tools (<shared-cache>/xdg under setup-pipeline.sh),
# not into the cache's aeneas/. Both are in pins.json (.hax.lean_tools)
# and in the disk estimate of this step.
smoke_hax() {
  local d xdg
  export OPAMROOT=$VU_OWN_OPAMROOT OPAMYES=1 OPAMCOLOR=never
  xdg=${XDG_CACHE_HOME:-$HOME/.cache}/hax/tools
  if [ ! -d "$xdg/charon/$(vu_pin .hax.lean_tools.charon)" ] ||
    [ ! -d "$xdg/aeneas/$(vu_pin .hax.lean_tools.aeneas)" ]; then
    need_disk smoke-hax "$(vu_pin '.hax.disk_gb["smoke-hax"]')"
  fi
  d=$VU_EXP/build/smoke-hax
  rm -rf "$d"
  mkdir -p "$d/src"
  cat >"$d/Cargo.toml" <<EOF2
[package]
name = "smoke"
version = "0.1.0"
edition = "2021"
[dependencies]
hax-lib = "=$(vu_pin .hax.hax_lib)"
EOF2
  cat >"$d/src/lib.rs" <<'EOF2'
#[hax_lib::requires(x < 100)]
#[hax_lib::ensures(|r| r == x + 1)]
pub fn add1(x: u32) -> u32 { x + 1 }
EOF2
  (cd "$d" && export PATH="$(opam var --switch hax bin):$PATH" &&
    for b in fstar coq lean; do
    vu_pinned cargo "+$(vu_pin .hax.rust)" hax into "$b" || exit 1
  done && find proofs -type f | sort)
  echo "hax Lean tools: charon $(ls "$xdg/charon" | tr '\n' ' ')($(vu_du "$xdg/charon"))" \
    "aeneas $(ls "$xdg/aeneas" | tr '\n' ' ')($(vu_du "$xdg/aeneas"))"
  echo "hax smoke: ok"
}

# Lean backend, Creusot, RefinedRust: only the disk check is written,
# followed by vu_die "install not written". In run C (2026-11-21) none
# of the three steps ran: setup-pipeline.sh refused them on its own
# disk check first. Writing the three installs (and pinning
# RefinedRust's commit in pins.json) is work for the next run.
step_hax_lean() { need_disk hax-lean "$(vu_pin '.hax.disk_gb["hax-lean"]')"; vu_die "hax-lean install not written"; }
step_creusot() { need_disk creusot "$(vu_pin .creusot.disk_gb)"; vu_die "creusot install not written"; }
step_refinedrust() { need_disk refinedrust "$(vu_pin .refinedrust.disk_gb)"; vu_die "refinedrust install not written"; }

# ------------------------------------------------------------ milestone 4

# Run D of the pipeline pinned the three tools in pins.json (commits and
# disk estimates, not measured) but did not write their installs: the
# disk was already under the floor, so none could be tried. As for
# milestone 3's last three steps, each is a disk check then vu_die.
step_bedrock2() { need_disk bedrock2 "$(vu_pin .bedrock2.disk_gb)"; vu_die "bedrock2 install not written"; }
step_cn() { need_disk cn "$(vu_pin .cn.disk_gb)"; vu_die "cn install not written"; }
step_refinedc() { need_disk refinedc "$(vu_pin .refinedc.disk_gb)"; vu_die "refinedc install not written"; }

# ----------------------------------------------------------------- main

step base step_base
# shellcheck disable=SC1091
. "$VU_CACHE/env.sh"
for c in "${components[@]}"; do
  case "$milestone:$c" in
  *:base) ;;
  1:why3) step why3 step_why3 ;;
  1:fstar) step fstar step_fstar ;;
  1:rust) step rust step_rust ;;
  1:verus) step verus step_verus ;;
  1:smoke-why3) step smoke-why3 smoke_why3 ;;
  1:smoke-pulse) step smoke-pulse smoke_pulse ;;
  1:smoke-verus) step smoke-verus smoke_verus ;;
  2:aeneas) step aeneas step_aeneas ;;
  2:aeneas-lean) step aeneas-lean step_aeneas_lean ;;
  2:vst) step vst step_vst ;;
  2:isabelle-llvm) step isabelle-llvm step_isabelle_llvm ;;
  2:llvm) step llvm step_llvm ;;
  2:smoke-aeneas) step smoke-aeneas smoke_aeneas ;;
  2:smoke-vst) step smoke-vst smoke_vst ;;
  2:smoke-isabelle-llvm) step smoke-isabelle-llvm smoke_isabelle_llvm ;;
  3:hax) step hax step_hax ;;
  3:smoke-hax) step smoke-hax smoke_hax ;;
  3:hax-fstar) step hax-fstar step_hax_fstar ;;
  3:hax-lean) step hax-lean step_hax_lean ;;
  3:creusot) step creusot step_creusot ;;
  3:refinedrust) step refinedrust step_refinedrust ;;
  4:bedrock2) step bedrock2 step_bedrock2 ;;
  4:cn) step cn step_cn ;;
  4:refinedc) step refinedc step_refinedc ;;
  *) vu_die "unknown component for milestone $milestone: $c" ;;
  esac
done
# shellcheck disable=SC1091
. "$VU_CACHE/env.sh"
vu_log "disk use: cache=$(vu_du "$VU_CACHE") exp=$(vu_du "$VU_EXP")"
if [ ${#failed[@]} -eq 0 ]; then
  status=0
else
  vu_log "failed components: ${failed[*]}"
fi
exit "$status"
