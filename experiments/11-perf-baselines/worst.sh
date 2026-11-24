#!/bin/bash
# Experiment #11, step 8: worst case. One labelled synthetic
# catastrophic-backtracking pattern per workload family (#1's fuel tier
# is driven by backreferences and subexpression calls, which are not
# catastrophic on these subjects and which RE2, Rust regex and ocaml-re
# do not support), in that family's syntax and options, on subjects
# "a"*n "!" for n = 16, 32, ..., 4096. Each point runs in its own
# process under `timeout 60` (outcome `cap`); a row stops at its first
# cap. Default limits everywhere: Oniguruma retry limit 10,000,000,
# PCRE2 match limit 10,000,000, PCRE2 JIT stack 32 KiB (default, no
# pcre2_jit_stack_assign). CSV on stdout.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/env.sh"
BIN="$BENCH/bin"; CPU=${TIME_CPU:-4}
ENGINES="onig-threaded onig-switch pcre2-interp pcre2-jit re2 rust-regex ocaml-re"
echo "family,pattern,syntax,options,engine,length,outcome,seconds,code"
while IFS=$'\t' read -r fam pat syn opt; do
  for e in $ENGINES; do
    n=16
    while [ $n -le 4096 ]; do
      out=$(timeout 60 taskset -c $CPU "$BIN/$e" worst "$pat" "$syn" "$opt" $n 2>/dev/null); rc=$?
      if [ $rc = 124 ]; then echo "$fam,\"$pat\",$syn,$opt,$e,$n,cap,60,"; break; fi
      set -- $out
      case "$1" in
        compile) echo "$fam,\"$pat\",$syn,$opt,$e,$n,compile-status-$2,,${3:-}"; break;;
        result)
          if [ "$2" -lt 0 ]; then echo "$fam,\"$pat\",$syn,$opt,$e,$n,error,$3,$2"
          else echo "$fam,\"$pat\",$syn,$opt,$e,$n,ok,$3,$2"; fi;;
        *) echo "$fam,\"$pat\",$syn,$opt,$e,$n,crash,,$rc"; break;;
      esac
      n=$((n*2))
    done
  done
done <<'PATS'
jq	(a+)+$	PERL_NG	256
php	(a|aa)+$	RUBY	12
vscode	(\w+\s?)+$	ONIGURUMA	256
PATS
