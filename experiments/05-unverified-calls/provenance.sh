#!/usr/bin/env bash
# provenance.sh: records the provenance of one run.
#
# Usage: provenance.sh RUN_ID start|end
#
# Appends "key: value" lines to VU_EXP/out/RUN_ID/provenance.txt and
# prints them. "start" records the machine, the commits and the tool
# versions; "end" records the end load and the duration. Environment:
# VU_EXP (required), VU_CACHE (its env.sh is sourced when present),
# VU_JOBS, VU_CPUS, VU_CFLAGS (compiler flags, recorded as given).
# Nothing recorded names the host, a user or an absolute path: the
# output goes through vu_redact.

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ $# -eq 2 ] || vu_die "usage: provenance.sh RUN_ID start|end"
case "$2" in start | end) ;; *) vu_die "phase must be start or end" ;; esac
run_id=$1
phase=$2
case "$run_id" in */* | .* | "") vu_die "bad run id: $run_id" ;; esac
vu_need_env VU_EXP
if [ -n "${VU_CACHE:-}" ] && [ -f "$VU_CACHE/env.sh" ]; then
  # shellcheck disable=SC1091
  . "$VU_CACHE/env.sh"
fi
dir=$VU_EXP/out/$run_id
mkdir -p "$dir"
file=$dir/provenance.txt

# first_line CMD...: the first non-empty output line of CMD, or "absent".
first_line() {
  local o
  if command -v "$1" >/dev/null 2>&1; then
    o=$("$@" 2>&1 | awk 'NF { print; exit }') || true
    printf '%s\n' "${o:-unknown}"
  else
    echo absent
  fi
}

# repo_state: the repository commit, with "-dirty" when tracked files
# differ from it.
repo_state() {
  local c
  c=$(git -C "$VU_HARNESS" rev-parse HEAD 2>/dev/null) || { echo unknown; return; }
  if [ -n "$(git -C "$VU_HARNESS" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    c=$c-dirty
  fi
  printf '%s\n' "$c"
}

# upstream_state: the commit the repository records for upstream/ (its
# gitlink), then the commit checked out there, "not-initialised" when
# upstream/ is not a checked-out submodule, and whether both equal the
# commit of pins.json.
upstream_state() {
  local top dir want link co
  top=$(git -C "$VU_HARNESS" rev-parse --show-toplevel 2>/dev/null) || { echo unknown; return; }
  dir=$top/upstream
  want=$(vu_pin .oniguruma)
  link=$(git -C "$top" rev-parse HEAD:upstream 2>/dev/null || echo unknown)
  co=not-initialised
  if [ "$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" = "$dir" ]; then
    co=$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo unknown)
  fi
  if [ "$link" = "$want" ] && [ "$co" = "$want" ]; then
    printf 'gitlink=%s checkout=%s pinned=yes\n' "$link" "$co"
  else
    printf 'gitlink=%s checkout=%s pinned=NO (expected %s)\n' "$link" "$co" "$want"
  fi
}

emit() {
  printf '%s: %s\n' "$1" "$2"
}

{
  emit phase "$phase"
  emit time_utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  emit load_avg "$(cut -d' ' -f1-3 /proc/loadavg)"
  case "$phase" in
  start)
    date +%s >"$dir/.start-epoch"
    emit cpu_model "$(awk -F': ' '/^model name/ { print $2; exit }' /proc/cpuinfo)"
    emit cpus_online "$(cat /sys/devices/system/cpu/online)"
    emit kernel "$(uname -sr)"
    emit os "$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}")"
    emit jobs "${VU_JOBS:-4}"
    emit cpu_set "${VU_CPUS:-unpinned}"
    emit cflags "${VU_CFLAGS:-default}"
    emit repo_commit "$(repo_state)"
    emit upstream_commit "$(upstream_state)"
    emit pins_sha256 "$(vu_sha256 "$VU_HARNESS/pins.json")"
    emit gcc "$(first_line gcc --version)"
    emit cmake "$(first_line cmake --version)"
    # The opam that setup.sh uses (VST and later switches), not the host's.
    emit opam "$(first_line "${VU_CACHE:-}/bin/opam" --version)"
    emit why3 "$(first_line why3 --version)"
    emit alt-ergo "$(first_line alt-ergo --version)"
    emit z3_for_why3 "$(first_line "${VU_WHY3_Z3:-z3}" --version)"
    emit fstar "$(first_line fstar.exe --version)"
    emit krml "$(first_line krml -version)"
    emit verus "$(verus --version 2>/dev/null | awk '/Version:/ { print $2; f = 1 } END { if (!f) print "absent" }')"
    emit rustup "$(first_line rustup --version)"
    if command -v rustup >/dev/null 2>&1; then
      emit rust_toolchains "$(rustup toolchain list 2>/dev/null | tr '\n' ' ')"
    fi
    emit charon "$(first_line charon version)"
    emit aeneas "$(first_line aeneas -version)"
    emit lean "$(first_line lean --version)"
    emit isabelle "$(first_line isabelle version)"
    emit clang "$(first_line clang --version)"
    emit coqc_vst "$(first_line env OPAMROOT="${VU_OWN_OPAMROOT:-}" "${VU_CACHE:-}/bin/opam" exec --switch vst -- coqc --version)"
    emit clightgen_vst "$(first_line env OPAMROOT="${VU_OWN_OPAMROOT:-}" "${VU_CACHE:-}/bin/opam" exec --switch vst -- clightgen -version)"
    for root in ${OPAMROOT:-} ${VU_OWN_OPAMROOT:-}; do
      [ -d "$root" ] || continue
      emit "opam_switches($root)" \
        "$(OPAMROOT=$root opam switch list --short --readonly 2>/dev/null | tr '\n' ' ')"
    done
    ;;
  end)
    if [ -f "$dir/.start-epoch" ]; then
      emit duration_s "$(($(date +%s) - $(cat "$dir/.start-epoch")))"
    fi
    ;;
  esac
} | vu_redact | tee -a "$file"
