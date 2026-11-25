# exp-11 worst case: catastrophic backtracking under default limits

## What

One labelled synthetic catastrophic-backtracking pattern per workload
family, in that family's syntax and options, searched on subjects
`"a"*n "!"` for n = 16, 32, …, 4096 on every engine column, each point
in its own process under `timeout 60`. Raw data:
`2026-11-19-exp-11-worst-case.csv` (family, pattern, syntax, options,
engine, length, outcome `ok`/`error`/`cap`, seconds, return code).

## Why

Criterion 4 of issue #2: worst-case behaviour with Oniguruma's default
retry limit, for the ReDoS policy of the spec.

## Provenance

- Repository: `worst.sh` as fixed in commit `234eac6` (the first attempt used
  `|` as field separator, which broke the php pattern `(a|aa)+$`; that
  attempt is discarded and the whole phase was re-run).
- Machine, toolchains, pinning (`taskset -c 4`) and gate: as in
  `2026-11-19-exp-11-throughput.md`. Command `run.sh r1 worst`,
  2026-11-19 12:41 UTC, exit 0, 15 s.
- Limits: all defaults. Oniguruma retry limit in match 10,000,000
  (`upstream/src/regint.h:110-111`), unlimited stack; PCRE2 match limit
  10,000,000, default depth and heap limits; PCRE2 JIT stack 32 KiB
  (default, no `pcre2_jit_stack_assign`); RE2, Rust and ocaml-re have no
  backtracking limit.

## Parameters

| family | pattern (synthetic, labelled) | syntax | options |
|---|---|---|---|
| jq | `(a+)+$` | PERL_NG | 256 (CAPTURE_GROUP) |
| php | `(a|aa)+$` | RUBY | 12 (MULTILINE, SINGLELINE) |
| vscode | `(\w+\s?)+$` | ONIGURUMA | 256 |

#1's fuel tier is driven by backreferences and subexpression calls,
which are not catastrophic on these subjects and which RE2, Rust and
ocaml-re reject; synthetic patterns were used instead, as the plan
allows.

## Raw data (summary)

| engine | jq `(a+)+$` | php `(a\|aa)+$` | vscode `(\w+\s?)+$` |
|---|---|---|---|
| onig-threaded | n=16 no match 2.9 ms; n≥32 −17 (`ONIGERR_RETRY_LIMIT_IN_MATCH_OVER`) after 0.14-0.15 s | n=16 0.2 ms; n≥32 −17 after 0.095 s | n=16 4.9 ms; n≥32 −17 after 0.12 s |
| onig-switch | same outcomes, −17 after 0.23 s | −17 after 0.17 s | −17 after 0.17 s |
| pcre2-interp | n≥32 −47 (`PCRE2_ERROR_MATCHLIMIT`) after 0.24 s | n≥32 −47 after 0.21-0.24 s | n≥32 −47 after 0.33 s |
| pcre2-jit | n≥32 −47 after 0.031 s | n=32 no match 0.098 s; n=64-512 −47 after 0.04 s; n≥1024 −46 (`PCRE2_ERROR_JIT_STACKLIMIT`) at once | n≥32 −47 after 0.041 s |
| re2 | no match, 10-14 µs at every n | 11-15 µs | 10-27 µs |
| rust-regex | 5-9 µs | 5-9 µs | 14-22 µs |
| ocaml-re | 24-33 µs | 43-51 µs | 28-37 µs |

No point reached the 60 s cap.

## Analysis and open questions

- Criterion 4 is met: each family's pattern was timed on every column
  with Oniguruma's default retry limit, and the outcome recorded.
- Contrary to the plan's expectation (rows mostly at `cap`), Oniguruma's
  default retry limit of 10,000,000 is reached in 0.1-0.15 s on this
  machine, so every backtracking engine fails fast with an error from
  n = 32 on, instead of running for minutes. The limit is a time bound of
  roughly a tenth of a second per search, not a correctness property: a
  legitimate search with many retries fails the same way.
- The automaton engines (RE2, Rust `regex`, ocaml-re) answer in
  microseconds at every length; ocaml-re accepts all three patterns.
- PCRE2 JIT hits its 32 KiB default stack from n = 1024 on `(a|aa)+$`, a
  different error from the match limit: a third resource limit to keep in
  mind when comparing failure modes.
- For the spec: the ReDoS guard of the reference is a step budget that
  turns exponential cases into an error after about 10^7 steps; whether
  Maquizcoatl keeps a budget, a linear-time subset, or both is the
  decision #11's numbers feed.
