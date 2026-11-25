# exp-11 throughput: compile time and search speed, seven columns × five workloads

## What

Compile time per pattern and whole-workload search throughput of
Oniguruma `f95747b` (direct-threaded and switch builds), PCRE2 10.49
(interpreter and JIT), RE2 2025-11-05, Rust `regex` 1.13.2 and ocaml-re
1.14.0 on #1's workloads, each engine on the patterns it accepts and
agrees on (see `2026-11-19-exp-11-agreement.md`), and Oniguruma threaded
re-timed on each engine's subset so that every ratio compares the same
work. Raw data: `2026-11-19-exp-11-throughput.csv` (one row per cell),
`2026-11-19-exp-11-compile.csv` (per-pattern compile medians),
`2026-11-19-exp-11-provenance.txt` (run conditions and per-column
samples).

## Why

Criteria 2 and 5 of issue #2: fixed speed targets for #10, #12 and the
final implementation, and the dispatch number for #10 (switch vs
direct-threaded on the same workloads).

## Provenance

- Repository: branch `exp/11-perf-baselines`; harness binaries as built
  in `2026-11-19-exp-11-builds.md` (`ed41cf0`); `run.sh` at `0362044`
  (gate change, see below); `summarise.py` as committed with this entry.
- Workloads: #1 at `f64aa5feb6c3246cc614be1d329adadbb636779a`, committed sample.
- Machine: the bench host, AMD EPYC 7502P 32-Core Processor,
  Linux 6.8.0-100-generic, Ubuntu 24.04.5 LTS; governor `schedutil`,
  boost on, scaling and cpuinfo range 1.5-2.5 GHz (boost reached about
  3.0 GHz in the samples). No root (Decision 3).
- Compilers and flags: GCC/G++ 13.3.0 `-O3 -DNDEBUG`; rustc 1.100.0
  `--release`; OCaml 5.5.2 `dune --release`, `-unsafe -inline 200`.
- Pinning: `taskset -c 4`, one timed process at a time. Experiment #3's
  fuzzers shared the host (about 40-48 processes pinned to CPUs 8-31,40-63;
  global load average 26-50 during the run). Before each column the gate
  required CPUs 4-7 and 36-39 (timing CPU, SMT sibling, rest of its L3
  complex) under 10% busy over 5 s: measured 0-6%. `/proc/stat`
  counters of those CPUs and `scaling_cur_freq` of CPU 4 are sampled
  before and after each column in the provenance file.
- Command: `run.sh r1 time`, 2026-11-19 12:16-12:40 UTC (bench host
  clock), exit 0. Run by Claude Code (Opus 5.5) in the experiment pipeline.

## Parameters

- Compile: each pattern compiled repeatedly until at least 1000
  compilations and 10 ms, cap 1 s; per-pattern median; the N actually
  used is in the compile CSV. PCRE2 JIT compile time includes
  `pcre2_jit_compile`; the time of freeing is excluded.
- Search: one untimed warm-up pass, then 5 timed repetitions, each of
  `passes_per_rep` whole passes so that a repetition lasts at least
  0.5 s. A pass runs every (pattern, subject) pair once, enumerating all
  non-overlapping matches from offset 0 with the shared loop. bytes/s =
  subject bytes per pass / median pass time; spread = IQR / median of the
  5 repetition times. Spread rule: a cell over 10% is repeated once, then
  marked invalid. Inside the timed region: the searches only (match data
  and regions are allocated once per pattern).
- Deviation from the plan: the gate "load average ≤ 2" could not be met
  on a host shared with #3's fuzzers; it was replaced by the idle check of
  the timing CPU's L3 complex above (commit `0362044`). A first time
  phase started under the old gate was stopped after three small cells
  and discarded. Paths on the bench host follow the pipeline's
  `~/maquizcoatl-work/exp/11-perf-baselines/`.

## Raw data (summary)

Speed ratio vs Oniguruma threaded on the same pattern subset (>1: faster); indicative MB/s; spread; * invalid (spread > 10%)

| engine | jq | php | php-legacy | vscode | vscode-subst |
|---|---:|---:|---:|---:|---:|
| onig-threaded | ×1.00, 16 MB/s, 0.0% | ×1.00, 0.31 MB/s, 0.1% | ×1.00, 45 MB/s, 0.2% | ×1.00, 33 MB/s, 0.0% | ×1.00, 2 MB/s, 1.0% |
| onig-switch | ×0.79, 13 MB/s, 0.1% | ×0.60, 0.18 MB/s, 1.5% | ×0.92, 42 MB/s, 0.4% | ×0.80, 27 MB/s, 0.7% | ×0.74, 2 MB/s, 0.4% |
| pcre2-interp | ×1.04, 18 MB/s, 0.8% | ×0.22, 0.06 MB/s, 0.4% | n/a | ×0.52, 17 MB/s, 0.1% | ×0.44, 1 MB/s, 0.1% |
| pcre2-jit | ×2.71, 45 MB/s, 0.4% | ×2.86, 0.79 MB/s, 0.3% | n/a | ×2.40, 82 MB/s, 0.3% | ×2.56, 6 MB/s, 0.9% |
| re2 | ×1.42, 25 MB/s, 0.9% | ×402.53, 70 MB/s, 0.3% | n/a | ×2.58, 261 MB/s, 0.4% | no pair (422 patterns compile-timed only) |
| rust-regex | ×2.44, 41 MB/s, 0.3% | ×299.15, 77 MB/s, 0.5% | n/a | ×3.95, 382 MB/s, 0.8% | no pair (429 patterns compile-timed only) |
| ocaml-re | ×1.50, 26 MB/s, 1.6% | ×413.80, 67 MB/s, 0.5% | n/a | ×1.23, 145 MB/s, 1.2% | ×0.62, 98 MB/s, 0.1% |

Compile time, median over patterns of the per-pattern median (µs)

| engine | jq | php | php-legacy | vscode | vscode-subst |
|---|---:|---:|---:|---:|---:|
| onig-threaded | 0.9 (44) | 1.0 (106) | 1.0 (83) | 4.1 (3856) | 6.0 (1544) |
| onig-switch | 0.9 (44) | 1.0 (106) | 1.0 (83) | 4.0 (3856) | 5.9 (1544) |
| pcre2-interp | 0.5 (44) | 0.6 (102) | n/a | 2.2 (3823) | 2.9 (1525) |
| pcre2-jit | 8.0 (44) | 8.1 (102) | n/a | 16.7 (3823) | 19.5 (1525) |
| re2 | 3.1 (38) | 2.9 (79) | n/a | 6.6 (1684) | 4.5 (422) |
| rust-regex | 13.4 (41) | 12.2 (92) | n/a | 52.6 (1798) | 23.0 (429) |
| ocaml-re | 2.4 (37) | 2.5 (77) | n/a | 3.8 (1469) | 3.4 (438) |

Each cell: speed ratio (Oniguruma threaded time on the same pattern
subset / engine time; > 1 means faster than Oniguruma), indicative
absolute throughput, spread. Every cell had a spread under 10% on its
first run (largest 1.6%); no repeat was needed and no cell is invalid.

Selected absolute values (median pass time, timed patterns):

| cell | patterns | bytes/pass | median pass | Oniguruma on same subset |
|---|---:|---:|---:|---:|
| onig-threaded vscode | 3856 | 3,816,964 | 114.3 ms | – |
| onig-switch vscode | 3856 | 3,816,964 | 142.8 ms | 114.3 ms |
| pcre2-jit vscode | 3823 | 3,802,934 | 46.4 ms | 111.6 ms |
| re2 vscode | 1684 | 1,531,171 | 5.87 ms | 15.1 ms |
| rust-regex vscode | 1798 | 1,584,022 | 4.15 ms | 16.4 ms |
| ocaml-re vscode | 1469 | 1,442,726 | 9.92 ms | 12.2 ms |
| onig-threaded php | 106 | 2,993 | 9.75 ms | – |

## Analysis and open questions

- **Dispatch (for #10).** Direct threading pays: the switch build runs at
  0.79-0.80 of the threaded speed on jq and vscode, 0.74 on vscode-subst,
  0.60 on php (dominated by backtracking, see below) and 0.92 on the
  legacy-encoding rows. Compile times are identical (as expected: only
  `regexec.c` differs). The same ratio shows in the worst-case runs
  (time to reach the retry limit: 0.23 s vs 0.15 s).
- **Targets on real (TextMate) patterns.** On the vscode workload
  Oniguruma threaded runs at 33 MB/s; PCRE2 JIT is 2.4× faster on almost
  the same patterns, the PCRE2 interpreter 0.52×. The automaton engines
  are faster on the subset they accept (RE2 2.6×, Rust `regex` 4.0×,
  ocaml-re 1.2×), but that subset is under half of the patterns: the
  look-around, possessive and atomic constructs they reject are the ones
  the grammars depend on.
- **php is one pattern.** In the php workload, `A(B|C+)+D|AC+X` on a
  21-byte subject (PHP's own backtracking test) takes about 6.8 ms of
  Oniguruma's 9.7 ms pass (checked on the workstation build, one pattern
  at a time). The ×300-×400 ratios of RE2, Rust and ocaml-re on php
  measure exponential backtracking against linear-time matching, not
  general speed; PCRE2 interpreter (×0.22) backtracks even more, PCRE2
  JIT (×2.9) backtracks faster.
- **Compile time.** Median per-pattern compile time on vscode: Oniguruma
  4.1 µs, PCRE2 2.2 µs (16.7 µs with JIT), RE2 6.6 µs, Rust `regex` 52.6 µs
  (p90 525 µs), ocaml-re 3.8 µs (Re.compile is lazy: its DFA is built
  during matching, so its compile time understates the work).
- **Limits.** The VS Code workload is #1's committed sample (20 searches
  per scanner), not the complete 473,134-search set that #1 recommends
  for timing; vscode-subst has no pair for RE2 and Rust (they reject
  every substituted pattern), so those two cells hold compile times only.
  Absolute MB/s carry frequency noise (governor not fixed); ratios are
  the result. The automaton engines' ratios are on their subsets and
  should not be read as whole-workload speedups.
