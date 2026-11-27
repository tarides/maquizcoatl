# Experiment #12 follow-up (issue #22), entry 6: catastrophic patterns inside the fragment

**What.** Decisions 3 and 6, run `x1`. Two patterns inside experiment
#9's fragment, `(a|aa)*b` (label `php-frag`: Ruby, options 12, the shape
of PHP's `(a|aa)+$`) and `(aa*)*b` (label `jq-frag`: Perl_NG, options
256, the shape of jq's `(a+)+$`), are searched on `"a"*n "!"`. The
columns are `c`, `c-noopt`, `stubs`, `ctypes` and `vm` at n = 16, 32,
..., 4096, and `rocq`, `fstar` at the comparable points: n = 16, and
n = 32 for `(a|aa)*b`. The fuel-bounded `cata-fuel` rows at the other
lengths were not run in run `x1` (below).

**Why.** Issue #10's catastrophic shape. Experiment #12's three
catastrophic patterns are outside the fragment, so they are not rerun.
Decision 3 removes the retry-budget measurement from the extracted
columns: they have no retry budget, only fuel, which counts VM
instructions and not backtracks. Instead it compares every column on the
time of a complete backtracking search where C completes one. Decision
6 adds a second comparable point wherever `c-noopt` completes under its
budget at n >= 32.

Provenance: [entry 1](2026-11-27-exp-12-followup-provenance.md).
Command: `run22.py cata x1 10` (experiment #12's `cata` subcommand with
`run.py`'s `CATA` set to the two patterns by `run22.py`; experiment
#12's own `CATA` is unchanged). Retry limit 10,000,000 per start
position (`CATA_LIMIT`), `timeout 60` per point, 10 interleaved runs on
CPU 2, rows stopped at the first length where every run is `cap` (none
was). Extracted columns: fuel `max_int`. Series 13:08-13:24 UTC, load
average 1.03-2.17. All runs exited 0. Raw:
[`cata.csv`](2026-11-27-exp-12-followup-raw/cata.csv),
[`summary/cata.md`](2026-11-27-exp-12-followup-raw/summary/cata.md),
[`optimizer.txt`](2026-11-27-exp-12-followup-raw/optimizer.txt).

## The comparable points (median of 10 runs, time of one search)

| Pattern | n | c (optimiser) | c-noopt | vm | rocq | fstar | rocq / c-noopt | fstar / c-noopt |
|---|---:|---|---|---|---|---|---:|---:|
| `(a\|aa)*b` | 16 | MISMATCH 0.001 ms | MISMATCH 0.126 ms | MISMATCH 0.572 ms | MISMATCH 11.0 ms | MISMATCH 18.7 ms | 87x | 149x |
| `(aa*)*b` | 16 | MISMATCH 0.001 ms | MISMATCH 1.54 ms | MISMATCH 6.44 ms | MISMATCH 122 ms | MISMATCH 213 ms | 79x | 138x |
| `(a\|aa)*b` | 32 | MISMATCH 0.001 ms | MISMATCH 266 ms | **limit** (-17) 258 ms | MISMATCH 28,613 ms | MISMATCH 55,249 ms | 108x | 208x |

At each comparable point, every run of every column has the same outcome
(stubs and ctypes give the same results as `c`). At n = 32 the Rocq runs
range over 28.4-29.0 s and the F\* runs over 55.1-55.8 s: under the 60 s
`timeout`, but F\* has less than 5 s of margin. The extracted columns
agree with `c-noopt` (MISMATCH) at all three points.

## The other lengths (baselines)

| Pattern | n | c, stubs, ctypes | c-noopt | vm |
|---|---|---|---|---|
| `(a\|aa)*b` | 64..4096 | MISMATCH, 0.001-0.011 ms | limit, 109.5-111.0 ms | limit, 257.7-259.3 ms |
| `(aa*)*b` | 32..4096 | MISMATCH, 0.001-0.011 ms | limit, 112.8-115.8 ms | limit, 238.7-240.4 ms |

## Findings

- **The C optimiser rejects both subjects without backtracking.** The
  default library finds the required literal `b` absent and answers
  MISMATCH in 1-11 µs at every n, so `c`, `stubs` and `ctypes` measure
  the optimiser's rejection, not a search. The optimiser's choice for
  each pattern, read from the `onig-dbgc` build, is in
  `optimizer.txt` (section below). The comparable C figure is
  `c-noopt`'s. The hand-written VM and the extracted VMs have no
  optimiser.
- **Extraction cost on backtracking.** A complete backtracking search in
  the Rocq-extracted VM takes 79-108x as long as Oniguruma's
  unoptimised matcher, and about 19x as long as the hand-written VM at
  n = 16, where the VM completes. The F\* column takes 138-208x and
  about 33x. On the
  short shape these ratios were 1.6-3.4x C on jq and PHP. They are
  larger here because every backtrack is spent in the extracted code's
  allocation and list traversal: `IStr` runs `skipn pos` from the start
  of the suffix (`rocq/Vm.v:73-75`), so each literal step costs time
  linear in the distance from the start position. Captures are an
  association list that grows with every group write
  (`rocq/Vm.v:17-23`), and both patterns have a starred group.
- **The hand-written VM differs from `c-noopt` at n = 32 for
  `(a|aa)*b`.** It returns -17 after 258 ms, while `c-noopt` completes
  in 266 ms. Its retry count is not Oniguruma's: experiment #12's
  agreement entry recorded one PHP retry-count disagreement of the same
  kind. This is a pre-existing property of experiment #12's VM, not a
  change made by this run.
- **No retry-budget measurement for the extracted columns** (decision
  3). Fuel counts instructions and the C budget counts backtracks, so no
  fuel value gives the same cut-off as `retry_limit_in_match`. The
  columns are compared only where C completes.

## The fuel-bounded rows were not run in run `x1`

Decision 3 also asks for the time until `OutOfFuel` at the other lengths
(`x22.exe cata-fuel`, fuel 10,000,000 per start position), labelled not
comparable. The pilot (one run per cell) measured them:

| Pattern | n | rocq (pilot, 1 run) | fstar (pilot, 1 run) |
|---|---|---|---|
| `(aa*)*b` | 32, 64, 128, 256, 512, 1024, 2048, 4096 | 1.37, 1.80, 2.62, 4.36, 7.67, 14.3, 27.9, 53.9 s | 2.69, 3.92, 5.99, 12.1, 18.9, 37.0 s, cap at 2048 |
| `(a\|aa)*b` | 64, 128, 256, 512, 1024, 2048, 4096 | 1.88, 2.85, 4.75, 8.38, 16.0, 31.2, 59.9 s | 3.93, 6.61, 11.8, 20.8, 43.6 s, cap at 2048 |

Each cell exhausts the same 10,000,000 instructions at the first start
position, yet the time grows roughly linearly with n. This is the cost
of `skipn` from the start of the suffix: each instruction costs time
proportional to the current position. These are pilot figures (one run
each); they are not the series that the plan asks for.

Ten runs would have taken about 97 minutes, more than the rest of the
run's 4 hours of wall clock. The plan's reduction rule covers only the
large series, so the series was left out of run `x1`, not shortened.
Whether to run it, and how, is a question for the maintainer on issue
#22.
