# Experiment #6, entry 4: throughput and the 10^6-case extrapolation

**What.** Criteria 3 and 4 for milestone 1: cases per second of each
semantics in every execution mode the tool offers, on the 149 parsed
in-subset cases (152 for stack G and C, which also parse the 3 `e`
cases), with the C library as the reference; the extrapolated wall-clock
time of 10^6 differential cases and the verdict against Decision 1
(at most 8 hours on one core, at least 34.7 cases/s).

**Why.** This is what experiment #6 decides: whether each tool's
executable spec can be the oracle of differential fuzzing against the C
library at millions of cases (issue #1, "What it decides").

## Provenance

As [entry 1](2026-11-20-exp-06-provenance.md). Timed on CPUs 28-31,60-63,
one run at a time under a lock, median of three runs, load average
before each run in `times.tsv`:

- `series.sh m1 e07` (14:48-15:29 UTC, `series.log`): extracted and
  compiled throughput (`thr`) for C, stack G, Rocq, Lean, Why3, F\*;
  in-prover modes (`inp`) for Rocq, Lean, Why3 (and F\*, invalid, see
  below); then `T_spec` (entry 5) and experiment #7's rerun (entry 6).
- `series2.sh m1`: Verus and Isabelle/HOL, `thr`, `inp` (Isabelle) and
  `T_spec`.
- `series3.sh m1`: F\*'s normaliser rerun with its checked-file cache
  cleared (labels `fstar-Q0c`, `fstar-QNc`).
- `series4.sh m1`: Isabelle's `value [code]` rerun with 100,000 passes
  (labels `isabelle-Q0L`, `isabelle-QVL`).

Passes per run are in [reps.env](2026-11-20-exp-06-raw/reps.env),
calibrated by untimed runs (run-id `cal`, CPUs 4-7) so that each fold
lasts about 10 s or more. Drivers: compiled or extracted code times
`passes REPS` in-process (`search_s`, `search_cps` lines, collected in
`<tool>/throughput-lines.txt`); stack G and the C oracle time parse
(compile), search on the precompiled pattern, and end to end
(parse + search, plus free for C) separately. In-prover modes: the
evaluation command's wall-clock minus an import-only baseline Q0 of the
same run (experiment #7's method): Rocq `Eval vm_compute` and
`Eval native_compute` of `passes N cases 0` (the semantics and cases
compiled with `-native-compiler yes` beforehand; `QN1` times one pass,
which is mostly the on-demand compilation of the evaluated term), Lean
`#eval`, Why3 `why3 execute --rac-timelimit=1150 'passes N 0'`, F\*
`assert_norm (passes N cases 0 = ...)` (not in the plan: F\*'s
normaliser is its in-prover evaluation), Isabelle `value [code]` in a
session built with `isabelle build -c`.

## Raw data


Extracted or compiled code: in-process timing of REPS passes (median of three runs); wall-clock and peak RSS of the whole process from `/usr/bin/time -v`.

| Row | Mode | REPS | Parse cases/s | Search cases/s | End to end cases/s | 10^6 cases (s) | Wall s | RSS MB | Load (1 min) |
|-----|------|-----:|-------------:|---------------:|-------------------:|---------------:|-------:|-------:|-------------|
| C library (reference) | native | 400000 | 858317 | 5788778 | 684137 | 1.5 | 170.18 | 2 | 0.10, 1.49, 2.04 |
| stack G, ocamlopt | native | 400000 | 2566443 | 5482772 | 853167 | 1.2 | 106.04 | 7 | 1.02, 2.54, 2.24 |
| Rocq, extracted OCaml | extracted | 60000 | (stack G) | 767480 | 590804 | 1.7 | 11.65 | 7 | 2.05, 1.31, 1.37 |
| Lean 4, lake native build | extracted | 50000 | (stack G) | 881968 | 656395 | 1.5 | 8.45 | 8 | 1.81, 1.24, 1.44 |
| Why3, extracted OCaml | extracted | 35000 | (stack G) | 456509 | 387570 | 2.6 | 11.43 | 7 | 1.75, 1.22, 1.48 |
| F*, extracted OCaml | extracted | 120000 | (stack G) | 1567045 | 972963 | 1.0 | 11.41 | 7 | 1.58, 1.78, 2.73 |
| Verus, compiled Rust | compiled | 250000 | (stack G) | 3533001 | 1486569 | 0.7 | 10.54 | 2 | 1.20, 0.41, 0.61 |
| Isabelle/HOL, export_code OCaml | extracted | 150000 | (stack G) | 1649722 | 1004211 | 1.0 | 13.55 | 8 | 1.16, 0.50, 0.67 |

For prover rows, end to end = stack G's parse plus the prover's search (plan step 8); 10^6 cases (s) = 10^6 / end-to-end cases/s.

In-prover evaluation: wall-clock of the evaluation command minus the import-only baseline Q0 of the same run (experiment #7's method), median of three runs.

| Prover | Mode | Passes | Cases | Eval s (median) | Q0 s (median) | Search cases/s | 10^6 cases (s) | Peak RSS MB | Load (1 min) |
|--------|------|-------:|------:|----------------:|--------------:|---------------:|---------------:|------------:|-------------|
| rocq | vm_compute | 3000 | 447000 | 26.53 | 0.48 | 17153 | 58.7 | 1688 | 2.54, 1.75, 1.27 |
| rocq | native_compute | 4000 | 596000 | 19.34 | 0.48 | 31618 | 32.0 | 1731 | 2.54, 1.49, 1.29 |
| rocq | native_compute, first call (1 pass) | 1 | 149 | 0.61 | 0.48 | 1146 | 872.9 | 268 | 2.54, 1.49, 1.29 |
| lean | #eval | 5000 | 745000 | 12.96 | 0.28 | 58800 | 17.4 | 459 | 2.10, 1.41, 1.21 |
| why3 | why3 execute | 5 | 745 | 12.48 | 0.44 | 62 | 16174.9 | 1129 | 1.86, 1.32, 1.23 |
| fstar | assert_norm (normaliser; extra mode) | 5 | 745 | 11.87 | 0.12 | 63 | 15785.6 | 483 | 2.84, 2.56, 2.32 |
| isabelle | value [code] (fold under 10 s, see QVL) | 8000 | 1192000 | 10.38 | 8.45 | 617617 | 2.0 | 1428 | 1.04, 2.10, 3.00 |
| isabelle | value [code] | 100000 | 14900000 | 15.49 | 8.61 | 2159420 | 0.9 | 1446 | 1.11, 1.30, 1.25 |


Isabelle's first `value [code]` series (8,000 passes) folded in about
2 s, under the 10 s floor, because the evaluation is compiled by
Poly/ML and runs close to the extracted code; the rerun with 100,000
passes folds in about 6.9 s with a Q0 spread of 0.11 s across runs,
kept as the figure (still under 10 s, noted). Lean's extracted runs
last 8.4 s each, also slightly under. Every other fold lasts 10 s or
more.

F\*'s first normaliser series (labels `fstar-Q0`, `fstar-QN`, in
`fstar/times.tsv`) measured nothing: F\* reused the checked file of
the calibration run (same source, `--cache_checked_modules`) and
finished in 0.11 s. The script now removes the checked files of Q0 and
QN before each run; the figures above are from the rerun.

The CPU check before each series found the timing CPUs free; the only
entries it logged are its own `ps` process (`<user> 62 400 ps`), after
which it waited 60 s and found them free.

## Extrapolation and verdict (criterion 4)

10^6 cases at the measured end-to-end rate, against 28,800 s (8 h):

| Row, mode | 10^6 cases | Verdict |
|-----------|-----------:|---------|
| C library (reference) | 1.5 s | (reference) |
| stack G, ocamlopt | 1.2 s | fast enough |
| Rocq, extracted OCaml | 1.7 s | fast enough |
| Rocq, `native_compute` | 32 s | fast enough |
| Rocq, `vm_compute` | 59 s | fast enough |
| Lean 4, lake native build | 1.5 s | fast enough |
| Lean 4, `#eval` | 17 s | fast enough |
| Why3, extracted OCaml | 2.6 s | fast enough |
| Why3, `why3 execute` | 16,175 s (4.5 h) | fast enough, with a 1.8x margin |
| F\*, extracted OCaml | 1.0 s | fast enough |
| F\*, normaliser (`assert_norm`) | 15,786 s (4.4 h) | fast enough, with a 1.8x margin |
| Verus, compiled Rust | 0.7 s | fast enough |
| Isabelle/HOL, `export_code` OCaml | 1.0 s | fast enough |
| Isabelle/HOL, `value [code]` | 0.9 s | fast enough |

Prover rows add stack G's parse time (2.57 M patterns/s) to the
prover's search time (plan step 8): the parser stays in OCaml for
stacks A to F at milestone 1. Reading or holding the case module is
excluded. The extrapolation assumes fuzz cases of the size of these
upstream cases (patterns and subjects of at most 105 bytes, most under
20).

## Analysis and open questions

- Every tool is fast enough in every mode, on this fragment and these
  case sizes. Extracted or compiled code runs at 0.39-1.5 M cases/s end
  to end, within a factor of two of the C library (0.68 M/s, slower
  than stack G here because `onig_new` runs the optimiser and allocates
  on every compile, while the matching itself is equally fast for C and
  stack G on such short subjects). The extracted search alone ranges
  from 0.46 M/s (Why3, `Z.t` integers and monomorphic lists) to 3.5 M/s
  (Verus, machine integers and arrays). At these rates the oracle is
  never the bottleneck of a differential campaign; the C library and
  the fuzzer are.
- In-prover evaluation splits into two groups. Compiled evaluators
  (Isabelle `value [code]` via Poly/ML, Lean `#eval`, Rocq
  `native_compute` and `vm_compute`) reach 17,000-2,160,000 cases/s;
  interpreters (`why3 execute`, F\*'s normaliser) about 62 cases/s,
  10^6 cases in about 4.5 h, inside the 8 h bar only by a factor of 1.8.
  A larger semantics (milestone 2: lookaround, backreferences, case
  folding over the Unicode tables) will be slower per case, so the
  interpreted modes may not stay under the bar; the extracted modes have
  four orders of magnitude of margin.
- The comparison is between transcriptions of one small-step machine.
  Representation choices matter as much as the tool: F\* and Isabelle
  extract to OCaml with `Z.t` integers yet run faster than Rocq's
  extraction with native `int`; Why3's monomorphic lists (forced by its
  interpreter bug, entry 3) and boxed `Z.t` make it the slowest
  extraction.
- Context: experiment #12's OCaml VM (compiled bytecode, no optimiser)
  and the C library differ by 2-11x on large subjects; on these short
  test cases stack G's direct interpreter is on par with C.
- Not measured: Lean `#eval` with precompiled modules (the modules
  were built by `lake` without `precompileModules`, so `#eval` runs
  Lean's IR interpreter); Rocq's
  extraction with `ExtrOcamlNatBigInt`; a fuzz-generated case
  distribution (to be done when experiment #9's harness exists).
