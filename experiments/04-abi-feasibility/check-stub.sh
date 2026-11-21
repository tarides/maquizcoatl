#!/bin/bash
# check-stub.sh PREFIX default|posix OUT
# Criteria 1-3 for a stub installed under PREFIX (lib/, include/),
# against the matching oracle under OUT/oracle and the harness under
# OUT/harness. Prints a TSV report: criterion, item, result, detail.
set -u
P=$(cd "$1" && pwd); V=$2; OUT=$(cd "$3" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd); H=$OUT/harness
TMP=$(mktemp -d "$OUT/tmp.XXXXXX"); trap 'rm -rf "$TMP"' EXIT
CC=${CC:-gcc}
out() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }
cls() { awk -F'\t' -v n="$1" '$1==n{print $3; f=1} END{if(!f)print "-"}' "$HERE/symbols.tsv"; }

# --- criterion 1: symbols, SONAME, file names
lib=$P/lib/libonig.so.5
if [ -e "$lib" ]; then
  nm -D --defined-only "$lib" | awk '{t=($2 ~ /^[Tt]$/)?"F":"D"; print $3, t}' | sort >"$TMP/stub.nm"
else : >"$TMP/stub.nm"; fi
awk '{t=($2 ~ /^[Tt]$/)?"F":"D"; print $1, t}' "$OUT/oracle/$V.nm" | sort >"$TMP/ora.nm"
nmiss=0; nextra=0; nkind=0; pubmiss=0
for s in $(join -v1 "$TMP/ora.nm" "$TMP/stub.nm" | awk '{print $1}'); do
  c=$(cls "$s"); out 1 "missing:$s" fail "$c"; nmiss=$((nmiss+1))
  [ "$c" = public ] && pubmiss=$((pubmiss+1))
done
for s in $(join -v2 "$TMP/ora.nm" "$TMP/stub.nm" | awk '{print $1}'); do
  out 1 "extra:$s" info "-"; nextra=$((nextra+1)); done
while read -r s a b; do
  out 1 "kind:$s" fail "oracle $a stub $b"; nkind=$((nkind+1))
done < <(join "$TMP/ora.nm" "$TMP/stub.nm" | awk '$2!=$3{print $1, $2, $3}')
# data symbol sizes matter for copy relocations in client executables
nsize=0
if [ -e "$lib" ]; then
  sz() { nm -D -S --defined-only "$1" | awk 'NF==4 && $3 !~ /^[Tt]$/{print $4, $2}' | sort; }
  while read -r s a b; do
    out 1 "size:$s" fail "oracle 0x$a stub 0x$b"; nsize=$((nsize+1))
  done < <(join <(sz "$OUT/oracle/$V/lib/libonig.so.5") <(sz "$lib") | awk '$2!=$3')
fi
r=fail; [ $nmiss -eq 0 ] && [ $nkind -eq 0 ] && [ $nsize -eq 0 ] && r=pass
out 1 symbols $r "oracle=$(wc -l <"$TMP/ora.nm") stub=$(wc -l <"$TMP/stub.nm") missing=$nmiss (public $pubmiss) extra=$nextra kind_mismatch=$nkind data_size_mismatch=$nsize"
so=""; [ -e "$lib" ] && so=$(readelf -d "$lib" | sed -n 's/.*Library soname: \[\(.*\)\]/\1/p')
r=fail; [ "$so" = libonig.so.5 ] && r=pass
out 1 soname $r "${so:-none}"
names=pass
{ [ -f "$P/lib/libonig.so.5.5.0" ] && [ ! -L "$P/lib/libonig.so.5.5.0" ]; } || names=fail
[ "$(readlink "$P/lib/libonig.so.5" 2>/dev/null)" = libonig.so.5.5.0 ] || names=fail
[ "$(readlink "$P/lib/libonig.so" 2>/dev/null)" = libonig.so.5 ] || names=fail
out 1 file-names $names "libonig.so.5.5.0 <- libonig.so.5 <- libonig.so"

# --- criterion 2: layout against the stub's shipped headers
lay() {
  if $CC -std=gnu11 -I"$P/include" -o "$TMP/$1" "$HERE/$1.c" 2>"$TMP/$1.err"; then
    "$TMP/$1" >"$TMP/$1.txt"
    for st in $(awk '{print $1}' "$H/ref/$1.txt" | uniq); do
      if diff <(grep "^$st " "$H/ref/$1.txt") <(grep "^$st " "$TMP/$1.txt") >/dev/null 2>&1
      then out 2 "$st" pass "-"; else out 2 "$st" fail "differs"; fi
    done
  else out 2 "$1" fail "does not compile against shipped header"; fi
}
lay layout; [ "$V" = posix ] && lay layout_posix

# --- criterion 3: load and link of each harness binary
bins="test_utf8 test_back testc testcu test_syntax test_options test_regset
 bug_fix callback_each_match callout count echo encode listcap names regset scan
 simple sql syntax user_property client_encoding"
[ "$V" = posix ] && bins="$bins testp posix"
for n in $bins; do
  b=$H/bin/$n
  res=$(cd "$TMP" && LD_LIBRARY_PATH="$P/lib" ldd "$b" | awk '$1=="libonig.so.5"{print $3}')
  rp=$(readlink -f "$res" 2>/dev/null || true)
  case $rp in "$P"/*) ;; *) out 3 "$n" fail "libonig.so.5 resolved to '${res:-not found}', not under prefix"; continue;; esac
  undef=$(cd "$TMP" && LD_LIBRARY_PATH="$P/lib" ldd -r "$b" 2>&1 | grep -c 'undefined symbol')
  (cd "$TMP" && LD_LIBRARY_PATH="$P/lib" LD_BIND_NOW=1 timeout 60 "$b" </dev/null >"$TMP/run.out" 2>&1)
  st=$?
  sle=$(grep -c 'symbol lookup error' "$TMP/run.out")
  r=fail
  if [ "$undef" -eq 0 ] && ! { [ $st -eq 127 ] && [ "$sle" -gt 0 ]; }; then r=pass; fi
  out 3 "$n" $r "undefined=$undef exit=$st"
done
