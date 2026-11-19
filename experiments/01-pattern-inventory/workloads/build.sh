#!/bin/sh
# Rebuild experiment #1 from the pinned sources fetched by fetch.sh:
# upstream builds, extraction, classification, tables, dynamic captures
# and workloads.  Everything heavy goes to $WORKDIR; the repository only
# receives patterns/, tables/ and the sampled workloads.
# Usage: WORKDIR=/path/outside/the/repo [JOBS=4] [SAMPLE=20] sh build.sh
set -eu
: "${WORKDIR:?set WORKDIR to a directory outside the repository}"
JOBS=${JOBS:-4}
SAMPLE=${SAMPLE:-20}
EXP=$(cd "$(dirname "$0")/.." && pwd)
UPSTREAM=$(cd "$EXP/../../upstream" && pwd)
S=$WORKDIR/src B=$WORKDIR/build O=$WORKDIR/out BIN=$WORKDIR/bin P=$WORKDIR/prefix
mkdir -p "$B" "$O" "$BIN"

# 1. Stock upstream f95747b, shared library, installed into $P.
cmake -S "$UPSTREAM" -B "$B/onig" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$P" >/dev/null
make -C "$B/onig" -j"$JOBS" >/dev/null
cmake --install "$B/onig" >/dev/null

# 2. Instrumented copy (static library) with instrument.patch.
rm -rf "$B/onig-instr"; mkdir -p "$B/onig-instr"
git -C "$UPSTREAM" archive --prefix=tree/ HEAD | tar x -C "$B/onig-instr"
(cd "$B/onig-instr/tree" && patch -s -p1 < "$EXP/instrument.patch")
cmake -S "$B/onig-instr/tree" -B "$B/onig-instr/b" -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON >/dev/null
make -C "$B/onig-instr/b" -j"$JOBS" onig >/dev/null

# 3. Classifiers, shim, replayer.
cc -O2 -o "$BIN/classify" "$EXP/classify.c" -I"$B/onig-instr/tree/src" -I"$B/onig-instr/b" "$B/onig-instr/b/libonig.a"
cc -O2 -DSTOCK -o "$BIN/classify-stock" "$EXP/classify.c" -I"$P/include" -L"$P/lib" -Wl,-rpath,"$P/lib" -lonig
cc -shared -fPIC -O2 -o "$BIN/libonigshim.so" "$EXP/workloads/shim.c" -I"$P/include" -ldl
cc -O2 -o "$BIN/replay" "$EXP/workloads/replay.c" -I"$P/include" -L"$P/lib" -Wl,-rpath,"$P/lib" -lonig

# 4. Static extraction, compile/classify, tables (criteria 1-5).
python3 -I "$EXP/scripts/gen_sources.py" "$S" "$EXP/pins.json" > "$EXP/sources.json"
python3 -I "$EXP/scripts/extract_textmate.py" "$S/vscode" > "$O/vscode.occ.jsonl"
python3 -I "$EXP/scripts/extract_jq.py" "$S/jq-1.8.2" > "$O/jq.occ.jsonl"
python3 -I "$EXP/scripts/extract_php.py" "$S/php-8.5.12" "$S/doc-en" > "$O/php.occ.jsonl"
cp "$O/jq.occ.jsonl" "$EXP/patterns/jq.occurrences.jsonl"
cp "$O/php.occ.jsonl" "$EXP/patterns/php.occurrences.jsonl"
python3 -I "$EXP/scripts/inventory.py" "$EXP/patterns" "$BIN/classify" "$BIN/classify-stock" \
  "$O/vscode.occ.jsonl" "$O/jq.occ.jsonl" "$O/php.occ.jsonl" > "$EXP/patterns/inventory-report.json"
python3 -I "$EXP/scripts/tables.py" "$EXP/patterns" "$EXP/tables" > "$EXP/tables/summary.json"

# 5. jq against the stock library, its test suites under the shim.
mkdir -p "$B/jq"
(cd "$B/jq" && PKG_CONFIG_PATH="$P/lib/pkgconfig" "$S/jq-1.8.2/configure" --with-oniguruma="$P" \
   --disable-docs --disable-valgrind >/dev/null && make -j"$JOBS" >/dev/null)
rm -f "$O/jq-shim.tsv"
for t in jq onig optional man manonig; do
  ONIGSHIM_LOG="$O/jq-shim.tsv" LD_PRELOAD="$BIN/libonigshim.so" \
  LD_LIBRARY_PATH="$B/jq/.libs:$P/lib" "$B/jq/.libs/jq" -L "$S/jq-1.8.2/tests" \
    --run-tests "$S/jq-1.8.2/tests/$t.test" >/dev/null 2>&1 || true
done

# 5b. PHP CLI (mbstring only) against the stock library, mbstring tests under
#     the shim.  The shim caps subjects at 4 KiB, 5000 calls per process and
#     200 MB per log: without caps one test writes tens of GB.
mkdir -p "$B/php"
[ -d "$B/php/php-8.5.12" ] || tar xJf "$S/php-8.5.12.tar.xz" -C "$B/php"
(cd "$B/php/php-8.5.12" && PKG_CONFIG_PATH="$P/lib/pkgconfig" ./configure --disable-all \
   --enable-mbstring --disable-cgi --disable-phpdbg --without-pear >/dev/null && make -j"$JOBS" >/dev/null)
rm -f "$O/php-shim.tsv"
(cd "$B/php/php-8.5.12" && ONIGSHIM_MAX_SUBJECT=4096 ONIGSHIM_MAX_LOG=209715200 \
   ONIGSHIM_LOG="$O/php-shim.tsv" LD_PRELOAD="$BIN/libonigshim.so" \
   TEST_PHP_EXECUTABLE="$PWD/sapi/cli/php" timeout 900 sapi/cli/php run-tests.php -j"$JOBS" -q \
   ext/mbstring/tests >/dev/null 2>&1 || true)

# 6. VS Code colorize fixtures through vscode-textmate + vscode-oniguruma.
node "$EXP/workloads/replay_vscode.js" "$S/vscode" "$WORKDIR/node/node_modules" "$O/vscode-log.jsonl"

# 7. Workloads: complete set in $WORKDIR, sample in the repository.
python3 -I "$EXP/workloads/build_workloads.py" "$EXP/patterns" "$O/workloads-full" "$BIN/replay" \
  "$O/vscode-log.jsonl" "$O/jq-shim.tsv" 0 "$O/php-shim.tsv"
python3 -I "$EXP/workloads/build_workloads.py" "$EXP/patterns" "$EXP/workloads/data" "$BIN/replay" \
  "$O/vscode-log.jsonl" "$O/jq-shim.tsv" "$SAMPLE" "$O/php-shim.tsv"

# 8. Dynamic-only triples, classified; tables again to include them.
python3 -I "$EXP/scripts/dynamic_only.py" "$EXP/patterns" "$BIN/classify" "$O/workloads-full"
python3 -I "$EXP/scripts/tables.py" "$EXP/patterns" "$EXP/tables" > "$EXP/tables/summary.json"
