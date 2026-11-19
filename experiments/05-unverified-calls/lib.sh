# shellcheck shell=bash
# lib.sh: helpers shared by setup.sh, run.sh and provenance.sh.
# Sourced, not run. Nothing here prints an absolute path, a hostname or
# a user name: every message and every log goes through vu_redact.

VU_HARNESS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# CPUs reserved for experiment #11's timing runs, never used here.
VU_RESERVED_CPUS="4-7,36-39"

# Exit status of a TOOL/build.sh whose prover rejected a proof (see the
# contract in run.sh). Any other non-zero status is another failure.
export VU_PROOF_REJECTED=3

vu_die() {
  printf 'error: %s\n' "$*" | vu_redact >&2
  exit 1
}

vu_log() {
  printf '%s\n' "$*" | vu_redact
}

# vu_need_env VAR...: every VAR is set and non-empty.
vu_need_env() {
  local v
  for v in "$@"; do
    [ -n "${!v:-}" ] || vu_die "$v is not set"
  done
}

# vu_redact: stdin to stdout, with the experiment and cache directories,
# the home directory, any other home directory, the host name and the
# user name replaced by placeholders. Longest paths first.
vu_redact() {
  local args=() host
  args+=(-e "s#${VU_HARNESS//#/\\#}#<harness>#g")
  [ -n "${VU_EXP:-}" ] && args+=(-e "s#${VU_EXP//#/\\#}#<exp>#g")
  [ -n "${VU_CACHE:-}" ] && args+=(-e "s#${VU_CACHE//#/\\#}#<cache>#g")
  [ -n "${VU_SHARED_CACHE:-}" ] &&
    args+=(-e "s#${VU_SHARED_CACHE//#/\\#}#<shared-cache>#g")
  [ -n "${HOME:-}" ] && args+=(-e "s#${HOME//#/\\#}#<home>#g")
  args+=(-e 's#/home/[A-Za-z0-9._-]*#<home>#g')
  args+=(-e 's#/Users/[A-Za-z0-9._-]*#<home>#g')
  host=$(uname -n 2>/dev/null || true)
  [ -n "$host" ] && args+=(-e "s#\\b${host//./\\.}\\b#<host>#g")
  [ -n "${USER:-}" ] && args+=(-e "s#\\b${USER}\\b#<user>#g")
  sed "${args[@]}"
}

# vu_expand_cpus LIST: "0-3,8" -> "0 1 2 3 8".
vu_expand_cpus() {
  printf '%s\n' "$1" | tr ',' '\n' | awk -F- '
    NF == 1 && $1 != "" { print $1 }
    NF == 2 { for (i = $1; i <= $2; i++) print i }' | sort -n | uniq |
    tr '\n' ' '
}

# vu_valid_cpus LIST: LIST is a taskset CPU list ("0-3,8", ranges in
# increasing order) whose CPUs are all online.
vu_valid_cpus() {
  local online c
  printf '%s\n' "$1" | grep -Eqx '[0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*' ||
    return 1
  printf '%s\n' "$1" | tr ',' '\n' |
    awk -F- 'NF == 2 && $1 + 0 > $2 + 0 { bad = 1 } END { exit bad }' ||
    return 1
  online=" $(vu_expand_cpus "$(cat /sys/devices/system/cpu/online)")"
  for c in $(vu_expand_cpus "$1"); do
    case "$online" in *" $c "*) ;; *) return 1 ;; esac
  done
}

# vu_pinned_cpus: the CPUs pinned by user processes other than this
# script's ancestors and descendants (which inherit or set its own
# affinity), one line. A process is pinned when its affinity is not the
# whole online set. Kernel threads (Kthread: 1, kthreadd and its
# children) are pinned per CPU by design and are ignored.
vu_pinned_cpus() {
  local online f
  online=$(cat /sys/devices/system/cpu/online)
  for f in /proc/[0-9]*/status; do
    cat "$f" 2>/dev/null && echo "End:"
  done | awk -v online="$online" -v self="$$" '
    /^Pid:/ { pid = $2 }
    /^PPid:/ { pp = $2 }
    /^Kthread:/ { k = $2 }
    /^Cpus_allowed_list:/ { c = $2 }
    /^End:/ {
      if (pid != "") { parent[pid] = pp; cpus[pid] = c; kern[pid] = (k == 1) }
      pid = ""; pp = ""; k = ""; c = ""
    }
    END {
      # Descendants of self (self included), until no process is added.
      desc[self] = 1
      do {
        added = 0
        for (p in parent)
          if (!(p in desc) && (parent[p] in desc)) { desc[p] = 1; added = 1 }
      } while (added)
      # Ancestors of self.
      for (p = parent[self]; p != "" && p != 0 && !(p in anc); p = parent[p])
        anc[p] = 1
      for (p in cpus)
        if (!(p in desc) && !(p in anc) && !kern[p] && p != 2 &&
            parent[p] != 2 && cpus[p] != "" && cpus[p] != online)
          print cpus[p]
    }' | sort -u | while read -r l; do vu_expand_cpus "$l"; done |
    tr ' ' '\n' | sort -nu | tr '\n' ' '
}

# vu_check_cpus LIST: LIST is a valid list of online CPUs and avoids the
# reserved CPUs and every CPU of vu_pinned_cpus. Prints the conflicts
# and fails if there are any.
vu_check_cpus() {
  local want reserved pinned c bad=""
  if ! vu_valid_cpus "$1"; then
    vu_log "bad CPU list (syntax, order or offline CPU): $1"
    return 1
  fi
  want=" $(vu_expand_cpus "$1")"
  reserved=" $(vu_expand_cpus "$VU_RESERVED_CPUS")"
  pinned=" $(vu_pinned_cpus)"
  for c in $want; do
    case "$reserved" in *" $c "*) bad="$bad $c(reserved)";; esac
    case "$pinned" in *" $c "*) bad="$bad $c(pinned)";; esac
  done
  if [ -n "$bad" ]; then
    vu_log "CPU conflicts:$bad"
    return 1
  fi
}

# vu_jobs COMPONENT: the job count for COMPONENT, VU_JOBS capped at 12
# for the slow installs (VST, Isabelle-LLVM, RefinedRust) and at 4
# otherwise.
vu_jobs() {
  local cap=4 j=${VU_JOBS:-4}
  case "$j" in "" | *[!0-9]*) vu_die "VU_JOBS must be a positive integer: $j" ;; esac
  j=$((10#$j))
  case "$1" in vst | isabelle-llvm | refinedrust) cap=12 ;; esac
  [ "$j" -gt "$cap" ] && j=$cap
  [ "$j" -lt 1 ] && j=1
  printf '%s\n' "$j"
}

# vu_pinned CMD...: runs CMD under nice, pinned to VU_CPUS when it is set
# (after vu_check_cpus).
vu_pinned() {
  if [ -n "${VU_CPUS:-}" ]; then
    nice -n 10 taskset -c "$VU_CPUS" "$@"
  else
    nice -n 10 "$@"
  fi
}

# vu_sha256 FILE: the sha256 of FILE.
vu_sha256() {
  sha256sum "$1" | cut -d' ' -f1
}

# vu_pin KEY: a value of pins.json (jq path, e.g. .verus.version).
vu_pin() {
  jq -er "$1" "$VU_HARNESS/pins.json"
}

# vu_fetch URL SHA256 DEST: downloads URL to DEST unless DEST already has
# the expected sha256. An empty SHA256 means "not pinned in pins.json":
# the hash of the first download is written to DEST.sha256, every later
# use is checked against it, and the log line "UNPINNED ... sha256=..."
# is the value to copy into pins.json and the notebook.
vu_fetch() {
  local url=$1 sum=$2 dest=$3 got pinned=1
  if [ -z "$sum" ]; then
    pinned=0
    [ -f "$dest.sha256" ] && sum=$(cat "$dest.sha256")
  fi
  if [ -f "$dest" ] && [ -n "$sum" ]; then
    got=$(vu_sha256 "$dest")
    [ "$got" = "$sum" ] && return 0
    [ "$pinned" = 1 ] || vu_die "$(basename "$dest") no longer matches its recorded sha256"
  fi
  curl -fsSL --retry 3 -o "$dest.part" "$url" || vu_die "download failed: $url"
  got=$(vu_sha256 "$dest.part")
  if [ -n "$sum" ] && [ "$got" != "$sum" ]; then
    rm -f "$dest.part"
    vu_die "sha256 mismatch for $url: expected $sum, got $got"
  fi
  mv "$dest.part" "$dest"
  if [ "$pinned" = 0 ]; then
    printf '%s\n' "$got" >"$dest.sha256"
    vu_log "UNPINNED $(basename "$dest") sha256=$got (recorded on first fetch)"
  else
    vu_log "fetched $(basename "$dest") sha256=$got"
  fi
}

# vu_uint NAME VALUE: VALUE is a non-empty string of digits, else dies.
vu_uint() {
  case "$2" in "" | *[!0-9]*) vu_die "$1 must be a non-negative integer: $2" ;; esac
}

# vu_du DIR: disk use of DIR, human-readable.
vu_du() {
  if [ -e "$1" ]; then du -sh "$1" 2>/dev/null | cut -f1; else echo 0; fi
}
