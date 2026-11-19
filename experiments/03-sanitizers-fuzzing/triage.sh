#!/bin/sh
# Replay every artifact with its read-* binary (stdin) or, for
# libfuzzer-onig*, the fuzz binary itself; keep the symbolised report and
# a dedup key (top 3 frames in upstream/src or the harness).
set -u
. "$(dirname "$0")/env.sh"
O=$LOGS/triage; mkdir -p "$O"
printf 'target\tartifact\texit\tkind\tkey\n' > "$O/index.tsv"
for A in "$HOSTDIR"/artifacts/*/*; do
  [ -f "$A" ] || continue
  t=$(basename "$(dirname "$A")"); a=$(basename "$A")
  case $t in
    libfuzzer-onig*) cmd="$H/$t -timeout=60 $A";;
    fuzzer-*) cmd="$H/read-${t#fuzzer-}";;
  esac
  R=$O/$t.$a.txt
  case $t in
    libfuzzer-onig*) ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=print_stacktrace=1 timeout 120 taskset -c "$CPUS" $cmd > "$R" 2>&1; ex=$?;;
    *) ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=print_stacktrace=1 timeout 120 taskset -c "$CPUS" $cmd < "$A" > "$R" 2>&1; ex=$?;;
  esac
  kind=$(grep -aoE 'ERROR: (AddressSanitizer|LeakSanitizer): [a-z-]+|runtime error: [a-z -]+|stack-overflow|ERROR: [A-Z_ ]+' "$R" | head -1)
  [ -z "$kind" ] && [ "$ex" = 124 ] && kind=timeout
  [ -z "$kind" ] && kind="exit-$ex $(grep -a '^ERROR:' "$R" | head -1)"
  key=$(grep -aE '^ +#[0-9]+ ' "$R" | grep -avE 'libclang_rt|compiler-rt|sanitizer_common|asan_|ubsan_|libc\.so|__libc_start|_start' | head -3 | sed -E 's/.* in ([^ ]+) .*\/([^/ ]+:[0-9]+).*/\1@\2/' | tr '\n' ' ')
  printf '%s\t%s\t%s\t%s\t%s\n' "$t" "$a" "$ex" "$kind" "$key" >> "$O/index.tsv"
done
cut -f1,4,5 "$O/index.tsv" | tail -n +2 | sort | uniq -c | sort -rn
