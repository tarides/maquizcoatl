# Experiment #6, milestone 2, entry 1: provenance (run 1)

**What.** Run conditions of run 1 of milestone 2 of experiment #6
(issue #28, plan `plans/06-spec-speed-m2.md`): the bench host, tool
versions, builds, pinning and load. The other entries of run 1 refer
here.

**Why.** Criterion 3 asks for throughput on a stated machine; `T_spec`
must be comparable with milestone 1 and experiment #7, so the host, CPU
set and pins are milestone 1's.

## Provenance (all entries of run 1)

- Decisions in force: issue #28's body, including the maintainer's
  decisions 5 (DEV-001 to DEV-004 implemented as decided) and 6
  (restricted table modules plus a full-table spot check), folded into
  the plan at `cec1b18`.
- Branch `exp/06-spec-speed-m2`: harness at `13c90dd` (stack G on S2,
  C oracle with syntax and options, Why3 and F\* S2 semantics,
  generators, series scripts), used by every timed series of run 1; the
  summary script and these entries are in later commits.
- Upstream: `f95747b`; milestone 1's Release build of the C library
  (`-O3 -DNDEBUG`, `test_utf8` 1554 SUCC, 0 FAIL, 0 ERROR) reused read
  only; `oracle/oracle2.c` built with `gcc -O2` against it.
- Bench host: AMD EPYC 7502P (32 cores, 64 hardware threads), 503 GB
  RAM, Linux 6.8.0-100-generic, Ubuntu 24.04.5 LTS; the host of
  milestone 1 and experiment #7. 52 GB free disk at the start and the
  end of the run.
- Toolchain (unchanged from milestone 1, `pins.json`): opam 2.6.1,
  switch `provers` with OCaml 5.4.1 and zarith 1.14; Why3 1.9.0; F\*
  2026.11.15 (commit `b92b0f87`, Z3 5.3.0 as in milestone 1); Isabelle2026
  and Lean 4.36.0 (Lake 5.0.0, elan 4.4.0) for WP D; GCC 13.3.0, CMake
  3.28.3, Python 3.12.3. Every command uses `opam exec --switch=provers
  --`; the default switch was not changed.
- Timing: CPUs 28-31,60-63 (L3 complex 7), the set of milestone 1, one
  run at a time under milestone 1's lock (`timed.lock`), 20-minute
  timeout, `ulimit -v 64G`. Before each timed series, the threads on
  those CPUs using more than 5% CPU are listed in the series log (none
  in every check of run 1) and the load average is recorded per run in
  `times.tsv`. Untimed work (builds, verdicts, calibration) ran on CPUs
  0-15 under `nice -n 10` (milestone 2 untimed runs were not on CPUs
  4-7 as in milestone 1's `provenance.sh` line, which is inherited text).
- Raw provenance: [provenance.txt](2026-11-24-exp-06-m2-raw/provenance.txt)
  (printed under `taskset -c 0-15`, so its "16 hardware threads" is the
  affinity mask; the host has 64).

## Series of run 1 (UTC, 2026-11-24)

| Series | Content | Script |
|--------|---------|--------|
| WP D | milestone 1's Isabelle `value [code]` (200,000 passes) and Lean `lake` driver (75,000 passes) rerun: one untimed calibration, three pinned runs | `series-m2-1d.sh m2-r1` (14:03-14:07) |
| WP A | C oracle and stack G on S2, parse, search, end to end, three runs | `series-m2-1a.sh r1` (from 14:11) |
| WPs B, C, spot check | Why3 and F\*: extracted throughput, in-prover throughput, `T_spec`, then the full-table spot check | `series-m2-1b.sh r1` |
| WP H | Why3 master check (optional, untimed) | `why3/bug/check.sh r1` |

Outputs on the bench host: `<bench-workdir>/exp/06-spec-speed/m2/out/r1/`
(WP D: `<bench-workdir>/exp/06-spec-speed/out/m2-r1/`, since it reuses
milestone 1's build tree), copied to `<workdir>/e06m2/out/` and selected
into [the raw directory](2026-11-24-exp-06-m2-raw/).
