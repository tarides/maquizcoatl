# Experiment #6, milestone 2, entry 4: throughput on S2 and the 10^6-case extrapolation (run 1)

**What.** Criteria 3 and 4 on the S2 cases for the rows of run 1: the C
library, stack G, Why3 (`why3 execute` and extracted OCaml) and F\*
(normaliser and extracted OCaml); the slowdown from milestone 1 to
milestone 2 per mode; the full-table spot check (decision 2 on issue
#28); and the correction note for milestone 1's Isabelle `value [code]`
and Lean `lake` folds (work package D).

**Why.** Question 1 of issue #28: do the interpreted in-prover modes
(`why3 execute` and the F\* normaliser, about 62 cases/s on milestone 1,
under the 8-hour bar by only 1.8x) stay at or above 34.7 cases/s on the
S2 semantics and cases?

## Provenance

As [entry 1](2026-11-24-exp-06-m2-provenance.md). Timed on CPUs
28-31,60-63, one run at a time under the lock; load average before each
run in `*/times.tsv`; the CPU check before each series found the timing
CPUs free every time ([series logs](2026-11-24-exp-06-m2-raw/)).

- `series-m2-1a.sh r1` (14:11-14:30 UTC): C oracle (30,000 passes) and
  stack G (9,000 passes), parse, search and end to end, three runs.
- `series-m2-1b.sh r1` (14:30-15:03 UTC): Why3 and F\* extracted
  (1,500 and 2,000 passes), three runs; `why3 execute` and the F\*
  normaliser, Q0 then one pass of the 1,160 emitted cases, three runs;
  `T_spec` (entry 5); the spot check (full table, one run).
- `series-m2-1c.sh r1`: Why3 `T_spec` rerun (entry 5).
- `series-m2-1e.sh r1` (15:03-15:08 UTC): the property-heavy cases with
  the restricted table, one run each, the baseline of the spot check.
  These runs overlapped the untimed Why3 master build of work package H
  (12 jobs on CPUs 0-15 under `nice -n 10`, other L3 complexes); load
  before the runs 1.2 (Why3) and 3.0 (F\*).
- `series-m2-1d.sh m2-r1` (14:03-14:07 UTC): work package D.

Passes: [reps-m2.env](../06-spec-speed/reps-m2.env), calibrated by
untimed runs on CPUs 0-15 so that every fold lasts 10 s or more. One
pass of an interpreted mode lasts more than 10 s, so a single pass is
the fold (plan step 6). Method as milestone 1: drivers time `passes N`
in-process; in-prover modes are the command's wall-clock minus the
import-only baseline Q0 of the same run; prover rows add stack G's parse
for end to end (plan step 8). Each F\* normaliser run deletes the checked
files of Q0 and QN first; `assert_norm (passes 1 cases 0 = 1154)` holds
(1,154 of the 1,160 emitted cases give C's exact verdict, entry 3).

## Raw data

Extracted or compiled code (median of three runs):

| Row | Mode | Passes | Parse cases/s | Search cases/s | End to end cases/s | 10^6 cases (s) | Milestone 1 end to end | Slowdown (search) |
|-----|------|-------:|---:|---:|---:|---:|---:|---:|
| C library (reference) | native | 30,000 | 312,316 | 3,413,444 | 273,483 | 3.7 | 684,137 | 1.7x |
| stack G, ocamlopt | native | 9,000 | 212,779 | 1,002,373 | 168,525 | 5.9 | 853,167 | 5.5x |
| Why3, extracted OCaml | extracted | 1,500 | (stack G) | 148,965 | 87,622 | 11.4 | 387,570 | 3.1x |
| F\*, extracted OCaml | extracted | 2,000 | (stack G) | 219,094 | 107,945 | 9.3 | 972,963 | 7.2x |

In-prover modes (one pass of the 1,160 emitted cases per run; median of
three runs; peak RSS of the evaluation):

| Mode | Q0 s | Eval s | Runs (eval s) | Search cases/s | 10^6 cases | Verdict | Milestone 1 cases/s | Slowdown | Peak RSS |
|------|---:|---:|---|---:|---:|---|---:|---:|---:|
| Why3 `why3 execute` | 1.93 | 316.04 | 316.04, 314.92, 316.12 | 3.69 | 75.2 h | below the bar | 62 | 16.8x | 28.4 GB |
| F\* normaliser (`assert_norm`) | 0.27 | 124.92 | 125.72, 124.92, 124.65 | 9.31 | 29.8 h | below the bar | 63 | 6.8x | 6.8 GB |

The end-to-end rate adds stack G's parse (212,779 cases/s), which
changes neither figure at this precision.

Full-table spot check (decision 2 on issue #28): the 162
property-heavy cases (every emitted case whose AST holds a ctype or a
property), one pass, one run per table:

| Mode | Table | Q0 s | Eval s | Cases/s | Peak RSS |
|------|-------|---:|---:|---:|---:|
| Why3 `why3 execute` | restricted (24 ctypes) | 0.94 | 210.55 | 0.77 | 19.7 GB |
| Why3 `why3 execute` | full (629 ctypes) | 2.01 | 390.03 | 0.42 | 23.7 GB |
| F\* normaliser | restricted | 0.21 | 10.41 | 15.9 | 0.46 GB |
| F\* normaliser | full | 0.41 | 10.47 | 16.1 | 0.56 GB |

The spot check finished inside the 20-minute cap (6.5 min for the
longest run).

Calibration (untimed, CPUs 0-15): `why3 execute` on the first 20 and
200 cases took 2.6 s and 9.1 s; the F\* normaliser on the first 100 and
400 cases 18.1 s and 71.7 s. The early cases are faster than the
average: `why3 execute` ran the whole module at 3.7 cases/s.

### Work package D: correction note for milestone 1

Milestone 1's Isabelle `value [code]` and Lean `lake` driver, rerun on
milestone 1's 149 cases and semantics with milestone 1's scripts and
more passes, so that each fold lasts at least 10 s (milestone 1: about
6.9 s and 8.4 s). One untimed calibration run (CPUs 0-3) gave 12.5 s
(Isabelle, QV minus Q0) and 12.6 s (Lean); three pinned runs:

| Mode | Passes | Fold s (median) | Runs | Search cases/s | Milestone 1 figure |
|------|-------:|---:|---|---:|---:|
| Isabelle `value [code]` (QV minus Q0) | 200,000 | 12.53 (21.18 - 8.65) | QV 21.18, 20.87, 21.22; Q0 8.41, 8.65, 8.70 | 2,378,292 | 2,159,420 (100,000 passes, 6.9 s) |
| Lean 4, `lake` native build | 75,000 | 12.59 | 12.53, 12.59, 12.71 | 887,390 | 881,968 (50,000 passes, 8.4 s) |

Both folds now last more than 10 s. Lean's figure moves by 0.6% and
Isabelle's by 10%; neither changes a verdict (both are far above the
bar). Milestone 1's entries are not edited.

Raw data: [g](2026-11-24-exp-06-m2-raw/g/), [why3](2026-11-24-exp-06-m2-raw/why3/),
[fstar](2026-11-24-exp-06-m2-raw/fstar/), [wpd](2026-11-24-exp-06-m2-raw/wpd/).

## Extrapolation and verdict (criterion 4)

10^6 cases at the measured end-to-end rate, against 28,800 s (8 h, at
least 34.7 cases/s):

| Row, mode | 10^6 cases | Verdict |
|-----------|-----------:|---------|
| C library | 3.7 s | reference |
| stack G, ocamlopt | 5.9 s | fast enough |
| Why3, extracted OCaml | 11.4 s | fast enough |
| F\*, extracted OCaml | 9.3 s | fast enough |
| Why3, `why3 execute` | 75.2 h | **below the bar** (9.4x too slow) |
| F\*, normaliser | 29.8 h | **below the bar** (3.7x too slow) |

## Analysis

- **Question 1: no.** On S2, both interpreted in-prover modes fall
  below the 34.7 cases/s bar: `why3 execute` runs 3.7 cases/s (16.8x
  slower than on milestone 1) and the F\* normaliser 9.3 cases/s (6.8x
  slower). Neither can serve as the oracle of 10^6 differential cases in
  8 hours on one core. The extracted code of both tools stays more than
  2,500 times above the bar.
- The slowdown is not explained by the case count alone (1,160 against
  149 cases, but the rates are per case). The S2 cases are heavier
  (case folding through the fold table, properties through decision
  trees, lookbehind restarts, backreferences), and the interpreters pay
  for each table lookup by evaluating the decision tree term. In Why3,
  memory grows to 28 GB for one pass, which suggests the interpreter
  retains the evaluated terms.
- **Spot check: the restricted table is optimistic for `why3 execute`,
  not for F\*.** On the property-heavy cases, the full table makes
  `why3 execute` 1.85x slower (0.42 against 0.77 cases/s) and adds 4 GB;
  the F\* normaliser runs at the same rate with either table (it
  unfolds only the branch it needs). The question-1 verdict for Why3 is
  therefore already "below the bar" on the optimistic side; with the
  full table it is further below. Caveat: the restricted-table baseline
  ran while the Why3 master build used other cores (load 1.2-3.0), one
  run each.
- The extracted rows slow down 3-7x from milestone 1, and stack G's
  parse 12x (its case-insensitive classes are closed under case folding
  at parse time, over the whole fold map); all stay well under a minute
  per 10^6 cases.
- Milestone 1's Lean and Isabelle folds are now above 10 s, with
  figures within 10% of milestone 1's.

## Work package H: the Why3 interpreter bug on Why3's master (optional)

`why3/bug/check.sh r1` (untimed, CPUs 0-15, `nice -n 10`, 12 jobs)
built Why3's master in a separate opam switch, `why3-master` (OCaml
5.4.1; `provers` untouched; 584 MB), pinned to
`git+https://gitlab.inria.fr/why3/why3.git#master` at
`5c30f6091172b75c4f610feb0ff0b4e16ca4db58` (reported version
`1.9.0+git`), and ran the isolated reproducer
[`why3/bug/bug.mlw`](../06-spec-speed/why3/bug/bug.mlw) with
`why3 execute -L . bug.mlw --use=Bug <expr>`:

| Expression | Why3 1.9.0 | master `5c30f60` |
|------------|------------|------------------|
| `some_list ()` (`Some (Cons 1 (Cons 2 Nil))`) | `Type mismatch between list.List.list int and int` | same |
| `cons_pair ()` (`Cons (P (Cons 1 Nil) Nil) Nil`) | `Type mismatch between Bug.pair and int` | same |
| `some_q ()` (`Some (Q 1 2)`, no list inside) | `result: option q = (Some (Q 1 2))` | same |

The bug is still present on master. Draft report (not filed; filing
waits for the maintainer's approval, decision 4 on issue #28):

> **`why3 execute`: "Type mismatch between ... and int" on a polymorphic
> constructor value that holds a list or a type containing one**
>
> Why3 1.9.0 and master (`5c30f6091172b75c4f610feb0ff0b4e16ca4db58`),
> OCaml 5.4.1, Linux x86_64.
>
> ```
> module Bug
>   use int.Int
>   use list.List
>   use option.Option
>   type pair = P (list int) (list int)
>   type q = Q int int
>   let some_list () : option (list int) = Some (Cons 1 (Cons 2 Nil))
>   let cons_pair () : list pair = Cons (P (Cons 1 Nil) Nil) Nil
>   let some_q () : option q = Some (Q 1 2)
> end
> ```
>
> `why3 execute bug.mlw --use=Bug "some_list ()"` prints
> `Type mismatch between list.List.list int and int`, and
> `"cons_pair ()"` prints `Type mismatch between Bug.pair and int`;
> expected: the values `Some (Cons 1 (Cons 2 Nil))` and
> `Cons (P (Cons 1 Nil) Nil) Nil`. `"some_q ()"` works. The module
> type-checks, and `why3 extract` produces correct OCaml for it.

Raw output: [why3-bug](2026-11-24-exp-06-m2-raw/why3-bug/).
