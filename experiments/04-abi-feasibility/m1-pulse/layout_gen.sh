#!/bin/bash
# layout_gen.sh OUT: layout of the structs as each emitter generated them
# (onig_encoding_type, onig_syntax_type, onig_meta_char_table_type in
# Custard.h), printed in layout.c's format under upstream's type names
# and diffed against the reference compiled from upstream's headers.
set -u
OUT=$(cd "$1" && pwd)
FS=$(dirname "$(dirname "$(command -v fstar.exe)")")
W=$OUT/stubs/m1-fstar/default; R=$OUT/harness/ref/layout.txt
gen() { # dir
cat <<'EOF'
#include <stdio.h>
#include <stddef.h>
#include "Custard.h"
#define S(N,T)   printf("%s - %zu %zu %zu\n", N, (size_t)0, sizeof(T), _Alignof(T))
#define F(N,T,f) printf("%s %s %zu %zu %zu\n", N, #f, offsetof(T,f), \
                        sizeof(((T*)0)->f), _Alignof(__typeof__(((T*)0)->f)))
int main(void) {
  S("OnigMetaCharTableType", onig_meta_char_table_type);
EOF
for f in esc anychar anytime zero_or_one_time one_or_more_time anychar_anytime; do
  echo "  F(\"OnigMetaCharTableType\", onig_meta_char_table_type, $f);"; done
echo '  S("OnigEncodingType", onig_encoding_type);'
for f in mbc_enc_len name max_enc_len min_enc_len is_mbc_newline mbc_to_code code_to_mbclen \
  code_to_mbc mbc_case_fold apply_all_case_fold get_case_fold_codes_by_str property_name_to_ctype \
  is_code_ctype get_ctype_code_range left_adjust_char_head is_allowed_reverse_match init \
  is_initialized is_valid_mbc_string flag sb_range index; do
  echo "  F(\"OnigEncodingType\", onig_encoding_type, $f);"; done
echo '  S("OnigSyntaxType", onig_syntax_type);'
for f in op op2 behavior options meta_char_table; do
  echo "  F(\"OnigSyntaxType\", onig_syntax_type, $f);"; done
echo '  return 0;'; echo '}'
}
for e in kc dc; do
  gen >"$W/layout_gen_$e.c"
  if gcc -std=gnu11 -I"$W/$e" -I"$FS/include/krml" -I"$FS/lib/krml/dist/minimal" \
       -o "$W/layout_gen_$e" "$W/layout_gen_$e.c" 2>"$W/layout_gen_$e.err"; then
    "$W/layout_gen_$e" >"$W/layout_gen_$e.txt"
    for st in OnigMetaCharTableType OnigEncodingType OnigSyntaxType; do
      if diff <(grep "^$st " "$R") <(grep "^$st " "$W/layout_gen_$e.txt") >/dev/null
      then echo "$e	$st	same"; else echo "$e	$st	differs"; fi
    done
  else echo "$e	-	does not compile"; fi
done
