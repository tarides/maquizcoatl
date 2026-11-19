# exp-11 re-runs r2-r4: worst case

## What

The worst-case phase of runs r2, r3 and r4: the same three labelled
synthetic patterns as r1, on `"a"*n "!"` for n = 16 to 4096, every
column, each point in its own process under `timeout 60`. Raw data:
`2026-11-19-exp-11-rN-worst-case.csv` per run, and
`2026-11-19-exp-11-rerun-worst-case.csv` across the runs (one row per
point: outcome and code over the runs, median, min and max seconds).

## Why

Criterion 4 of issue #2, re-measured with the fixed harnesses: RE2 and
Rust `regex` now extract every capture group in worst mode too, and
ocaml-re computes groups (`Re.exec_opt`) instead of `Re.execp`
(`5aabc3e`).

## Provenance

- Runs, repository and machine: as in
  `2026-11-19-exp-11-rerun-throughput.md`; worst phase of `run.sh rN all`
  (r2 15:48:04-15:48:18, r3 16:26:56-16:27:10, r4 17:47:43-17:47:57 UTC),
  `worst.sh` unchanged since r1, gate passed at 0-1% busy.
- Table across runs: `python3 -I -S spread.py --worst
  2026-11-19-exp-11-r{2,3,4}-worst-case.csv`.
- Limits: all defaults, as in `2026-11-19-exp-11-worst-case.md`.

## Raw data (summary)

All 189 points (3 families × 7 columns × 9 lengths) have the same
outcome and return code in r2, r3 and r4, and the same as in r1. No
point reached the 60 s cap. Median over the three runs:

| engine | jq `(a+)+$` | php `(a\|aa)+$` | vscode `(\w+\s?)+$` |
|---|---|---|---|
| onig-threaded | n=16 no match 2.9 ms; n≥32 −17 after 0.13-0.15 s | n=16 0.2 ms; n≥32 −17 after 0.084 s | n=16 4.5 ms; n≥32 −17 after 0.11 s |
| onig-switch | n≥32 −17 after 0.22 s | −17 after 0.15 s | −17 after 0.16 s |
| pcre2-interp | n≥32 −47 after 0.22 s | n≥32 −47 after 0.21 s | n≥32 −47 after 0.30 s |
| pcre2-jit | n≥32 −47 after 0.028 s | n=32 no match 0.090 s; n=64-512 −47 after 0.037 s; n≥1024 −46 at once | n≥32 −47 after 0.037 s |
| re2 | no match, 10-16 µs | 10-14 µs | 9-15 µs |
| rust-regex | 5-9 µs | 5-8 µs | 13-20 µs |
| ocaml-re | 22-35 µs | 40-52 µs | 27-38 µs |

Between runs, the points of 1 ms or more vary by under 11% of their
median, except two single-process outliers of onig-threaded jq (r3
n = 64 at 0.189 s, r2 n = 256 at 0.227 s, against about 0.139 s at
every other length and run).

## Analysis and open questions

- Criterion 4 still holds with the fixed harnesses, and the r1 outcomes
  are reproduced exactly.
- Group extraction does not change the automaton engines' worst case
  at this scale: RE2, Rust `regex` and ocaml-re stay at 5-52 µs, as in
  r1 (5-51 µs), where RE2 and Rust asked for the overall match only and
  ocaml-re used `Re.execp`.
- The backtracking engines fail on their limits after the same times as
  in r1 within about 10% (Oniguruma threaded jq 0.13-0.15 s, php
  0.084 s against r1's 0.095 s), the same drift as in the throughput
  runs.
- onig-threaded jq n = 16 takes 2.9 ms in all three runs, against
  2.0 ms in r1's kept attempt and 2.9 ms in r1's discarded one: one
  short search, sensitive to the process state, like the small
  throughput cells.
