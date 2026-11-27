# Experiment #12 follow-up (issue #22), entry 11: large subjects, the ranks run 1 dropped (run 2)

**What.** This is the large-subject series of run `x2`. It covers
exactly the fragment patterns that run 1's reduction left out
([entry 5](2026-11-27-exp-12-followup-large.md)): log ranks 11, 12, 15
and 16, and source ranks 11, 12, 14, 15 and 16. There are nine
(source, pattern) pairs and five distinct patterns, four of them
alternations. Every column was timed (`c`, `stubs`, `ctypes`, `vm`,
`rocq-scan`, `fstar-scan`) at both sizes, 108 cells in all. The tables
below merge them with run 1's ranks 1-10 into the full fragment lists
of 14 log and 15 source patterns.

**Why.** Decision 7 (a). Run 1 kept ranks 1-10 without a recorded
reason, which dropped every alternation (run 1 review, problem 3). The
alternations are where experiment #12's hand-written VM is slowest, so
they are where the extracted columns' cost per byte most needs to be
measured.

Provenance: [entry 9](2026-11-27-exp-12-followup-run2-setup.md).
Command: `run22.py large x2 10 ">10"`, then `run22.py repeat x2 large`.
The protocol and binaries are run 1's: experiment #12's `scan` find-all
loop, with the warm-up scan untimed (it includes the extracted columns'
one conversion per subject), then one timed scan. There were 10
interleaved runs on CPU 2 under `timeout 120`. Decision 4's gate came
from run 2's pilot: 53.6 minutes projected, so there is no fallback and
the extracted columns ran at 16 MiB too. Series 14:27:54-15:16:20 UTC
(48.4 minutes), load average 1.08-5.50 (no flag: the plan flags
above 16), CPU 2 idle at the start. All 1,080 processes exited 0, with
no timeout. No cell had an IQR above 10% of its median, so `repeat` had
nothing to rerun. The match counts are identical across the six
columns for every (source, size, pattern). Raw:
[`large.csv`](2026-11-27-exp-12-followup-run2-raw/large.csv),
[`summary/large.md`](2026-11-27-exp-12-followup-run2-raw/summary/large.md),
[`summary/large-patterns.csv`](2026-11-27-exp-12-followup-run2-raw/summary/large-patterns.csv)
(both runs; column `run`).

## Run 2's patterns (median MB/s of 10 runs per cell)

| Source | Rank | Pattern | Size | c | stubs | ctypes | vm | rocq | fstar | vm / rocq time | vm / fstar time |
|---|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| log | 11 | `%\|\*\|/\|-\|\+` | 1 MiB | 254.28 | 251.73 | 199.04 | 17.79 | 2.70 | 1.08 | 6.6x | 16.4x |
| log | 11 | | 16 MiB | 252.93 | 251.67 | 231.97 | 17.73 | 2.69 | 1.08 | 6.6x | 16.4x |
| log | 12 | `/\*` | 1 MiB | 993.24 | 996.23 | 995.29 | 60.85 | 28.35 | 20.16 | 2.1x | 3.0x |
| log | 12 | | 16 MiB | 995.12 | 995.62 | 994.34 | 60.90 | 28.53 | 20.13 | 2.1x | 3.0x |
| log | 15 | `\&\|~\|\^\|\|` | 1 MiB | 258.19 | 259.99 | 258.96 | 21.90 | 4.23 | 1.61 | 5.2x | 13.6x |
| log | 15 | | 16 MiB | 256.08 | 256.17 | 256.13 | 21.65 | 4.21 | 1.61 | 5.1x | 13.4x |
| log | 16 | `<<\|>>>\|>>` | 1 MiB | 261.25 | 260.76 | 259.17 | 24.39 | 5.99 | 2.37 | 4.1x | 10.3x |
| log | 16 | | 16 MiB | 256.86 | 256.74 | 256.86 | 24.44 | 5.99 | 2.39 | 4.1x | 10.2x |
| src | 11 | `%\|\*\|/\|-\|\+` | 1 MiB | 98.70 | 84.28 | 23.75 | 17.25 | 2.70 | 1.09 | 6.4x | 15.8x |
| src | 11 | | 16 MiB | 129.14 | 113.77 | 36.23 | 17.27 | 2.69 | 1.09 | 6.4x | 15.9x |
| src | 12 | `/\*` | 1 MiB | 891.97 | 893.56 | 888.74 | 60.76 | 27.34 | 19.62 | 2.2x | 3.1x |
| src | 12 | | 16 MiB | 874.23 | 857.28 | 651.19 | 60.64 | 26.90 | 19.51 | 2.3x | 3.1x |
| src | 14 | `\&\|~\|\^\|\|` | 1 MiB | 215.70 | 206.57 | 107.75 | 21.44 | 4.17 | 1.59 | 5.1x | 13.5x |
| src | 14 | | 16 MiB | 222.15 | 213.51 | 120.90 | 21.73 | 4.19 | 1.60 | 5.2x | 13.6x |
| src | 15 | `<<\|>>>\|>>` | 1 MiB | 261.23 | 261.43 | 259.39 | 24.33 | 5.97 | 2.38 | 4.1x | 10.2x |
| src | 15 | | 16 MiB | 258.40 | 258.45 | 253.36 | 24.36 | 5.88 | 2.37 | 4.1x | 10.3x |
| src | 16 | `<=\|>=\|<>\|<\|>` | 1 MiB | 218.47 | 207.67 | 112.08 | 15.91 | 2.24 | 0.95 | 7.1x | 16.7x |
| src | 16 | | 16 MiB | 219.00 | 209.17 | 116.53 | 15.91 | 2.29 | 0.95 | 6.9x | 16.8x |

The two right-hand columns give the extracted column's time per byte
as a multiple of the hand-written VM's.

Experiment #12's context on these patterns
(`2026-11-19-exp-12-raw/summary/large-patterns.csv`): `c` is within 1%
of run 2's on every cell (for example log rank 11 at 16 MiB, 252.9
against 252.93). Its `vm` is within 1.2% on the four alternations
(17.3-24.4 MB/s) and 4.6-5.0% slower on `/\*` (57.9-58.2 against
60.6-60.9).

## Merged tables (run 1's ranks 1-10 and run 2's ranks above 10)

Median over patterns of the per-pattern medians (MB/s). The "all
patterns" figures are over the 14 log and 15 source patterns of the
fragment:

| Source | Size | Column | ranks 1-10 (run `x1`) | ranks above 10 (run `x2`) | all patterns | experiment #12, same patterns (context) |
|---|---|---|---:|---:|---:|---:|
| log | 1 MiB | c | 663.36 | 259.72 | 663.13 | 662.9 |
| log | 1 MiB | stubs | 662.70 | 260.37 | 661.25 | 662.6 |
| log | 1 MiB | ctypes | 662.53 | 259.06 | 661.37 | 662.8 |
| log | 1 MiB | vm | 71.18 | 23.14 | 60.80 | 58.1 |
| log | 1 MiB | rocq | 27.73 | 5.11 | 27.60 | - |
| log | 1 MiB | fstar | 20.20 | 1.99 | 19.88 | - |
| log | 16 MiB | c | 664.46 | 256.47 | 664.33 | 664.2 |
| log | 16 MiB | stubs | 664.46 | 256.46 | 664.43 | 663.8 |
| log | 16 MiB | ctypes | 664.42 | 256.49 | 663.83 | 663.6 |
| log | 16 MiB | vm | 71.22 | 23.04 | 60.94 | 58.2 |
| log | 16 MiB | rocq | 27.06 | 5.10 | 27.02 | - |
| log | 16 MiB | fstar | 19.52 | 2.00 | 19.50 | - |
| src | 1 MiB | c | 621.99 | 218.47 | 520.14 | 521.3 |
| src | 1 MiB | stubs | 606.38 | 207.67 | 488.69 | 497.0 |
| src | 1 MiB | ctypes | 390.60 | 112.08 | 259.39 | 258.8 |
| src | 1 MiB | vm | 69.69 | 21.44 | 60.76 | 58.0 |
| src | 1 MiB | rocq | 26.98 | 4.17 | 26.91 | - |
| src | 1 MiB | fstar | 19.50 | 1.59 | 19.43 | - |
| src | 16 MiB | c | 569.36 | 222.15 | 448.64 | 448.7 |
| src | 16 MiB | stubs | 546.13 | 213.51 | 409.36 | 419.4 |
| src | 16 MiB | ctypes | 328.34 | 120.90 | 253.36 | 253.6 |
| src | 16 MiB | vm | 69.88 | 21.73 | 60.64 | 57.9 |
| src | 16 MiB | rocq | 26.76 | 4.19 | 26.37 | - |
| src | 16 MiB | fstar | 19.41 | 1.60 | 19.33 | - |

With all patterns, the context column is experiment #12's medians over
the same 14 or 15 patterns. That is the column entry 5 first printed
for 10 patterns, and it is right for this set.

Time per MiB, median over all patterns:

| Subject | C (ms) | vm / C | rocq / C | fstar / C | rocq / vm | fstar / vm |
|---|---:|---:|---:|---:|---:|---:|
| log 1 MiB | 1.581 | 10.9x | 24.0x | 33.4x | 2.2x | 3.1x |
| log 16 MiB | 1.578 | 10.9x | 24.6x | 34.1x | 2.3x | 3.1x |
| src 1 MiB | 2.016 | 8.6x | 19.3x | 26.8x | 2.3x | 3.1x |
| src 16 MiB | 2.337 | 7.4x | 17.0x | 23.2x | 2.3x | 3.1x |

## Analysis

- **Alternations multiply the extraction cost per byte.** Per pattern,
  the Rocq column takes 4.1-7.1x the hand-written VM's time on the four
  alternations, against 2.1-2.7x on the 11 literal patterns (run 1's ranks 1-10 and
  `/\*`). The F\* column takes 10.2-16.8x, against 3.0-3.8x. Against C, Rocq is
  36-97x and F\* 90-235x on the alternations (C 98.7-261 MB/s). The
  factor grows with the number of alternatives: 4.1x and 10.2x with 3
  (`<<|>>>|>>`), 5.1x and 13.5x with 4, 6.4-7.1x and 15.8-16.8x with 5.
  A reading of the code that fits this, not a profile: an alternation
  compiles to `IPush`/`IJump` pairs (`rocq/Compile.v`, `Alt`), so at
  each start position every failing alternative costs one `IPush`
  (a new `EAlt` stack cell, `rocq/Vm.v:76`), one `IStr` on the list
  suffix and one backtrack, each step building a fresh state record. The
  hand-written VM takes the same steps without allocating, and F\* adds
  `Z.t` arithmetic to each one. Per-instruction profiles were not taken.
- **The medians over patterns hide this.** Over all 14 or 15 patterns
  the extracted columns' medians hardly move (Rocq 26.4-27.6 MB/s
  against 26.8-27.7 for ranks 1-10), because 11 of 14 log patterns and
  11 of 15 source patterns are literals. The VM's median falls from
  70-71 to 61 MB/s, so the median ratio drops to 2.2-2.3x (Rocq) and
  3.1x (F\*). The per-pattern table is the measure of the alternations;
  the median is the measure of the ranked mix.
- **Size independence holds.** The extracted columns hold the same
  throughput at 1 and 16 MiB on alternations too (log rank 11: 2.70
  against 2.69 MB/s for Rocq, 1.08 against 1.08 for F\*).
- **The run 1 VM speed-up is a literal-pattern effect.** On the four
  alternations the hand-written VM is within 1.2% of experiment #12's.
  On `/\*` it is 4.6-5.0% faster, the same order as run 1's 6-7% on the
  literals ([entry 8](2026-11-27-exp-12-followup-correction.md)). The
  cause is still not investigated. It is confined to the patterns where
  the VM's per-position path is shortest.
- **ctypes on source alternations.** ctypes costs up to 4.2x C on source
  rank 11 (23.75 against 98.70 MB/s at 1 MiB), where matches are dense.
  This is experiment #12's per-match crossing cost, as in its own table
  (the context column agrees within 1%).
