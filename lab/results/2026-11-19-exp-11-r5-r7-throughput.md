# exp-11 r5-r7: compilation timed separately, throughput and comparison with r2-r4

## What

Analysis of the three runs r5, r6 and r7, the first series made with
compilation timed in a process of its own
(`2026-11-19-exp-11-compile-separate.md`). This entry gives the
three-run throughput table, the compile medians and the worst case, then
compares the series with r2-r4: whether the compile-timing bias is gone,
the dispatch ratio for experiment 10, and the ratios that moved by more
than the noise.

Files:

- per run: `2026-11-19-exp-11-rN-raw-times.tsv` (every C, W, T and S
  line; the C lines come from the `compile` processes),
  `-rN-provenance.txt`, `-rN-run.log`, `-rN-agreement.csv`,
  `-rN-disagreements.csv`, `-rN-worst-case.csv` and `-rN-outputs.tar.xz`
  (the whole run directory: check, only, time, compile and worst);
- across runs: `2026-11-19-exp-11-r5-r7-throughput.csv`
  (`spread.py --runs`, one row per engine and workload),
  `-r5-r7-compile.csv` (`spread.py --compile`, one row per pattern) and
  `-r5-r7-worst-case.csv` (`spread.py --worst`, one row per point).

## Why

Maintainer decisions on issue #2 after the review of r2-r4: time
compilation in a separate process from the search and make a new series
of three runs; repeat a cell when its range, (max - min) / median of
the 5 repetitions, exceeds 10%.

## Provenance

- Repository: bench clone at `1d1fa5f`, clean. Every sample of every run
  records repo commit `1d1fa5f` and bin_sha256 `29bcfd83…a52e`. That is
  the hash `provenance.sh` computes from the per-binary sha256 list of
  `2026-11-19-exp-11-compile-separate.md` (recomputed here from that
  list), so the binaries timed are those of that rebuild. Analysis with
  `spread.py` as committed at `1d1fa5f`.
- Workloads: experiment 1 at `f64aa5feb6c3246cc614be1d329adadbb636779a`,
  same prepared files as r1-r4.
- Machine: the same bench host and bench directory as r2-r4 (AMD EPYC
  7502P, Linux 6.8.0-100-generic, Ubuntu 24.04.5 LTS), governor
  `schedutil`, boost on; the samples show up to 3.35 GHz on CPU 4. No
  root.
- Runs: `run.sh rN all` (check, then time with a `compile` process after
  the search of each own cell, then worst) under `setsid nohup`, timing
  on `taskset -c 4`, check phase on `BUILD_CPUS` with 4 jobs. Each exited
  0 and every `.err` file is empty. The gate (CPUs 4-7 and 36-39 under
  10% busy over 5 s) passed before every column at 0-1% busy.

  | run | start-end (UTC) | conditions |
  |---|---|---|
  | r5 | 20:06:59-20:30:50 | global load average 5.6-7.2, from experiment 13's jobs pinned to CPUs 16-19 and 28-31; 16-19 are also `BUILD_CPUS`, which only the untimed check phase uses |
  | r6 | 20:57:45-21:21:38 | load average 0.9-6.8, same kind of experiment 13 jobs; one repeat (rust-regex php, range 10.3%) |
  | r7 | 21:25:20-21:49:08 | load average 0.1-1.6, no process with a restricted affinity on the host |

- Run by Claude Code (Opus 5.5) in the experiment pipeline, 2026-11-19.

## Parameters

As in r2-r4 (`2026-11-19-exp-11-rerun-throughput.md`), except the two
decisions above. Statistics from `spread.py --runs` (see its header):

- per run, the median of the 5 repetitions of a cell; the table gives
  the median over the three runs;
- `r`: the largest within-run range, (max - min) / median, over the
  three runs (the repeat rule now uses it);
- `b`: between-run spread, (max - min) / median of the three per-run
  medians;
- ratio: Oniguruma threaded time on the same pattern subset / engine
  time, computed run by run; median and range over the runs. A ratio is
  distinguishable from 1 when the three runs are on the same side of 1
  and |ln ratio| exceeds the sum of the between-run spreads of the cell
  and of its reference.

## Raw data (summary)

Speed ratio vs Oniguruma threaded on the same subset, median (min-max
over r5-r7); MB/s; r; b. With captures in every column.

| engine | jq | php | php-legacy | vscode | vscode-subst |
|---|---:|---:|---:|---:|---:|
| onig-threaded | ×1.00, 18 MB/s, r 2.4%, b 0.3% | ×1.00, 0.33 MB/s, r 1.4%, b 0.7% | ×1.00, 54 MB/s, r 2.1%, b 0.8% | ×1.00, 37 MB/s, r 0.7%, b 0.7% | ×1.00, 2.7 MB/s, r 0.4%, b 0.2% |
| onig-switch | ×0.98 (0.97-0.98), 17 MB/s, r 2.3%, b 1.4% | ×0.62 (0.62-0.63), 0.21 MB/s, r 1.2%, b 1.4% | ×0.92 (0.92-0.93), 50 MB/s, r 0.8%, b 0.5% | ×0.85 (0.85-0.86), 31 MB/s, r 0.7%, b 0.8% | ×0.75 (0.75-0.75), 2.0 MB/s, r 1.4%, b 1.0% |
| pcre2-interp | ×1.06 (1.06-1.08), 19 MB/s, r 2.5%, b 0.8% | ×0.23 (0.23-0.24), 0.07 MB/s, r 1.1%, b 2.5% | n/a | ×0.49 (0.48-0.50), 18 MB/s, r 0.6%, b 2.6% | ×0.40 (0.39-0.40), 1.1 MB/s, r 1.4%, b 1.4% |
| pcre2-jit | ×2.80 (2.79-2.86), 50 MB/s, r 1.9%, b 2.5% | ×2.78 (2.77-2.82), 0.87 MB/s, r 2.5%, b 1.5% | n/a | ×2.41 (2.40-2.41), 90 MB/s, r 0.5%, b 0.4% | ×2.52 (2.52-2.56), 6.8 MB/s, r 0.7%, b 1.0% |
| re2 | ×1.31 (1.31-1.32), 24 MB/s, r 2.6%, b 0.8% | ×281 (279-293), 52 MB/s, r 3.0%, b 2.5% | n/a | ×2.32 (2.32-2.32), 258 MB/s, r 0.4%, b 0.1% | no subject byte (422 patterns compile-timed only) |
| rust-regex | ×1.81 (1.80-1.81), 32 MB/s, r 2.2%, b 0.6% | ×201 (199-215), 56 MB/s, r 9.6%, b 3.6% | n/a | ×2.84 (2.83-2.85), 295 MB/s, r 1.2%, b 0.5% | no subject byte (429 patterns compile-timed only) |
| ocaml-re | ×1.52 (1.46-1.53), 28 MB/s, r 4.2%, b 5.4% | ×407 (399-409), 71 MB/s, r 3.9%, b 2.2% | n/a | ×1.24 (1.23-1.26), 159 MB/s, r 0.7%, b 1.8% | ×0.61 (0.61-0.62), 107 MB/s, r 2.1%, b 0.5% |

- Every ratio is distinguishable from 1 by the rule above. The closest
  are onig-switch jq (|ln 0.976| = 0.025 against a bound of 0.017) and
  pcre2-interp jq (0.059 against 0.027). All the others clear their
  bound by a factor of 6.5 or more.
- Repeat rule: one cell-run crossed 10%, rust-regex php in r6 (range
  10.27%). Its repeat has a range of 9.6% and replaces it, as the rule
  says. Every other cell-run with subject bytes, subset cells included,
  has a range under 10%: 8.9% for onig-threaded@re2 php in r5, 8.8% for
  rust-regex php in r7, and at most 4.2% for all the others. The two cells with no subject byte (RE2 and Rust on
  vscode-subst) time an empty pass and are never repeated.

Compile time, median over patterns of the per-pattern median over the
three runs (µs, number of patterns), from `-r5-r7-compile.csv`:

| engine | jq | php | php-legacy | vscode | vscode-subst |
|---|---:|---:|---:|---:|---:|
| onig-threaded | 0.85 (44) | 0.93 (106) | 0.91 (83) | 3.78 (3856) | 5.52 (1544) |
| onig-switch | 0.78 (44) | 0.86 (106) | 0.87 (83) | 3.56 (3856) | 5.34 (1544) |
| pcre2-interp | 0.46 (44) | 0.55 (102) | n/a | 1.99 (3823) | 2.67 (1525) |
| pcre2-jit | 7.27 (44) | 7.48 (102) | n/a | 15.3 (3823) | 18.0 (1525) |
| re2 | 2.57 (38) | 2.60 (79) | n/a | 6.01 (1684) | 4.11 (422) |
| rust-regex | 12.2 (41) | 11.1 (92) | n/a | 48.6 (1798) | 21.8 (429) |
| ocaml-re | 2.19 (37) | 2.23 (77) | n/a | 3.30 (1469) | 3.02 (438) |

Every pattern was compiled in all three runs. 273 of the 28,858
patterns have a between-run spread of their compile median above 10%
(607 in r2-r4).

Worst case (`-r5-r7-worst-case.csv`): all 189 points have the same
outcome and return code in r5, r6 and r7, and the same as in r2-r4
(and so r1). No point reached the 60 s cap. Median over the three runs:

| engine | jq `(a+)+$` | php `(a\|aa)+$` | vscode `(\w+\s?)+$` |
|---|---|---|---|
| onig-threaded | n=16 no match 2.8 ms; n≥32 −17 after 0.133-0.143 s | n=16 0.2 ms; n≥32 −17 after 0.086-0.088 s | n=16 4.4 ms; n≥32 −17 after 0.110-0.111 s |
| onig-switch | n≥32 −17 after 0.21 s | n≥32 −17 after 0.15 s | n≥32 −17 after 0.16 s |
| pcre2-interp | n≥32 −47 after 0.21 s | n≥32 −47 after 0.21 s | n≥32 −47 after 0.29 s |
| pcre2-jit | n≥32 −47 after 0.028 s | n=32 no match 0.090 s; n=64-512 −47 after 0.037 s; n≥1024 −46 at once | n≥32 −47 after 0.037 s |
| re2 | 10-16 µs | 11-16 µs | 9-15 µs |
| rust-regex | 5-10 µs | 5-9 µs | 13-20 µs |
| ocaml-re | 22-35 µs | 40-51 µs | 26-38 µs |

Between runs, the points of 1 ms or more vary by at most 8.3% of their
median (onig-threaded jq n = 128). Against the r2-r4 medians they move
by -6.8% to +4.4%: onig-switch jq is 5.5-6.8% faster, pcre2-interp jq
4.4-5.8% faster, onig-threaded jq 0.6-4.9% faster, onig-threaded php
2.4-4.4% slower, everything else within ±3%.

Agreement: every `agreement.csv` equals r4's apart from its last column
(`one_pass_seconds`, a timing), and every `disagreements.csv` and `only/`
pattern list is byte-identical to r4's.

## The compile-timing bias is gone

jq is the only workload where an own cell of Oniguruma threaded and an
Oniguruma subset cell time exactly the same work: the pcre2-interp and
pcre2-jit jq lists are the 44 patterns of onig-threaded's own list
(same `only/` files, same `included_patterns`, bytes and matches per
pass). Per run, median pass:

| run | onig-threaded jq (own cell) | onig-threaded@pcre2-interp jq | @pcre2-jit jq | own / subset |
|---|---:|---:|---:|---:|
| r2 | 30.08 µs | 24.29 µs | 24.42 µs | 1.239, 1.232 |
| r3 | 29.04 µs | 24.62 µs | 24.60 µs | 1.179, 1.181 |
| r4 | 29.21 µs | 24.22 µs | 24.54 µs | 1.206, 1.190 |
| r5 | 25.49 µs | 25.39 µs | 25.42 µs | 1.004, 1.003 |
| r6 | 25.48 µs | 25.75 µs | 25.34 µs | 0.989, 1.006 |
| r7 | 25.55 µs | 25.28 µs | 25.39 µs | 1.010, 1.006 |

The 18-24% excess of the own cell is gone: own and subset now agree
within 1.1%, inside the between-run spread of the @pcre2-interp cell
(1.9%).

The other workloads have no identical subset cell. There, the own cells
of r5-r7 match the `nocompile` check of r2-r4 (search only, one run, the
r2-r4 binaries), not the r2-r4 runs (compile timing first):

| cell | r2-r4, compile first | `nocompile` check | r5-r7 | r5-r7 / `nocompile` |
|---|---:|---:|---:|---:|
| onig-threaded jq | 29.21 µs | 24.31 µs | 25.49 µs | +4.9% |
| onig-threaded php-legacy | 14.43 µs | 13.29 µs | 13.54 µs | +1.9% |
| onig-threaded vscode | 100.93 ms | 104.52 ms | 104.53 ms | +0.0% |
| onig-switch jq | 31.22 µs | 25.88 µs | 26.12 µs | +0.9% |
| onig-switch php-legacy | 15.96 µs | 14.57 µs | 14.66 µs | +0.6% |
| onig-switch vscode | 126.52 ms | 124.20 ms | 122.23 ms | -1.6% |

The compile-first effect was +20% on jq, +9% on php-legacy, and -3.4%
on onig-threaded vscode (the compile loop made that cell faster). All
three are gone. The remaining +4.9% on onig-threaded jq is the drift of
every Oniguruma jq cell between the two series (next section), not the
compile effect: the subset cells, which never had compile timing, moved
by the same amount.

## Comparison with r2-r4

### Absolute times: a 4% drift on Oniguruma's jq cells

The Oniguruma subset cells (onig-threaded@engine), whose protocol did
not change, are 3.5-4.6% slower on jq in r5-r7 than in r2-r4 (all five,
ranges disjoint), and within -2.4% to +1.7% on the other workloads.
pcre2-interp jq (+4.8%) and ocaml-re jq (+3.8%) moved the same way;
pcre2-jit, re2 and rust-regex jq did not (within ±0.5%). The cause is
not identified. Candidates, none tested: every harness was relinked for
the new protocol (the engine libraries are unchanged; `time` now runs
through a new `setup` function), which can change code layout in a
workload of 64 calls per pass; and a different session (time of day,
other experiments on the host). Since the ratios divide by an Oniguruma
subset cell, this drift moves the jq ratios of RE2 and Rust (below).

### Dispatch ratio for experiment 10

Speed of the switch build relative to the direct-threaded build
(onig-threaded time / onig-switch time, both own cells), median (min-max
over the runs):

| workload | r5-r7 | r2-r4 (compile first) | `nocompile` check (one run) |
|---|---:|---:|---:|
| jq | 0.976 (0.966-0.981) | 0.944 (0.920-0.964) | 0.939 |
| php | 0.622 (0.621-0.630) | 0.617 (0.592-0.619) | 0.601 |
| php-legacy | 0.920 (0.919-0.928) | 0.906 (0.904-0.932) | 0.912 |
| vscode | 0.854 (0.848-0.861) | 0.798 (0.793-0.803) | 0.842 |
| vscode-subst | 0.749 (0.746-0.752) | 0.756 (0.751-0.756) | 0.744 |

For experiment 10: with compilation out of the search process, the
switch build runs at 0.85 of direct-threaded speed on vscode, the main
throughput workload, and at 0.75 on vscode-subst. On php, which is
pattern 105's backtracking, it runs at 0.62. On the call-bound
micro-workloads it runs at 0.92 (php-legacy) and 0.98 (jq). The jq figure
is distinguishable from 1 within the series, but only narrowly (bound
0.017 against 0.025), and is smaller than the 3-7% between-session
variation found in `2026-11-19-exp-11-rerun-review-fixes.md`: read it as
"at most a few percent slower". The vscode figure moves from r2-r4's
0.80 to 0.85, because r2-r4 had the compile-first effect on both cells
in opposite directions (threaded -3.4%, switch +1.9%). It agrees with
the `nocompile` check (0.84). The r1 figures of 0.74-0.80 on real
workloads and 0.79 on jq are superseded.

### Ratios that moved by more than the noise

Rule: a ratio moved when its per-run ranges in r2-r4 and r5-r7 are
disjoint and |ln (r5-r7 median / r2-r4 median)| exceeds the sum of the
two series' bounds (the bound of the rule above, computed in each
series). Four ratios pass:

| cell | r2-r4 | r5-r7 | move | bounds (r2-r4 + r5-r7) | where the move is |
|---|---:|---:|---:|---:|---|
| onig-switch vscode | ×0.798 (0.793-0.803) | ×0.854 (0.848-0.861) | +7.1% | 0.015 + 0.016 | both cells: the compile-first effect removed (above) |
| rust-regex jq | ×1.72 (1.72-1.72) | ×1.81 (1.80-1.81) | +5.3% | 0.018 + 0.009 | reference +4.5%, engine -0.5% |
| re2 vscode | ×2.22 (2.21-2.22) | ×2.32 (2.32-2.32) | +4.5% | 0.013 + 0.003 | engine -3.7% (6.17 to 5.94 ms), reference +0.5% |
| re2 jq | ×1.26 (1.26-1.29) | ×1.31 (1.31-1.32) | +4.1% | 0.025 + 0.013 | reference +4.6%, engine +0.3%; passes narrowly (0.040 against 0.038) |

Seven more have disjoint ranges but a move under the bound: onig-switch
jq +3.3%, onig-switch php +0.9%, pcre2-jit jq +3.5%, pcre2-interp
vscode-subst -4.0%, pcre2-interp php +2.7%, ocaml-re vscode +2.0%,
rust-regex vscode +1.9%. The other 12 of the 23 ratios have overlapping
ranges.

Apart from onig-switch vscode, which the protocol change explains, the
moves are 4-5%, inside the 3-7% between-session variation of the review
fixes. The rust-regex and re2 jq moves come from the Oniguruma jq drift
above, not from the engines. re2 vscode is the only engine cell that
moved by more than its noise on its own (RE2's library is unchanged;
only its harness was relinked).

The results that hold over r1-r7: PCRE2 JIT ×2.4-2.8 faster than
Oniguruma on every workload; PCRE2 interpreter ×0.49 on vscode and ×0.40
on vscode-subst; on the under-half of vscode patterns they accept, RE2
×2.2-2.3, Rust ×2.8 (with groups) and ocaml-re ×1.2.

### Compile times

Compiling in a separate process, after the search, does not change the
compile medians: every engine and workload is within ±2.8% of r2-r4,
computed the same way from `2026-11-19-exp-11-rerun-compile.csv`. The
largest moves are onig-switch vscode -2.8% and onig-threaded jq +2.7%.

Correction to `2026-11-19-exp-11-rerun-throughput.md`: its compile
table does not reproduce from `2026-11-19-exp-11-rerun-compile.csv` in
the cells that contain per-pattern medians of 1 ms or more. Those are
written in exponent form (`%.6g`, for example `1.23457e+06`), and a
locale-dependent numeric sort reads them as small numbers. Recomputed
from the CSV, the r2-r4 values are onig-threaded vscode 3.78 and
vscode-subst 5.53 µs (not 3.7 and 5.4), onig-switch vscode 3.66 and
vscode-subst 5.44 (not 3.6 and 5.3), pcre2-jit vscode 15.2 and
vscode-subst 17.8 (not 15.1 and 17.2), rust-regex php 11.2, vscode
48.8 and vscode-subst 21.8 (not 10.6, 43.2 and 21.3). The other cells
agree with that table to its rounding. Its count of 607 patterns with a
spread above 10% is right. Its sentence "7-18% below r1's compile
medians" was not rechecked.

## Analysis and open questions

- The maintainer's decision 1 did what it was meant to do: the own
  Oniguruma cells now time the same as the subset cells on identical
  work (within 1.1%), and the jq and php-legacy figures lose their
  20% and 9% handicap. Decision 2 (range rule) triggered one repeat in
  three runs, on the cell with the largest r2-r4 between-run spread.
- Dispatch for experiment 10: 0.85 on vscode, 0.75 on vscode-subst, 0.62
  on php, 0.92 on php-legacy, 0.98 on jq. These replace the r2-r4 figures
  and r1's.
- Ratios against Oniguruma: unchanged within the between-session noise,
  except re2 vscode (×2.32 instead of ×2.22, engine 3.7% faster) and the
  jq ratios of RE2 and Rust (×1.31 and ×1.81 instead of ×1.26 and ×1.72),
  which follow a 4% slowdown of every Oniguruma jq cell.
- Open, not decided here: the cause of the 4% Oniguruma jq drift between
  r2-r4 and r5-r7 (relink of the harnesses or session); still open from
  earlier entries: the r1 to r2-r4 drift, why php pattern 105 alone is
  9% faster than in the pass, PCRE2 with `PCRE2_NO_UTF_CHECK`, the
  complete VS Code set, a regset row.
- The r2-r4 output archives committed with `98047cc` record a
  user name as the owner of every entry (tar headers).
  The r6 and r7 archives were repacked with numeric owner 0 before
  this commit, with the same content; r5's already had it. The r2-r4
  archives are left as they are (results are append-only); the
  maintainer may want them rewritten.
