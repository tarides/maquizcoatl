# exp-11 re-runs r2-r4: throughput, between-run noise and capture cost

## What

Three full runs (r2, r3, r4) of experiment 11 with the fixed harness,
in the new bench directory, plus three short check measurements made
after them on the same binaries. This entry gives the three-run
throughput table, the between-run noise, the cost of capture extraction
in RE2 and Rust `regex`, and the php single-pattern share measured on
the bench host. It also reports a systematic effect found while
analysing the runs (compile timing before the search, see below).

Files:

- per run: `2026-11-19-exp-11-rN-raw-times.tsv` (every C, W, T and S
  line), `-rN-provenance.txt`, `-rN-run.log`, `-rN-agreement.csv`,
  `-rN-disagreements.csv`, `-rN-worst-case.csv`, and
  `-rN-outputs.tar.xz` (the whole run directory: check, only, time and
  worst outputs);
- across runs: `2026-11-19-exp-11-rerun-throughput.csv` (one row per
  engine and workload), `-rerun-compile.csv` (per-pattern compile
  medians); agreement and worst case have their own entries
  (`2026-11-19-exp-11-rerun-agreement.md`, `-rerun-worst-case.md`);
- checks: `2026-11-19-exp-11-rerun-checks-raw-times.tsv` (run labels
  `php-share`, `compile-first`, `nocompile`) and
  `-rerun-checks-provenance.txt`.

## Why

The results review on issue #2 (problems 1, 3 and 5) and the review of
the partial fix asked for: RE2 and Rust timed with capture extraction,
a between-run noise figure instead of the within-run spread alone, and
the php single-pattern share measured on the bench host. Problems 2, 4,
6 and 7 were settled from r1 in `2026-11-19-exp-11-r1-corrections.md`.

## Provenance

- Repository: bench clone at `11c2545`, clean, which has every harness
  fix since r1: capture extraction in RE2 and Rust (`465850a`),
  repetitions of at least 0.5 s (`5ea951c`), ocaml-re groups in worst
  mode (`5aabc3e`), pinned mtime and dune (`11c2545`). Binaries built as
  in `2026-11-19-exp-11-rebuild.md`; every sample of every run records
  repo commit `11c2545` and the same hash of the binaries (`9271570f…`).
  Analysis with `spread.py` as committed with this entry.
- Workloads: experiment 1 at `f64aa5feb6c3246cc614be1d329adadbb636779a`,
  committed sample, same prepared files as r1.
- Machine: the same bench host as r1 (AMD EPYC 7502P, Linux
  6.8.0-100-generic, Ubuntu 24.04.5 LTS), governor `schedutil`, boost on,
  nominal range 1.5-2.5 GHz; the samples show up to 3.34 GHz on CPU 4.
  No root.
- Runs: `run.sh rN all` (check, time, worst) under `nohup`, timing on
  `taskset -c 4`, check phase on `BUILD_CPUS` with 4 jobs. Each exited 0,
  no cell needed a repeat, every `.err` file is empty. The gate (CPUs
  4-7 and 36-39 under 10% busy over 5 s) passed before every column at
  0-1% busy.

  | run | start-end (UTC) | conditions |
  |---|---|---|
  | r2 | 15:24:40-15:48:18 | load average 0.4 at launch |
  | r3 | 16:03:33-16:27:10 | global load average up to 5.6 during the last column (ocaml-re) and the worst gate, timing complex still 0-1% busy |
  | r4 | 17:24:18-17:47:57 | experiment 12 was timing on another L3 complex (its binaries pinned to CPU 2, 16 MB subjects): the two runs may have shared memory bandwidth |

- Checks, 18:09-18:16 UTC, same binaries and pattern lists (the `only/`
  lists of r4), gate at 0% before each, each cell one process on
  `taskset -c 4`, search timing only (`E11_NO_COMPILE=1`) unless stated:
  - `php-share`: Oniguruma threaded on the whole php list, on pattern
    105 alone, and on the list without 105; every other column on
    pattern 105 alone and on its own list without 105, with Oniguruma
    threaded on the same lists.
  - `compile-first`: Oniguruma threaded and switch on the jq list, twice,
    each time with and without the compile timing before the search.
  - `nocompile`: the 30 own-column cells of `run.sh` (each engine on its
    own list) without compile timing, once.
- Run by Claude Code (Opus 5.5) in the experiment pipeline, 2026-11-19.

## Parameters

As in r1 (`2026-11-19-exp-11-throughput.md`), with the fixes above. In
r2-r4 every repetition of a cell with subject bytes lasted at least
0.5 s (shortest 0.49999 s, the rounding of the printed time per pass);
the only shorter repetitions are in the four cells with no subject byte
(RE2 and Rust on vscode-subst and their Oniguruma subsets), whose
minimum is 0 by design.

Statistics (from `spread.py --runs`, see its header):

- per run, the median of the 5 repetitions of a cell; the table gives
  the median over the three runs;
- `w`: the largest within-run IQR / median over the three runs;
- `b`: between-run spread, (max - min) / median of the three per-run
  medians;
- ratio: Oniguruma threaded time on the same pattern subset / engine
  time, computed run by run; the table gives the median and the range
  over the runs. A ratio counts as distinguishable from 1 when all three
  runs are on the same side of 1 and |ln ratio| exceeds the sum of the
  between-run spreads of the cell and of its reference.

## Raw data (summary)

Speed ratio vs Oniguruma threaded on the same subset, median (min-max
over r2-r4); MB/s; w; b. With captures in every column.

| engine | jq | php | php-legacy | vscode | vscode-subst |
|---|---:|---:|---:|---:|---:|
| onig-threaded | ×1.00 (1.00-1.00), 15 MB/s, w 0.4%, b 3.6% | ×1.00 (1.00-1.00), 0.33 MB/s, w 1.8%, b 0.7% | ×1.00 (1.00-1.00), 51 MB/s, w 0.3%, b 3.6% | ×1.00 (1.00-1.00), 38 MB/s, w 0.3%, b 0.1% | ×1.00 (1.00-1.00), 3 MB/s, w 0.2%, b 0.9% |
| onig-switch | ×0.94 (0.92-0.96), 14 MB/s, w 0.1%, b 2.0% | ×0.62 (0.59-0.62), 0.20 MB/s, w 0.5%, b 3.9% | ×0.91 (0.90-0.93), 46 MB/s, w 0.2%, b 0.8% | ×0.80 (0.79-0.80), 30 MB/s, w 0.3%, b 1.3% | ×0.76 (0.75-0.76), 2 MB/s, w 0.2%, b 0.3% |
| pcre2-interp | ×1.07 (1.06-1.08), 20 MB/s, w 0.4%, b 1.1% | ×0.23 (0.22-0.23), 0.07 MB/s, w 1.2%, b 2.1% | n/a | ×0.50 (0.50-0.50), 19 MB/s, w 0.1%, b 0.3% | ×0.41 (0.41-0.42), 1 MB/s, w 1.0%, b 1.1% |
| pcre2-jit | ×2.70 (2.69-2.73), 50 MB/s, w 0.1%, b 1.2% | ×2.83 (2.82-2.87), 0.86 MB/s, w 0.8%, b 2.4% | n/a | ×2.40 (2.36-2.40), 90 MB/s, w 0.5%, b 1.5% | ×2.55 (2.53-2.55), 7 MB/s, w 0.1%, b 0.5% |
| re2 | ×1.26 (1.26-1.29), 24 MB/s, w 0.4%, b 0.5% | ×284 (283-284), 53 MB/s, w 0.3%, b 0.4% | n/a | ×2.22 (2.21-2.22), 248 MB/s, w 0.2%, b 0.5% | no subject byte (422 patterns compile-timed only) |
| rust-regex | ×1.72 (1.72-1.72), 32 MB/s, w 1.8%, b 0.9% | ×211 (191-212), 58 MB/s, w 2.1%, b 9.9% | n/a | ×2.79 (2.71-2.80), 293 MB/s, w 0.6%, b 3.0% | no subject byte (429 patterns compile-timed only) |
| ocaml-re | ×1.53 (1.52-1.53), 29 MB/s, w 0.6%, b 5.0% | ×427 (406-446), 70 MB/s, w 0.5%, b 4.4% | n/a | ×1.22 (1.21-1.23), 157 MB/s, w 0.3%, b 1.3% | ×0.62 (0.61-0.63), 109 MB/s, w 0.8%, b 2.7% |

Every ratio is distinguishable from 1 by the rule above. The closest
are onig-switch jq (|ln 0.94| = 0.058 against a bound of 0.055) and
pcre2-interp jq (0.069 against 0.028).

The largest within-run range, (max - min) / median of the 5
repetitions, is 5.6% over the 138 cell-runs that have subject bytes
(onig-threaded@ocaml-re jq in r3, rust-regex php in r4); the cell with no
subject byte onig-threaded@re2 vscode-subst reaches 148% (it times an
empty loop). So no cell of r2-r4 crosses the 10% repeat threshold,
whether the threshold applies to IQR / median (as `run.sh` does) or to
the range: the open choice between the two (review of the partial fix,
problem 5) changes nothing in these runs.

Compile time, median over patterns of the per-pattern median over the
three runs (µs, number of patterns):

| engine | jq | php | php-legacy | vscode | vscode-subst |
|---|---:|---:|---:|---:|---:|
| onig-threaded | 0.8 (44) | 0.9 (106) | 0.9 (83) | 3.7 (3856) | 5.4 (1544) |
| onig-switch | 0.8 (44) | 0.9 (106) | 0.9 (83) | 3.6 (3856) | 5.3 (1544) |
| pcre2-interp | 0.5 (44) | 0.6 (102) | n/a | 2.0 (3823) | 2.7 (1525) |
| pcre2-jit | 7.2 (44) | 7.4 (102) | n/a | 15.1 (3823) | 17.2 (1525) |
| re2 | 2.6 (38) | 2.6 (79) | n/a | 6.0 (1684) | 4.1 (422) |
| rust-regex | 12.2 (41) | 10.6 (92) | n/a | 43.2 (1798) | 21.3 (429) |
| ocaml-re | 2.2 (37) | 2.2 (77) | n/a | 3.3 (1469) | 3.0 (438) |

These are 7-18% below r1's compile medians in every column, the same
drift as the search times (next section). 607 of the 28,858 patterns
have a between-run spread of their compile median above 10%.

## Capture cost in RE2 and Rust `regex` (problem 1)

r1 timed RE2 and Rust on the overall match only; r2-r4 extract every
capture group. Absolute times cannot be compared directly: every column
whose harness did not change runs 2-12% faster in r2-r4 than in r1 (7-12% for all but one cell), and
so do the Oniguruma subset cells (onig-threaded@engine: 5.5-10.2%
faster). The cause is not identified (new bench directory and rebuild,
longer repetitions, frequency). The ratio to Oniguruma on the same
subset in the same run cancels that drift, and the columns whose
harness did not change confirm it: their ratios move by a factor
0.97-1.01 (pcre2-jit, ocaml-re) or 0.97-1.07 (pcre2-interp).

Cost factor = r1 ratio (bounds only) / r2-r4 ratio (with groups):

| engine | workload | r1 ratio, bounds only | r2-r4 ratio, with groups | cost factor | engine time r1 → r2-r4 |
|---|---|---:|---:|---:|---|
| re2 | jq | ×1.42 | ×1.26 | 1.13 | 16.2 → 16.6 µs |
| re2 | php | ×403 | ×284 | 1.42 | 23.2 → 30.5 µs |
| re2 | vscode | ×2.58 | ×2.22 | 1.16 | 5.87 → 6.17 ms |
| rust-regex | jq | ×2.44 | ×1.72 | 1.42 | 10.4 → 13.4 µs |
| rust-regex | php | ×299 | ×211 | 1.42 | 30.8 → 40.7 µs |
| rust-regex | vscode | ×3.95 | ×2.79 | 1.41 | 4.15 → 5.40 ms |
| pcre2-jit (control) | jq / php / vscode | ×2.71 / ×2.86 / ×2.40 | ×2.70 / ×2.83 / ×2.40 | 1.00 / 1.01 / 1.00 | 9.9 → 9.0 µs, 3.49 → 3.19 ms, 46.4 → 42.1 ms |
| ocaml-re (control) | jq / php / vscode | ×1.50 / ×414 / ×1.23 | ×1.53 / ×427 / ×1.22 | 0.98 / 0.97 / 1.01 | 15.0 → 13.6 µs, 22.4 → 21.2 µs, 9.92 → 9.17 ms |

Extracting the groups costs RE2 13-16% on jq and vscode and 42% on php,
and Rust `regex` about 41-42% on all three. The comparable figures are
now RE2 ×1.26 / ×284 / ×2.22 and Rust ×1.72 / ×211 / ×2.79 on jq / php /
vscode; they replace r1's group-0 figures. Groups do not change the
overall matches: every check output of r2-r4 equals r1's apart from its
`PASS` duration line (see `2026-11-19-exp-11-rerun-agreement.md`).

## Between-run noise (problem 3)

- Between-run spread of the per-run medians: at most 1.5% for 16 of the
  28 engine cells with subject bytes. The largest are rust-regex php 9.9% (r3 at 44.5 µs
  against 40.7 µs in r2 and r4), ocaml-re jq 5.0%, ocaml-re php 4.4% (and 9.0%
  for its Oniguruma subset cell, r2 at 9.48 ms against 8.69-8.75 ms),
  onig-switch php 3.9%, onig-threaded jq and php-legacy 3.6%.
- The ratios vary less than the cells, since a cell and its reference
  share the run: the range of the three per-run ratios of a cell is at
  most 5% of their median, except rust-regex php (191-212, 10%) and
  ocaml-re php (406-446, 9%).
- The within-run IQR / median (`w`, at most 2.1%) understates this
  noise: claims about ratios should use the between-run figures above,
  not `w`.
- The r1 corrections note concluded that ratios within ±5% of 1 were
  noise, from cells of r1 that timed the same work twice. Most of that
  4% difference was the systematic effect below, not run-to-run noise.

## Compile timing before the search slows Oniguruma's search (new)

In r2-r4, the same work (Oniguruma threaded, the 44 jq patterns, 450
bytes and 64 calls per pass) takes 29.0-30.1 µs per pass in the
onig-threaded column and 24.2-24.6 µs in the onig-threaded@pcre2-interp
and @pcre2-jit cells of the same runs, 20% apart. The difference between
the cells: in its own column, a harness first times the compilation of
every pattern (at least 1000 compilations each) in the same process,
then times the search; the subset cells skip the compile timing
(`E11_NO_COMPILE=1`).

The `compile-first` check isolates it (median per pass, jq list):

| build | with compile timing first | without |
|---|---|---|
| onig-threaded | 25.4 µs, 29.4 µs | 24.6 µs, 24.4 µs |
| onig-switch | 31.3 µs, 31.1 µs | 25.8 µs, 26.0 µs |

and the `nocompile` check gives the size of the effect on every own
cell (median of r2-r4 with compile timing first / single run without):

| engine | jq | php | php-legacy | vscode | vscode-subst |
|---|---:|---:|---:|---:|---:|
| onig-threaded | +20.2% | +0.3% | +8.6% | -3.4% | +1.6% |
| onig-switch | +20.6% | -2.1% | +9.6% | +1.9% | +0.0% |
| pcre2-interp | -1.1% | +0.9% | n/a | -0.6% | +0.3% |
| pcre2-jit | +0.9% | +0.2% | n/a | -0.5% | -0.1% |
| re2 | -0.1% | -1.0% | n/a | -0.1% | no byte |
| rust-regex | -1.0% | -10.6% | n/a | +1.2% | no byte |
| ocaml-re | -0.5% | -0.3% | n/a | -0.1% | +0.4% |

The effect is specific to Oniguruma on the small workloads (jq +20%,
php-legacy +9 to +10%), and it can switch on and off between processes
(25.4 then 29.4 µs above). The rust-regex php -10.6% is within that
cell's 9.9% between-run spread. The mechanism is not identified (heap
state left by the compile loop is a candidate).

Consequences:

- The ratios of PCRE2, RE2, Rust and ocaml-re are not affected: they
  divide an Oniguruma subset cell (no compile timing) by an engine cell
  that the effect does not touch.
- Oniguruma's own absolute figures on jq and php-legacy (15 and 51 MB/s
  above) are about 20% and 9% low.
- The dispatch ratio compares two own cells, both affected. Without
  compile timing (one run) it is jq ×0.94, php ×0.60, php-legacy ×0.91,
  vscode ×0.84, vscode-subst ×0.74, against ×0.94, ×0.62, ×0.91, ×0.80,
  ×0.76 in r2-r4. r1's jq ×0.79 (switch 35.0 µs, threaded 27.8 µs) is
  not reproduced in either setting; given the on/off behaviour above, it
  is most likely the same effect hitting only the switch cell.
- A harness change would remove it (time the search in a process that
  has not run the compile loop, for example by timing compilation in a
  separate invocation). It is not applied here: it changes the protocol
  and needs a new series of runs.

## php single-pattern share (problem 5)

php pattern 105, `A(B|C+)+D|AC+X` on its 21-byte subject (PHP's own
backtracking test), measured on the bench host (`php-share` check, one
run, search only):

| cell | median pass | share of the full pass |
|---|---:|---:|
| onig-threaded, all 106 patterns | 9.02 ms | 100% |
| onig-threaded, pattern 105 alone | 8.14 ms | 90.3% |
| onig-threaded, the 105 other patterns | 0.074 ms | 0.8% |

Within the full pass, pattern 105 takes 99.2% of the time (full minus
the others). Alone it runs 9% faster than inside the pass (8.14 ms
against 8.95 ms; not explained), so its share is 90-99%, not "about 70%"
as the r1 throughput entry said from a workstation measurement.

Speed ratios against Oniguruma threaded, on pattern 105 alone and on
each engine's php list without it:

| engine | pattern 105 alone | php without 105 |
|---|---:|---:|
| onig-switch | ×0.56 | ×0.93 |
| pcre2-interp | ×0.21 | ×0.86 |
| pcre2-jit | ×2.55 | ×2.89 |
| re2 | ×4573 | ×1.15 |
| rust-regex | ×6812 | ×1.52 |
| ocaml-re | ×11030 | ×1.51 |

So the ×211-427 php ratios of the automaton engines come entirely from
pattern 105: on the rest of php they are ×1.15-1.52, the same order as
on jq. These are single-run figures; php cells have between-run spreads
of up to 4% (10% for rust-regex).

Micro-workloads: a jq pass is 450 bytes in 64 calls, a php-legacy pass
737 bytes in 86 calls, and php without pattern 105 is 2,972 bytes in
133 calls taking 74 µs, about 0.55 µs per call. These columns measure
the cost of a call, not matching speed. Only vscode (3,816,964 bytes per
pass) and, to a lesser extent, vscode-subst (288,411 bytes) measure
throughput.

## Analysis and open questions

- Review problems: 1 (RE2 and Rust with captures) and 3 (between-run
  noise) are now measured; 4 is confirmed fixed (every repetition with
  subject bytes lasted at least 0.5 s); 5 is closed (micro-workload
  reading above, php share measured on the bench host). The capture
  part of the partial-fix review (problem 2) is settled: rebuild
  recorded, check outputs and pattern lists unchanged, cost measured.
- Results that hold over r1-r4: PCRE2 JIT ×2.4-2.8 faster than
  Oniguruma on every workload; PCRE2 interpreter ×0.50 on vscode; on the
  under-half of vscode patterns they accept, RE2 ×2.2, Rust ×2.8 (with
  groups) and ocaml-re ×1.2.
- Dispatch (for experiment 10): the switch build runs at 0.74-0.84 of
  direct-threaded speed on vscode and vscode-subst, 0.60-0.62 on php
  (pattern 105) and 0.91-0.94 on the micro-workloads jq and php-legacy.
  The r1 summary's "0.79 on jq" is withdrawn.
- Open, needs a decision: the compile-first effect (harness change and
  a new series, or keep the protocol and state the bias); the 10%
  repeat rule (IQR or range; no effect on r2-r4).
- Open, not decided here: the cause of the 2-12% drift between r1 and
  r2-r4; why pattern 105 alone is 9% faster than in the pass; still
  open from the reviews: PCRE2 with `PCRE2_NO_UTF_CHECK` on valid
  subjects, the complete VS Code set, a regset row.
