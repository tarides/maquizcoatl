# Plan: experiment #11, performance baselines

Issue: [#2](https://github.com/tarides/maquizcoatl/issues/2) (the issue
body is the reference for scope, inputs, measurement protocol and
done-criteria; this plan says how).
Source: maintainer's state-of-the-art report, "Experiments before
deciding", row #11 (https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

## Objective

Time Oniguruma `f95747b` and the reference engines (PCRE2 interpreter,
PCRE2 JIT, RE2, Rust `regex`, `ocaml-re`) on the workloads of
experiment #1, in-process and under one protocol, so that #10, #12 and
the final implementation have fixed speed targets. Oniguruma is timed
in two builds, direct-threaded and switch dispatch, which gives #10 its
dispatch number on the same workloads. Record throughput, compile time,
agreement with Oniguruma, and worst-case behaviour.

## Decisions folded in

From the maintainer's
[comment](https://github.com/tarides/maquizcoatl/issues/2#issuecomment-7007239442):

1. Timing runs on the blocksci bench host (a dedicated machine), not on
   the maintainer's laptop. Published provenance of that host is its
   CPU model and kernel version only.
2. A second Oniguruma column, built with
   `-DONIG_DISABLE_DIRECT_THREADING` (`upstream/src/regint.h:58-62`).

From the maintainer's
[comment](https://github.com/tarides/maquizcoatl/issues/2#issuecomment-7008103108)
on the
[question](https://github.com/tarides/maquizcoatl/issues/2#issuecomment-7007472892)
about the frequency governor:

3. No root on the bench host. The CPU frequency governor (`schedutil`)
   is left as it is; nothing is run through sudo. Frequency noise is
   handled by the warm-up pass and the 10% spread rule (step 7), the
   governor and frequency range are recorded in provenance (step 10),
   and the report treats ratios as the primary result (step 11).

## Where things live

- **Bench host.** Everything is under `~/maquizcoatl-work/e11/` in the
  bench host's home directory (written `<bench>` below). Nothing is
  installed system-wide and the existing opam root and Rust setup (if
  any) of the account are not touched:
  - `<bench>/repo/` — a clone of `tarides/maquizcoatl` at branch
    `exp/11-perf-baselines`, with the `upstream/` submodule at
    `f95747b` (read only; never built in);
  - `<bench>/src/` — pinned release tarballs, with their sha256;
  - `<bench>/build/<engine>/`, `<bench>/prefix/` — out-of-tree builds
    and their install prefix;
  - `<bench>/toolchains/rustup`, `<bench>/toolchains/cargo` —
    `RUSTUP_HOME` and `CARGO_HOME`; `<bench>/toolchains/opam` — a
    separate `OPAMROOT`;
  - `<bench>/workloads/` — #1's workloads, converted (step 5);
  - `<bench>/out/<run-id>/` — raw harness output of each run.
- **Workstation.** `<workdir>` is the work directory outside the
  repository; `<workdir>/e11/out/` receives the raw outputs copied back
  from the bench host. The worktree of this branch is under
  `<workdir>/wt/`.
- **Repository** (branch `exp/11-perf-baselines`):
  - `experiments/11-perf-baselines/` — `setup.sh` (step 2), `build.sh`
    (steps 3-4), `prep_workloads.py` (step 5), the harnesses
    (`onig_bench.c`, `pcre2_bench.c`, `re2_bench.cc`,
    `rust_bench/` with `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`,
    `ocaml_bench/` with a `dune` project), `agree.py` (step 6),
    `run.sh` (steps 7-8), `provenance.sh`, `summarise.py`, and
    `pins.json` (versions, URLs, sha256, licences);
  - `lab/notebook.md` and `lab/results/` — the lab notebook.

Scripts take `<bench>` from an environment variable with
`~/maquizcoatl-work/e11` as default, and never print absolute paths into
their output, so raw files can be committed after a redaction check.

## Tools and versions

All actively maintained. Pinned now; the notebook records them again at
run time.

| Tool | Version | Source on the bench host |
|------|---------|--------------------------|
| GCC / G++ (all C and C++ engines and harnesses) | 13.3 (Ubuntu 24.04 package) | system |
| CMake | 3.28 | system |
| Python (stdlib only, `-I`) | 3.12 | system |
| Oniguruma | `f95747b` | `upstream/` submodule |
| PCRE2 (JIT enabled) | 10.49 | release tarball |
| Abseil | 20260817.0 | release tarball |
| RE2 | 2025-11-05 | release tarball |
| Rust toolchain | 1.100.0 | rustup into `<bench>/toolchains/`, pinned by `rust-toolchain.toml` |
| Rust `regex` crate | 1.13.2 | `Cargo.toml` (`=1.13.2`) + committed `Cargo.lock` |
| opam | 2.1.5 (installed) | system; separate `OPAMROOT` |
| OCaml | 5.5.2 (`ocaml-base-compiler`) | opam switch in `<bench>/toolchains/opam` |
| `ocaml-re` (opam `re`) | 1.14.0 | opam |
| `mtime` | latest 2.x at setup, recorded | opam (monotonic clock for the OCaml harness) |
| dune | latest 3.x at setup, recorded | opam |

The C and C++
engines are all built with the same compiler and `-O3 -DNDEBUG`
(CMake `Release`), as the issue requires. The bench host has no clang
and no `libabsl-dev`; neither is installed system-wide.

## Machine budget

At most 4 parallel jobs (`make -j4`, `cargo build -j4`, `opam
--jobs=4`), and at most 3 hours of wall-clock for the whole run on the
bench host. Timing runs execute one at a time (one job). Disk: under
5 GB in `<bench>` (the bench host has about 160 GB free).

**Milestone 1** (fits in 3 hours): steps 1-9 on #1's published
workloads, or, if #1 has not published them when the run starts, on the
smoke corpus (patterns and subjects from `upstream/test/test_utf8.c`)
only; the timed runs on #1's workloads then become milestone 2.
**Follow-up** (outside this budget, listed on the issue if needed):
regset throughput as an Oniguruma-only row; repeating milestone 1 if
spread rules invalidate too many cells.

## Approach

1. **Pin and push the harness code** (workstation, about 10 min of
   machine time). Write the harnesses and scripts in
   `experiments/11-perf-baselines/`, commit and push the branch. Build
   and test the harnesses on the workstation only as a compile check
   (no timing there). This check may use the workstation's system
   packages (distribution PCRE2, RE2, and so on); only the bench-host
   builds of steps 3-4, from pinned sources, count for criterion 1. Fill `pins.json` with URLs and sha256 of every
   tarball.

2. **Reproducible setup on the bench host** (about 40 min, mostly the
   OCaml switch build). `ssh` to the bench host and run `setup.sh`:
   - check that `<bench>` is under the home directory and that disk and
     load are as expected; clone the repository branch with
     `--recurse-submodules` and check that `upstream/` is at
     `f95747b`;
   - download the tarballs to `<bench>/src/`, verify their sha256
     against `pins.json`, refuse to continue on mismatch;
   - install rustup with `--no-modify-path` and
     `RUSTUP_HOME`/`CARGO_HOME` under `<bench>/toolchains/`, then the
     toolchain named in `rust-toolchain.toml`;
   - `opam init --bare --disable-sandboxing -n` with
     `OPAMROOT=<bench>/toolchains/opam`, then
     `opam switch create e11 ocaml-base-compiler.<version> --jobs=4`
     and `opam install re.1.14.0 mtime dune`;
   - every later command is run through one `env.sh` that sets these
     variables, so the account's own opam root and `PATH` are untouched.

3. **Build Oniguruma twice** (about 5 min). Out of tree from
   `<bench>/repo/upstream` with `-DCMAKE_BUILD_TYPE=Release
   -DBUILD_SHARED_LIBS=OFF` (static, so each harness binary carries its
   own copy and both builds can coexist):
   `build/onig-threaded/` with default flags, and `build/onig-switch/`
   with `-DCMAKE_C_FLAGS=-DONIG_DISABLE_DIRECT_THREADING`. A probe
   compiled against each build's flags with `regint.h` prints whether
   `USE_DIRECT_THREADED_CODE` is defined; the result is recorded
   (criterion 1). The two libraries must differ in `regexec.c.o`.

4. **Build the other engines** (about 15 min). PCRE2 10.49 with CMake
   (`PCRE2_SUPPORT_JIT=ON`, 8-bit library only, static); Abseil then
   RE2 with CMake, static, installed into `<bench>/prefix`, both with
   `-DCMAKE_PREFIX_PATH=<bench>/prefix -DCMAKE_CXX_STANDARD=17
   -DABSL_PROPAGATE_CXX_STD=ON` (so RE2 finds the Abseil just installed
   and both use the same C++ standard); the Rust harness with `cargo build --release
   --locked`; the OCaml harness with `dune build --release`. The C and
   C++ harnesses are compiled with the same `-O3 -DNDEBUG`. All build
   commands are logged (criterion 1).

5. **Prepare workloads** (about 5 min). Fetch #1's workloads by git from
   its branch (or `main`, once merged) at a recorded commit, into
   `<bench>/workloads/`. `prep_workloads.py` turns
   `workloads/<source>.jsonl` into one simple format read by every
   harness: one line per pattern and one file per subject. Each pattern
   line carries #1's per-record fields unchanged: record id, syntax,
   compile-time options, search-time options (kept separate from the
   compile options), encoding, non-default match-param limits (such
   records are counted and reported), pattern bytes in hex, and #1's
   expected result, which `agree.py` uses as a cross-check of the
   Oniguruma reference. It splits out the rows that
   are Oniguruma-only by construction (non-UTF-8 encodings) and the
   `host-substituted` TextMate patterns. Workloads are translated once,
   never per engine. Until #1 publishes, the same script builds the
   smoke corpus from the `x2`/`x3`/`n` cases of `upstream/test/test_utf8.c`:
   it decodes the C escapes of the string literals (`\xHH`, octal,
   `\\`, `\"`, adjacent-literal concatenation) into bytes, and excludes
   the `e(...)` (expected compile error) cases.

6. **Agreement check** (criterion 3; about 10 min, up to 4 jobs in
   parallel since nothing is timed). Each harness has a `check` mode
   that prints, per (pattern, subject), the compile status (accepted,
   rejected with error, unsupported syntax or feature, or rejected by a
   resource limit) and the list of non-overlapping matches with group 0
   bounds. Matches are enumerated the same way in every engine, never
   with an engine's own iterator: search from a start offset in the
   whole subject (so anchors and look-behind see the full subject),
   starting at 0; after a match `[s, e)` the next search starts at `e`,
   or, if the match is empty (`s = e`), at `e` plus one character
   (one code point in UTF-8, one byte for byte-oriented rows). The
   timed passes of step 7 use the same loop. Oniguruma threaded is
   the reference. `agree.py` lists every disagreement and classifies it
   as syntax difference, semantic difference (e.g. byte versus code
   point in `ocaml-re`), or unexplained. Patterns rejected by a
   resource limit (RE2 `max_mem`, Rust `regex` `size_limit`) are counted
   separately from unsupported syntax, in `agree.py` and in the
   criterion 2 counts; both limits stay at their defaults, and the
   notebook says so; disagreeing patterns are
   excluded from the timing tables of that engine. The switch build must
   agree exactly with the threaded build; any difference stops the run.
   The check also records the duration of one search pass per (engine,
   workload); from these, `run.sh` prints the projected duration of
   step 7 (warm-up, repetitions, possible repeats) before launching the
   timed runs, so the 3-hour budget is checked before it is spent.

7. **Throughput and compile time** (criterion 2; about 40 min).
   `run.sh` first records the run conditions (step 10), then, for each
   engine column (Oniguruma threaded, Oniguruma switch, PCRE2
   interpreter, PCRE2 JIT, RE2, Rust `regex`, `ocaml-re`) and each
   workload, runs the harness in `time` mode:
   - CPU pinning: `taskset -c 4` (core 4 on the second L3 complex; core 0
     receives most interrupts), with its SMT sibling (CPU 36) and the
     rest of that L3 complex (CPUs 5-7, 37-39) left idle. The layout is
     re-checked with `lscpu -e` at setup;
   - compile time: each pattern is compiled repeatedly until both at
     least N = 1000 compilations and at least 10 ms have elapsed, with a
     cap of 1 s per pattern; the compile time is the median per pattern,
     and the N actually used is recorded;
   - search: one warm-up pass, then at least 5 timed repetitions of the
     whole workload pass (compile excluded; each repetition lasts at
     least 0.5 s, by repeating the pass), with
     `clock_gettime(CLOCK_MONOTONIC)` (C, C++), `std::time::Instant`
     (Rust) and `Mtime_clock` (OCaml). Definitions: a pass runs every
     (pattern, subject) pair of the workload once; bytes/s = sum of the
     subject lengths over all (pattern, subject) pairs of the pass /
     median pass time; spread = IQR / median of the pass times. Output:
     bytes/s, median pass time, min, max, IQR and spread, match count,
     rejected, resource-limited and unsupported pattern counts;
   - the warm-up pass is untimed; it also lets the `schedutil`
     governor raise the pinned core's frequency before timing starts;
   - a cell whose spread exceeds 10% is repeated once;
     if it still exceeds 10%, it is reported as invalid with its data.

8. **Worst case** (criterion 4; at most 30 min). Per workload family,
   one catastrophic-backtracking pattern from #1's fuel tier if there is
   one, else a labelled synthetic one (for example `(a+)+$`), on
   subjects of growing length (16 to 4096 bytes, doubling), on each
   engine, with Oniguruma's default retry limit and PCRE2's default
   match limit. The 60 s cap is enforced from outside: each (engine,
   pattern, length) point runs in its own process under `timeout 60`,
   and reaching it is recorded as a distinct outcome, `cap`. Record
   time, or the error (`ONIGERR_RETRY_LIMIT_IN_MATCH_OVER` −17,
   `PCRE2_ERROR_MATCHLIMIT`, `PCRE2_ERROR_DEPTHLIMIT`,
   `PCRE2_ERROR_HEAPLIMIT`, `PCRE2_ERROR_JIT_STACKLIMIT`), or `cap`, and
   the subject length; the JIT stack size used is recorded. Oniguruma's
   default retry limit is high (10,000,000, `upstream/src/regint.h:111`), so its
   rows are expected to hit `cap` mostly, not −17. Rows that reach the
   cap are stopped at that length.

9. **Fetch results back** (about 5 min). `rsync` `<bench>/out/<run-id>/`
   to `<workdir>/e11/out/` on the workstation, check the files for
   absolute paths, hostnames and addresses (redaction check), then copy
   the raw CSV files that back a notebook entry into `lab/results/` on
   this branch, next to the entry that cites them.

10. **Provenance** (each run). `provenance.sh` records only: CPU model
    and kernel version of the bench host; the CPU list used; the load
    average before and after; the frequency governor, boost state and
    frequency range (`scaling_min_freq`, `scaling_max_freq`,
    `cpuinfo_min_freq`, `cpuinfo_max_freq`) of the pinned CPU, and its
    `scaling_cur_freq` sampled before and after each engine column (all
    read from `/sys`, no root needed); compiler, CMake,
    rustc, OCaml versions and flags; `/proc/stat` counters of CPUs 4,
    36, 5-7 and 37-39 sampled before and after each engine column (since
    `taskset` cannot keep the siblings idle, this shows whether other
    work ran on them); engine versions and sha256; the
    repository and #1 workload commits; start time and duration. It
    does not record the hostname, addresses, user names or paths.
    The governor is left as it is (`schedutil`; Decision 3): no root
    command is run on the bench host. The warm-up pass and the spread
    rule of step 7 decide validity. The run is not started if the load
    average exceeds 2 (other users share the host); this is checked
    again before each engine column.

11. **Report** (criterion 6). `summarise.py` builds the engine ×
    workload table (both Oniguruma builds as columns, invalid cells
    marked) from the raw files. Absolute bytes/s carry frequency noise
    (the governor is not fixed, Decision 3), so the primary result is
    the ratios: each engine column relative to Oniguruma threaded on
    the same workload, and Oniguruma switch relative to Oniguruma
    threaded; the report says so, and absolute bytes/s are given as
    indicative. Commit the notebook entries, push, open
    the PR, and post the summary table on issue #2.

## Lab notebook

With the lab-notebook skill: `lab/notebook.md` (index, one line per
recorded run, linking to its file) and
`lab/results/<date>-exp-11-<topic>.md` (append-only), raw data in
`lab/results/<date>-exp-11-<topic>.csv` beside it. Planned entries:

1. `builds` — pinned versions, sha256, build commands, the dispatch
   probe of both Oniguruma builds (criterion 1).
2. `agreement` — per engine and workload: accepted, rejected,
   unsupported counts, disagreements and their classification
   (criteria 2 and 3).
3. `throughput` — compile time and search throughput per cell, with
   spread and run conditions (criteria 2 and 5).
4. `worst-case` — per family, pattern, subject lengths, times or errors
   (criterion 4).

Smoke-corpus timing is a pipeline test and is not recorded in the
notebook by default; if #1's workloads are not available, the
maintainer decides whether the milestone 1 smoke-corpus results get an
entry. Exploratory runs are not recorded. The maintainer decides on any
further entry.

## Outputs

- `experiments/11-perf-baselines/` (scripts, harnesses, pins).
- Lab notebook entries above, with raw CSV files.
- Summary table posted on issue #2.

## Done-criteria (from the issue)

1. Every engine builds from a pinned version, and the build commands are recorded. For Oniguruma this covers both builds (threaded and switch dispatch), and the notebook shows which dispatch each build actually compiled.
2. For each engine (the two Oniguruma builds counting as two columns) and each #1 workload, the notebook records:
   - compile time per pattern;
   - search throughput (bytes/s) or time per search, as the median of at least 5 repetitions, with spread;
   - the number of patterns the engine rejects or does not support.
3. Match results agree with Oniguruma (match position and length) on the patterns each engine supports. Every disagreement is listed, explained by a syntax or semantic difference, and those patterns are excluded from the timing comparison.
4. Worst-case behaviour: at least one catastrophic-backtracking pattern per workload family is timed on each engine, with Oniguruma's default retry limit, and the outcome (time, or the retry-limit error) is recorded.
5. Every run is recorded in the lab notebook with provenance: CPU model and kernel version of the blocksci bench host, compiler and flags, and engine versions.
6. A summary table (engine × workload, with both Oniguruma builds) is posted on this issue.

## Risks

- **#1's workloads are late.** Milestone 1 then runs on the smoke
  corpus, which is not representative; criterion 2 is met only by
  milestone 2. The workload format may also change; `prep_workloads.py`
  is the only place that reads it.
- **Shared host noise.** Other users may load the host, and boost and
  the `schedutil` governor add variance. Mitigation: load check before
  each column, pinning on an idle L3 complex, the 10% spread rule, and
  recording governor, boost state and frequency range. Absolute
  bytes/s remain noisy; ratios are the primary result.
- **No root.** Decided (Decision 3): the governor and CPU isolation
  (`isolcpus`) are not changed; the plan does not depend on them.
- **Old opam (2.1.5).** If it cannot build the switch, a current opam
  binary is downloaded into `<bench>/toolchains/` (pinned, checksum
  recorded) instead of upgrading the system one.
- **Harness asymmetry.** Different languages mean different overheads
  (bounds checks, allocation of match data). Each harness allocates its
  match data once per pattern, outside the timed loop where the API
  allows, and the notebook states per engine what is inside the timed
  region.
- **Semantic gaps.** `ocaml-re` works on bytes; RE2 and Rust `regex`
  reject many patterns; TextMate host-substituted patterns cannot be run
  verbatim. Exclusions are counted, not hidden (criteria 2 and 3).
- **Worst-case runs hog the core.** The 60 s cap and stopping a row at
  the first cap bound step 8 to 30 minutes.
- **Leaking host details.** Raw outputs pass a redaction check before
  they are committed; the host is named only as the blocksci bench host.
