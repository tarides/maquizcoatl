#!/bin/sh
# Final statistics: one -runs=0 pass per corpus for cov/ft, fork-parent
# figures, corpus size, corpus tarball hash. Output: TSV on stdout.
set -u
. "$(dirname "$0")/env.sh"
mkdir -p "$LOGS/stats" "$HOSTDIR/corpus-tar"
printf 'target\tworkers\tcov_runs0\tft_runs0\tfork_last\texecs\tfiles\tbytes\ttar_sha256\ttar_bytes\tcrash\ttimeout\toom\tleak\n'
tail -n +2 "$EXP/split.tsv" | while IFS="$(printf '\t')" read -r t w d m; do
  ML=""; [ "$m" != 0 ] && ML="-max_len=$m"
  ASAN_OPTIONS=detect_leaks=0 taskset -c "$CPUS" "$H/$t" -runs=0 $ML "$HOSTDIR/corpus/$t" > "$LOGS/stats/$t.runs0" 2>&1
  l=$(grep -aE '#[0-9]+[[:space:]]+(INITED|DONE)' "$LOGS/stats/$t.runs0" | tail -1)
  cov=$(echo "$l" | sed -n 's/.*cov: \([0-9]*\).*/\1/p'); ft=$(echo "$l" | sed -n 's/.*ft: \([0-9]*\).*/\1/p')
  fl=$(grep -aE '^#[0-9]+: cov:' "$LOGS/fuzz/$t.log" | tail -1 | tr -s ' ' | cut -c1-120)
  ex=$(echo "$fl" | sed -n 's/^#\([0-9]*\):.*/\1/p')
  nf=$(find "$HOSTDIR/corpus/$t" -type f | wc -l); nb=$(du -sb --apparent-size "$HOSTDIR/corpus/$t" | cut -f1)
  tar -C "$HOSTDIR/corpus" -cJf "$HOSTDIR/corpus-tar/$t.tar.xz" "$t"
  sh=$(sha256sum "$HOSTDIR/corpus-tar/$t.tar.xz" | cut -c1-64); sz=$(stat -c %s "$HOSTDIR/corpus-tar/$t.tar.xz")
  A=$HOSTDIR/artifacts/$t
  c=$(ls "$A" | grep -c '^crash-'); to=$(ls "$A" | grep -c '^timeout-'); oo=$(ls "$A" | grep -c '^oom-'); lk=$(ls "$A" | grep -c '^leak-')
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$t" "$w" "$cov" "$ft" "$fl" "$ex" "$nf" "$nb" "$sh" "$sz" "$c" "$to" "$oo" "$lk"
done
