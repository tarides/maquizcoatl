#!/bin/bash
# probe.sh OUT CACHE [JOBS]
# Mechanism 4 construct probe: one small theory per ABI construct the
# Oniguruma ABI needs, each built independently so that every one
# reports its own result. Expected to fail are the constructs that
# Isabelle-LLVM's export_llvm grammar or its LLVM model does not have.
# Results: OUT/stubs/m4-probe/results.tsv (construct, built yes/no,
# first error line).
set -u
OUT=$(cd "$1" && pwd); CACHE=$(cd "$2" && pwd); JOBS=${3:-4}
ISA=$CACHE/isabelle/bin/isabelle
AFP=$CACHE/isabelle/afp-2026-11-19/afp-2026-11-19
ILLVM=$CACHE/isabelle/isabelle_llvm
D=$OUT/stubs/m4-probe; rm -rf "$D"; mkdir -p "$D"
thy() { # NAME BODY
  mkdir -p "$D/$1"
  printf 'session %s = Isabelle_LLVM +\n  theories %s\n' "Probe_$1" "$1" >"$D/$1/ROOT"
  printf 'theory %s\n  imports Isabelle_LLVM.LLVM_DS_All\nbegin\n\n%s\n\nend\n' "$1" "$2" >"$D/$1/$1.thy"
}
F32='definition f :: "32 word \<Rightarrow> 32 word llM" where [llvm_code]: "f x \<equiv> Mreturn x"'
# control: fixed-width signature, accepted
thy P_control "$F32
export_llvm f is \"int32_t f (int32_t)\" file \"p.ll\""
# C type int (upstream prototypes use int, unsigned int, size_t, enums)
thy P_int "$F32
export_llvm f is \"int f (int)\" file \"p.ll\""
# const-qualified pointer parameter
thy P_const "definition g :: \"8 word ptr \<Rightarrow> 32 word llM\" where [llvm_code]: \"g p \<equiv> Mreturn 0\"
export_llvm g is \"int32_t g (const uint8_t*)\" file \"p.ll\""
# variadic definition (onig_error_code_to_str)
thy P_variadic "$F32
export_llvm f is \"int32_t f (int32_t, ...)\" file \"p.ll\""
# function-pointer parameter type (onig_set_warn_func, callbacks)
thy P_fnptr_param "$F32
export_llvm f is \"int32_t f (int32_t (*)(int32_t))\" file \"p.ll\""
# the same two, with the signature in a cartouche (no outer-syntax
# string or comment lexing)
thy P_variadic_cart "$F32
export_llvm f is \<open>int32_t f (int32_t, ...)\<close> file \"p.ll\""
thy P_fnptr_param_cart "$F32
export_llvm f is \<open>int32_t f (int32_t (*)(int32_t))\<close> file \"p.ll\""
# struct typedef with a function-pointer field (OnigEncodingType); the
# generated header p.h shows how the field was read

thy P_fnptr_field "$F32
export_llvm f is \"int32_t f (int32_t)\" defines \<open>typedef struct { int32_t (*len)(uint8_t*); int32_t min; } enc;\<close> file \"p.ll\""
# struct typedef with plain fields (accepted: layout from the struct type)
thy P_struct "definition h :: \"(32 word \<times> 64 word) ptr \<Rightarrow> 32 word llM\" where [llvm_code]: \"h p \<equiv> Mreturn 0\"
export_llvm h is \"int32_t h (pair*)\" defines \<open>typedef struct { int32_t a; int64_t b; } pair;\<close> file \"p.ll\""
printf 'construct\tbuilt\tfirst error\n' >"$D/results.tsv"
for p in P_control P_int P_const P_variadic P_fnptr_param P_variadic_cart P_fnptr_param_cart \
  P_fnptr_field P_struct; do
  nice -n 10 "$ISA" build -c -j 1 -o threads="$JOBS" -d "$AFP/thys" -d "$ILLVM/thys" \
    -D "$D/$p" >"$D/$p.log" 2>&1
  st=$?
  e=$(grep -m1 '^\*\*\*' "$D/$p.log" | sed "s#$D#<probe>#g" | tr '\t' ' ')
  b=no; [ $st -eq 0 ] && b=yes
  printf '%s\t%s\t%s\n' "$p" "$b" "${e:--}" >>"$D/results.tsv"
  echo "$p built=$b"
done
for p in P_fnptr_field P_struct; do
  echo "== $p/p.h"; grep -v '^$' "$D/$p/p.h"
done >"$D/headers.txt" 2>&1
