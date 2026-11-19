#!/bin/sh
# Review follow-ups of experiment #1, added after #11 started (build.sh and
# the files it writes are left unchanged).  Run after fetch.sh and build.sh,
# with the same WORKDIR:
#   - long-subject PHP calls (shim_long.c, long_subjects.py), for #12;
#   - repetition counts of the VS Code searches (freq_vscode.js,
#     freq_profile.py), for #11.
# Usage: WORKDIR=/path/outside/the/repo sh build_followups.sh
set -eu
: "${WORKDIR:?set WORKDIR to a directory outside the repository}"
EXP=$(cd "$(dirname "$0")/.." && pwd)
S=$WORKDIR/src B=$WORKDIR/build O=$WORKDIR/out BIN=$WORKDIR/bin P=$WORKDIR/prefix

# 1. PHP mbstring tests under the long-subject shim: first 5 calls per test
#    process with a subject over 4 KiB, subjects up to 4 MiB, 16 MB per log.
cc -shared -fPIC -O2 -o "$BIN/libonigshim_long.so" "$EXP/workloads/shim_long.c" -I"$P/include" -ldl
rm -rf "$O/php-long"; mkdir -p "$O/php-long"
(cd "$B/php/php-8.5.12" && ONIGSHIM_DIR="$O/php-long" ONIGSHIM_MIN_SUBJECT=4096 \
   ONIGSHIM_PER_PROCESS=5 ONIGSHIM_MAX_SUBJECT=4194304 ONIGSHIM_MAX_LOG=16777216 \
   LD_PRELOAD="$BIN/libonigshim_long.so" TEST_PHP_EXECUTABLE="$PWD/sapi/cli/php" \
   timeout 900 sapi/cli/php run-tests.php -j4 -q ext/mbstring/tests >/dev/null 2>&1 || true)
python3 -I "$EXP/workloads/long_subjects.py" "$O/php-long" "$EXP/workloads/data" 100 1048576

# 2. VS Code fixtures again, counting repeated searches.
node "$EXP/workloads/freq_vscode.js" "$S/vscode" "$WORKDIR/node/node_modules" "$O/vscode-freq.jsonl"
python3 -I "$EXP/workloads/freq_profile.py" "$O/vscode-freq.jsonl" "$EXP/workloads/data" "$O/workloads-full"
