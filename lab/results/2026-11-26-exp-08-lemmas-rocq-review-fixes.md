# Experiment #8 follow-up (issue #34), entry 5: corrections after the run-2 review

**What.** Corrections to entry 4
([2026-11-26-exp-08-lemmas-rocq.md](2026-11-26-exp-08-lemmas-rocq.md))
required by the independent review of run 2 on issue #34
([comment](https://github.com/tarides/maquizcoatl/issues/34#issuecomment-7196308911)),
problems 1-4. No new run: every figure below is recomputed from entry 4's
raw data. Entry 4 is left as recorded; this entry supersedes the passages
it names.

**Why.** The review confirmed run 2 (both lemmas and the stretch closed
under the global context, no admit, figures recomputed from the raw
files) but found the total check time reported under a different
convention from experiment #9's, the "failed checks" unit missing for
run 4's comparison table, and the mutant script not runnable from the
raw directory as checked in.

## Provenance

Text corrections only, on the data of entry 4 (branch commit `c8b8840`,
raw files in [`2026-11-26-exp-08-lemmas-rocq-raw/`](2026-11-26-exp-08-lemmas-rocq-raw/)).
Totals computed from [`rocq/time.tsv`](2026-11-26-exp-08-lemmas-rocq-raw/rocq/time.tsv)
(columns: run, file, wall clock, max RSS in KB, user, system) by summing
the six files per run. Nothing was run on the bench host.

## Corrections

### 1. Total check time: median of the full checks, 11.19 s (entry 4, "Check time")

Entry 4's **11.17 s** is the sum of the per-file medians. Experiment
#9's convention ([2026-11-25-exp-09-rocq-measure.md](2026-11-25-exp-09-rocq-measure.md),
"Check time") is the median of the per-run totals, and that is the figure
run 4 compares. Per timed run, summed over the six files:

| Timed run | wall clock | user | system | user + system | peak RSS |
|---|---:|---:|---:|---:|---:|
| 1 | 11.17 s | 8.97 s | 2.15 s | 11.12 s | 492,848 KB |
| 2 | 11.19 s | 9.01 s | 2.15 s | 11.16 s | 493,284 KB |
| 3 | 11.20 s | 9.01 s | 2.14 s | 11.15 s | 492,816 KB |
| **median** | **11.19 s** | | | **11.15 s** | |

Spread (max - min): 0.03 s wall clock, 0.04 s CPU. Peak RSS is
`AbsentProof.v`'s. The per-file medians of entry 4 stand. The notebook
index row of entry 4 and the dashboard note repeat 11.17 s; read 11.19 s
(median of three full checks) wherever the total is compared.

### 2. Failed checks and failing invocations (entry 4, "Effort")

Experiment #9's plan (`plans/09-representative-proof.md`, step 8)
requires each attempt figure to name its unit. For run 2 of issue #34:

- **compile invocations**: 43 = 12 passing + 29 failing + 2 interrupted;
- **failing invocations**: 29 (every `rc=1` row of `invocations.tsv`);
- **failed checks**: 27, the failing invocations less the two that only
  read goals with `Show` (no proof was being checked to completion);
- the two interrupted invocations (a looping tactic) are counted in
  neither figure.

Run 4's table should carry 29 failing invocations and 27 failed checks
side by side.

### 3. Working directory of `mutants/run.sh`

`mutants/run.sh` compiles `Absent.v`, `Desugar.v` and `DM1`-`DM8` from its
own directory, but the raw directory holds only the nine `TM*.v` drivers
(and `Rcheck.v`). The recorded run used a scratch working directory on
the bench host made of: the sources of `lab/08-discriminating-lemmas/rocq/`
at `c8b8840` (for `Absent.v`, `Desugar.v`), run 1's mutants
`DM1`-`DM8` from [`2026-11-26-exp-08-lemmas-raw/mutants/`](2026-11-26-exp-08-lemmas-raw/mutants/),
and the nine `TM*.v` drivers of entry 4's raw directory. To rerun,
copy those three sets into one directory with `run.sh`. The results
(`out.txt`, the drivers) stand.

### 4. History of `run.sh`

Commit `0ddbf53` carried a tilde-relative path to the bench work
directory in `run.sh` (no username or host); `7b66a74` replaced it with
`BENCH_WORKDIR`. It stays in the branch history until the squash merge of
PR #40, which drops the intermediate commit from `main`; the history is
not rewritten.

## Analysis

No conclusion of entry 4 changes. The check-time figure for comparison
is 11.19 s (median of three full checks; 11.15 s user + system), and
run 2's effort is 29 failing invocations, 27 failed checks.
