#!/usr/bin/env bash
# run.sh: builds one prototype, links it with the C caller and compares
# the caller's output with caller/expected.txt; or runs its negative
# control.
#
# Usage: run.sh [-n | -r] TOOL [RUN_ID]
#
#   TOOL     a tool directory next to this script (why3, pulse, verus,
#            ...), or "reference" for caller/reference.c.
#   RUN_ID   names the output directory; default: the UTC time. An
#            output directory that already exists is refused.
#   -n       negative control: build with VU_NEGATIVE_CONTROL=1 (the
#            tool's variant without the clamp in vu_char_len); the proof
#            must fail. Nothing is linked. A rejection only counts after
#            a normal run of the same tool with the same RUN_ID passed.
#   -r       second negative control, for the read accessor: build with
#            VU_NEGATIVE_CONTROL=2 (the tool's variant whose
#            vu_get_subject_byte drops the upper bound check, so it may
#            read past subject_len); the proof must fail. Same rules as
#            -n; outputs in TOOL-control-read.
#
# Environment: VU_EXP (required), VU_CACHE (required except for
# "reference"; its env.sh is sourced), VU_CPUS (CPU list for taskset,
# required except for "reference"; checked against reserved and pinned
# CPUs), VU_JOBS (capped as in lib.sh), VU_TIMEOUT (seconds, default
# 1200), VU_VMEM_KB (default 64 GiB; not applied to isabelle-llvm, whose
# JVM reserves large virtual ranges).
#
# Contract of TOOL/build.sh: run from TOOL's directory with VU_HARNESS
# (this directory), VU_OUT (an empty build directory), VU_JOBS,
# VU_NEGATIVE_CONTROL (0, 1 or 2) and VU_PROOF_REJECTED (3) set. It checks
# the proofs and leaves VU_OUT/libvu.a, a static library that defines
# the functions of proto.h; VU_OUT/ldflags may list extra link flags.
# Exit status: 0 when every proof is checked and the library is built;
# VU_PROOF_REJECTED when, and only when, the prover rejects a proof; any
# other non-zero status for any other failure (missing tool, compilation
# error, out of memory...). Its output is logged.
#
# Outputs, in VU_EXP/out/RUN_ID/TOOL (TOOL-control for -n,
# TOOL-control-read for -r): build.log
# (headed by the sha256 of every harness file the run reads),
# build.time (from /usr/bin/time -v when present), caller.out,
# caller.diff and result.txt (key=value lines). Logs are redacted. The
# build directory is VU_EXP/build/RUN_ID/TOOL (or TOOL-control,
# TOOL-control-read).

set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

control=0
case "${1:-}" in
-n) control=1; shift ;;
-r) control=2; shift ;;
esac
[ $# -ge 1 ] && [ $# -le 2 ] || vu_die "usage: run.sh [-n | -r] TOOL [RUN_ID]"
tool=$1
run_id=${2:-$(date -u +%Y%m%dT%H%M%SZ)}
case "$tool" in */* | .* | "") vu_die "bad tool name: $tool" ;; esac
case "$run_id" in */* | .* | "") vu_die "bad run id: $run_id" ;; esac
if [ "$tool" = reference ] && [ "$control" != 0 ]; then
  vu_die "the reference has no proof, hence no negative control"
fi

vu_need_env VU_EXP
if [ "$tool" != reference ]; then
  vu_need_env VU_CACHE VU_CPUS
  [ -f "$VU_CACHE/env.sh" ] || vu_die "no env.sh in <cache>: run setup.sh"
  # shellcheck disable=SC1091
  . "$VU_CACHE/env.sh"
  [ -x "$VU_HARNESS/$tool/build.sh" ] || vu_die "no $tool/build.sh"
fi
if [ -n "${VU_CPUS:-}" ]; then
  vu_check_cpus "$VU_CPUS" || vu_die "VU_CPUS refused (see above)"
fi
timeout_s=${VU_TIMEOUT:-1200}
vmem_kb=${VU_VMEM_KB:-67108864}
vu_uint VU_TIMEOUT "$timeout_s"
vu_uint VU_VMEM_KB "$vmem_kb"
jobs=$(vu_jobs "$tool")

suffix=""
[ "$control" = 1 ] && suffix=-control
[ "$control" = 2 ] && suffix=-control-read
out=$VU_EXP/out/$run_id/$tool$suffix
build=$VU_EXP/build/$run_id/$tool$suffix
[ -e "$out" ] && vu_die "output directory exists, choose another RUN_ID: $out"

# A negative control relies on a passing normal run.
if [ "$control" != 0 ]; then
  normal_result=$VU_EXP/out/$run_id/$tool/result.txt
  if ! { [ -f "$normal_result" ] &&
    grep -qx 'build_status=0' "$normal_result" &&
    grep -qx 'caller_output=same' "$normal_result" &&
    grep -qx 'caller_status=0' "$normal_result"; }; then
    vu_die "no passing normal run of $tool with RUN_ID $run_id: run it first"
  fi
fi

rm -rf "$build"
mkdir -p "$out" "$build"
result=$out/result.txt
: >"$result"
record() { printf '%s=%s\n' "$1" "$2" >>"$result"; }
record tool "$tool"
record run_id "$run_id"
case "$control" in
1) record mode negative-control ;;
2) record mode negative-control-read ;;
*) record mode normal ;;
esac
record jobs "$jobs"
record cpus "${VU_CPUS:-unpinned}"
[ "$control" != 0 ] && record normal_run passed

# The build, under timeout and (except Isabelle) a virtual memory limit.
build_cmd() {
  if [ "$tool" = reference ]; then
    cc -std=c11 -O2 -Wall -Wextra -Werror -I"$VU_HARNESS" \
      -c "$VU_HARNESS/caller/reference.c" -o "$build/reference.o" &&
      ar rcs "$build/libvu.a" "$build/reference.o"
  else
    cd "$VU_HARNESS/$tool" &&
      VU_OUT=$build VU_JOBS=$jobs VU_NEGATIVE_CONTROL=$control ./build.sh
  fi
}
export -f build_cmd
export tool build control jobs VU_HARNESS

# The sha256 of every harness file the run reads (the shared scripts,
# proto.h, the caller and the tool's directory), at the head of
# build.log, so that the log ties the run to committed files.
sources() {
  local dirs=(caller)
  [ "$tool" != reference ] && dirs+=("$tool")
  (cd "$VU_HARNESS" &&
    { printf '%s\0' run.sh lib.sh proto.h && find "${dirs[@]}" -type f -print0; } |
    LC_ALL=C sort -z | xargs -0 sha256sum)
}
{
  echo "== harness sources (sha256)"
  sources
  echo "== build"
} >"$build/build.raw"

limit=""
[ "$tool" != isabelle-llvm ] && limit="ulimit -v $vmem_kb;"
timer=()
[ -x /usr/bin/time ] && timer=(/usr/bin/time -v -o "$build/time.raw")
start=$(date +%s)
set +e
vu_pinned "${timer[@]}" timeout "$timeout_s" \
  bash -c "$limit build_cmd" >>"$build/build.raw" 2>&1
status=$?
set -e
record build_seconds "$(($(date +%s) - start))"
record build_status "$status"
vu_redact <"$build/build.raw" >"$out/build.log"
[ -f "$build/time.raw" ] && vu_redact <"$build/time.raw" >"$out/build.time"

if [ "$control" != 0 ]; then
  case "$status" in
  "$VU_PROOF_REJECTED")
    record control rejected
    vu_log "$tool control: proof rejected, as required"
    exit 0
    ;;
  0)
    record control ACCEPTED
    vu_log "$tool control: FAILED, the proof passed with the broken variant"
    ;;
  124)
    record control timeout
    vu_log "$tool control: timeout after ${timeout_s}s"
    ;;
  *)
    record control error
    vu_log "$tool control: the build failed for another reason than a rejected proof (status $status), see build.log"
    ;;
  esac
  exit 1
fi

if [ "$status" != 0 ]; then
  record verdict build-failed
  vu_log "$tool: build or proof failed (status $status), see build.log"
  exit 1
fi
[ -f "$build/libvu.a" ] || vu_die "$tool/build.sh left no libvu.a"

ldflags=()
if [ -f "$build/ldflags" ]; then
  read -r -a ldflags <"$build/ldflags" || true
fi
if ! cc -std=c11 -Wall -Wextra -Werror -I"$VU_HARNESS" \
  "$VU_HARNESS/caller/caller.c" "$build/libvu.a" "${ldflags[@]}" \
  -o "$build/caller" >"$build/link.raw" 2>&1; then
  vu_redact <"$build/link.raw" >"$out/link.log"
  record verdict link-failed
  vu_log "$tool: link failed, see link.log"
  exit 1
fi
record link ok

set +e
timeout 60 "$build/caller" >"$out/caller.out" 2>&1
run_status=$?
set -e
record caller_status "$run_status"
if diff -u --label expected.txt --label caller.out \
  "$VU_HARNESS/caller/expected.txt" "$out/caller.out" \
  >"$out/caller.diff"; then
  record caller_output same
  vu_log "$tool: caller output equals expected.txt"
else
  record caller_output DIFFERENT
  vu_log "$tool: caller output differs from expected.txt, see caller.diff"
  exit 1
fi
[ "$run_status" = 0 ] || exit 1
