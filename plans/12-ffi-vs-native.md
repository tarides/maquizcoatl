# Plan: experiment #12, FFI versus native OCaml

Issue: [#10](https://github.com/tarides/maquizcoatl/issues/10) (the
issue body is the reference for scope, inputs, measurement method and
done-criteria; this plan says how). Follow-up for the generated-OCaml
part: [issue #22](https://github.com/tarides/maquizcoatl/issues/22).
Source: maintainer's state-of-the-art report, "Deliverables: libonig
drop-in and OCaml library" and "Experiments before deciding", row of
experiment #12 (https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

## Objective

Decide, with numbers, which costs less for the OCaml library on real
workloads: calling Oniguruma `f95747b` through an FFI, or running a
native OCaml engine. A small backtracking VM written in plain OCaml for
the regular subset of the issue is compared, on experiment #1's
workloads in three shapes (many short searches, few searches over large
subjects, catastrophic patterns under a retry budget), with four other
columns: the same libonig through hand-written `[@@noalloc]` stubs,
through ctypes in `ctypes-foreign` (libffi) mode, from a C-only driver,
and `ocaml-re` as a pure-OCaml reference. The C-only driver splits the
gap into FFI crossing cost (stubs or ctypes minus C driver) and engine
cost (OCaml VM minus C driver). The outcome is evidence for the
report's open question "OCaml library: native code or bindings?".

## Decisions folded in

1. **Generated OCaml split out: (b)**, from the maintainer's
   [comment](https://github.com/tarides/maquizcoatl/issues/10#issuecomment-7015358150).
   Criterion 4 (OCaml extracted by Why3 and Pulse) moved to
   [issue #22](https://github.com/tarides/maquizcoatl/issues/22), which
   depends on experiment #10 (issue #8). This experiment closes on
   criteria 1-3 and 5-7. To keep issue #22 cheap, the harness takes an
   engine as a module of a fixed signature (step 4), so an extracted VM
   is one more column, not a new harness, and the OCaml version is the
   one of the shared prover switch (5.4.1, see Tools).
2. **Timing and isolation on the bench host**, same comment. Every
   job, builds included, runs under `taskset -c 0-3,32-35` (L3 complex
   0 and its SMT siblings), with at most 4 parallel jobs. Experiment
   #11's timing (CPU 4, complex 4-7/36-39) and experiment #4 (CPUs
   8-31, 40-63) run there at the same time. Timed runs use CPU 2 alone,
   with CPUs 0, 1, 3 and 32-35 idle (no build or other job of this
   experiment runs during a timed series). Each timed series records the
   load average and which other experiments were running.

## Where things live

- **Bench host.** Nothing is installed system-wide; no root.
  - `<bench-workdir>/cache/` (written `<cache>`): the shared toolchain
    cache of earlier experiments (opam 2.6.1 binary, `OPAMROOT`
    `<cache>/opam`, `<cache>/env.sh`). This experiment adds two opam
    switches there, `ffi` and `ffi-flambda` (see Tools), reusable by
    issue #22. The existing switches (`provers`, `compcert`) are not
    modified.
  - `<bench-workdir>/exp/12-ffi-vs-native/` (written `<exp>`): a clone
    of `tarides/maquizcoatl` at this branch's commit with the
    `upstream/` submodule at `f95747b` (`<exp>/repo/`, `upstream/`
    read only), two out-of-tree C builds (`<exp>/build/onig-release/`
    for timing, `<exp>/build/onig-debug/` for the test suites), the
    dune build directories, the large subjects (`<exp>/subjects/`),
    downloads (`<exp>/dl/`, one directory per source) and raw outputs
    (`<exp>/out/<run-id>/`).
- **Workstation.** `<workdir>` is the work directory outside the
  repository; this branch's worktree is under `<workdir>/wt/`.
  Development of the VM and the harness, and quick unit tests, happen
  here (no timing). Raw outputs are copied back to `<workdir>/e12/out/`
  before selection.
- **Repository** (branch `exp/12-ffi-vs-native`), under
  `lab/12-ffi-vs-native/`:
  - `setup.sh` (switches, C builds, clone check), `pins.json`
    (versions, URLs, sha256), `provenance.sh`;
  - `subset/`: the subset classifier and `select_tests.py`
    (mechanical selection of `test_utf8.c` cases);
  - `prep.py`: turns experiment #1's JSONL workloads and the large
    subjects into one flat binary-safe format read by both the C and
    the OCaml drivers;
  - `vm/`: the OCaml VM (parser for the subset, compiler to a small
    instruction array, backtracking interpreter);
  - `stubs/`: the `[@@noalloc]` stubs and their OCaml side;
  - `ctypes/`: the `ctypes-foreign` binding;
  - `bench/`: the OCaml harness (one executable, engine chosen on the
    command line) and `cdriver.c` (the C-only driver, same protocol);
  - `run.sh` (interleaved timed series), `summarise.py`;
  - `lab/notebook.md` and `lab/results/`: the lab notebook.

Scripts take `<cache>` and `<exp>` from environment variables and
never print absolute paths, hostnames or addresses into their output,
so raw files can be committed after a redaction check.

## Tools and versions

All actively maintained. `setup.sh` pins every version in
`pins.json`; the notebook records the versions actually installed.

| Tool | Version | Source on the bench host |
|------|---------|--------------------------|
| opam | 2.6.1 | `<cache>/bin` (existing) |
| OCaml | 5.4.1 (`ocaml-base-compiler`), switch `ffi` | opam |
| OCaml with flambda | 5.4.1 (`ocaml-variants.5.4.1+options` + `ocaml-option-flambda`), switch `ffi-flambda`, built with `-O3` | opam |
| dune | 3.25.0 | opam |
| ctypes, ctypes-foreign | 0.24.0 | opam |
| libffi | system package (3.4.6 on Ubuntu 24.04; version recorded) | system, via `conf-libffi` |
| re (`ocaml-re`) | 1.14.0 (as experiment #11) | opam |
| mtime | 2.2.0 (`Mtime_clock`, monotonic) | opam |
| GCC | Ubuntu 24.04 package (13.3.0) | system |
| CMake | system (3.28.3) | out-of-tree builds of `upstream/` |
| Python | 3.12, stdlib only, run with `-I` | system |

OCaml is 5.4.1 rather than the latest 5.5.2 so that the follow-up
(issue #22) can link Why3- and F\*-extracted OCaml, which is compiled
by the shared `provers` switch (OCaml 5.4.1, see experiment #7's
`toolchains` entry), with the same compiler as the columns measured
here. The reason is recorded beside the pin.

`bechamel` is not used: the C driver cannot use it, and criterion 2
needs the same protocol on all columns. The harness mirrors experiment
#11's protocol instead (monotonic clock, repeated whole-workload
passes, min/median/IQR), so the figures can be read against its
baselines.

## Machine budget

Bench host, CPUs 0-3 and 32-35 only, at most 4 parallel jobs
(`opam --jobs=4`, `make -j4`, `dune build -j 4`), all under
`taskset -c 0-3,32-35`. Timed runs: `taskset -c 2`, one process at a
time, nothing else of this experiment running. At most 3 hours of
wall-clock for the whole run, setup included. Long jobs run under
`tmux` (or `nohup`), logs in `<exp>/out/`. Each timed process runs
under `timeout`. `uptime` is recorded before and after each timed
series, with the list of other experiments running (from the
pipeline's dashboard and `ps`, by experiment number only); a series
started with a 1-minute load average above 16 is flagged in the table.
Before each series, the governor of CPU 2 (`schedutil`, not changeable
without root) is recorded and the untimed warm-up pass raises its
frequency.

The engineering (VM, stubs, harness) is done on the workstation before
the run and is not part of the 3 hours.

Expected schedule (wall-clock, bench host):

| Phase | Steps | Time |
|-------|-------|------|
| Setup: two switches, two C builds, clone, subjects (4 jobs) | 1-3 | 45 min |
| Correctness: test subset, workload agreement, allocation check | 6-8 | 15 min |
| Pilot (one run per cell, budget check) | 9 | 10 min |
| Timed short-subject series | 10 | 15 min |
| Timed large-subject series | 11 | 45 min |
| Catastrophic patterns | 12 | 20 min |
| Fetch, redaction check, record | 13-14 | 20 min |
| Total | | 2 h 50 min |

**Milestone 1** (fits in 3 hours): criteria 1, 2, 3, 5, 6 and 7, with
the large-subject shape limited to at most 16 patterns per source (step
5) and the VS Code short-subject workload taken from the committed
sample (11,263 searches, weighted by the frequency profile). If the
pilot (step 9) shows that the timed phases would exceed their share,
the number of large-subject patterns is reduced first (never the 10
runs per cell), and the reduction is recorded. **Follow-up**, outside
this budget, listed on the issue if needed: the complete VS Code set
(473,134 searches, regenerated by experiment #1's `build.sh`, which
needs Node.js); more large-subject patterns; a ctypes `cstubs` column
(the reviewer's optional third FFI mode); the generated-OCaml columns
(issue #22).

## Regular subset and its classifier

The subset is the one of the issue, fixed here before any measurement.
The classifier, `subset/`, is the VM's own parser run in strict mode:
a triple (pattern, syntax, options) is in the subset if and only if it
parses with only these constructs and options, and anything else is
rejected with the first construct it met (logged, so the coverage table
can say why patterns fall out).

- Encoding UTF-8; syntaxes `ONIG_SYNTAX_ONIGURUMA`, `RUBY` and
  `PERL_NG` (the three used by the workloads; `test_utf8.c` uses
  `ONIG_SYNTAX_DEFAULT`, which is Ruby's), with each syntax's own
  meaning of `^`, `$` and `.` (Ruby and Oniguruma: `^`/`$` at line
  boundaries; Perl_NG: `ONIG_OPTION_SINGLELINE` set by the syntax, `$`
  at the end or before a final newline).
- Literals (including escaped metacharacters, `\t \n \r \f \v \e`,
  `\xHH` and `\x{H..}` for one code point); `.`; bracket classes with
  ranges and negation, possibly containing `\d \w \s` and their
  negations; `\d \w \s \D \W \S` outside classes; `^ $ \A \z`;
  capturing `( )` and non-capturing `(?: )` groups; alternation;
  `* + ? {n,m} {n,} {n}` greedy and lazy.
- `\d \w \s` are in the subset in their ASCII meaning only. In UTF-8
  Oniguruma gives them their Unicode meaning unless
  `ONIG_OPTION_WORD_IS_ASCII`, `DIGIT_IS_ASCII` or `SPACE_IS_ASCII` is
  set; on an ASCII-only subject both meanings agree. So a (triple,
  subject) case using them is admitted when the matching `*_IS_ASCII`
  option is set or the subject is ASCII-only; otherwise it is out.
  This reading of "ASCII `\d`, `\w`, `\s`" is recorded in the notebook.
- Options admitted: `CAPTURE_GROUP`, `MULTILINE` (`.` matches
  newline), `SINGLELINE`, `NEGATE_SINGLE_LINE`, the three `*_IS_ASCII`
  options; search options `NOTBOL`, `NOTEOL`; anything else (case
  folding, `FIND_LONGEST`, `FIND_NOT_EMPTY`, …) is out.
- Out by construction: case folding, Unicode properties, lookaround,
  backreferences, named groups, possessive quantifiers, atomic groups,
  `\b \B \G \Z`, subexpression calls, absent operator, inline options.

The VM copies Oniguruma's semantics on the points where a naive
backtracker differs, each with a test: leftmost-first alternation;
the capture of the last iteration of a repeated group; the empty-loop
check of `(a*)*` style loops (experiment #2's notes on empty iterations
are the reference); `{n,m}` with `n > m` and lone `{` as literals
where the syntax says so.

## FFI binding design

As fixed in the issue:

- `[@@noalloc]` stubs: the compiled `regex_t*`, a preallocated
  `OnigRegion*` and an `OnigMatchParam*` are wrapped once, by ordinary
  allocating stubs, in custom blocks (finalisers free them); the search
  stub is
  `external search : regex -> region -> param -> string -> (int [@untagged]) -> (int [@untagged]) -> (int [@untagged]) -> (int [@untagged]) = "…_byte" "…" [@@noalloc]`
  (subject, start, range, search options), reading the pointers with
  `Data_custom_val` and the string in place (no copy), returning the
  `onig_search_with_param` result untagged; capture positions are read
  by `[@@noalloc]` accessors `region_beg : region -> (int [@untagged]) -> (int [@untagged])`
  and `region_end`. These stubs neither allocate, raise nor release the
  runtime lock.
- ctypes: `Foreign.foreign` (libffi) on `onig_search_with_param`, with
  the subject passed as `ocaml_string` (no copy) and offsets as
  pointer arithmetic on `ocaml_string_start`; the region read through
  ctypes `getf`. Measured as its own column.
- C side, all three columns: `onig_search_with_param` with an
  `OnigMatchParam` set by `onig_set_retry_limit_in_match_of_match_param`
  (10,000,000) and `onig_set_retry_limit_in_search_of_match_param` (0,
  unlimited), the defaults of `upstream/src/regint.h:111-112`; the same
  shared `libonig.so` from the Release build for stubs, ctypes and the C
  driver, so the engine code is identical across the three.
- OCaml VM: one retry counted per backtrack to a choice point, counter
  reset per start position, per-match limit clamped to the remaining
  search-wide budget (issue, "Retry budget semantics"); it returns
  Oniguruma's `ONIGERR_RETRY_LIMIT_IN_MATCH_OVER` (-17) code when the
  limit is hit. Its search loop tries each start position in turn
  (advancing by one UTF-8 character), with no search optimiser; this
  is the point of the C-only baseline.

## Workloads

All inputs from experiment #1 are read from `main` at this branch's
base, under `experiments/01-pattern-inventory/workloads/data/`; nothing
there is modified.

- **Short subjects.**
  - jq: `jq.jsonl` (217 calls), PHP: `php.jsonl` (421 calls); each
    call in the subset (classifier, with its subject) is run as
    recorded (`search` or `match`, start, range, options, match
    param).
  - VS Code: `vscode.jsonl` (11,263 scanner searches) with
    `vscode.scanners.jsonl` and `vscode.triples.jsonl`. A scanner search
    uses `onig_regset_search`, which the FFI columns would have to bind
    separately; this experiment measures single-regex searches, so
    each scanner search is expanded into one `onig_search` per member
    triple in the subset, at the recorded start and range, and each is
    repeated `count` times per pass as given by `vscode.frequency.jsonl`
    (the frequency profile), so the pass follows the real call mix.
  - Time per call is reported per family (jq, PHP, VS Code).
- **Large subjects** (criterion 2, throughput). Experiment #1's
  long-subject PHP sample (18 calls, two synthetic subjects: 30,000
  spaces and 2 MiB of `a`) is kept as one labelled synthetic row. Two
  realistic sources are added, each cut at 1 MiB and 16 MiB (at a line
  boundary, sizes recorded):
  - *whole source files*: the OCaml 5.4.1 source release tarball
    (already in `<cache>`'s opam download cache, sha256 recorded):
    every `.ml`, `.mli`, `.c` and `.h` file, sorted by path, whole
    files concatenated until the size is reached;
  - *log files*: a full log from the Loghub collection (logpai,
    Zenodo; the archive and record id pinned with sha256 in
    `pins.json` at step 1, a real system log of at least 16 MiB, for
    example OpenSSH or Linux). If the download fails, the log rows are
    recorded as missing with the reason; no synthetic log stands in.
  - Patterns: the subset triples of the three families ranked by call
    count (VS Code by frequency profile), the top 16 per source after
    removing anchored-at-start patterns that cannot scan (`\A`), ties
    broken by triple id; the list is written to the notebook. Each
    pattern scans the whole subject in a find-all loop (search, then
    restart at the match end, or one character further after an empty
    match), so throughput is subject bytes divided by the time of one
    full scan.
- **Catastrophic patterns** (criterion 3): the three labelled
  synthetic patterns of experiment #11's worst-case entry, one per
  family, all in the subset: jq `(a+)+$` (`PERL_NG`, options 256), PHP
  `(a|aa)+$` (`RUBY`, options 12), VS Code `(\w+\s?)+$` (`ONIGURUMA`,
  options 256), on subjects `"a"*n "!"` for n = 16, 32, …, 4096
  (doubling), the same set as experiment #11 so the "time to reach the
  budget" column reads against its baselines. Experiment #11's files
  are read from branch `exp/11-perf-baselines`, read only.

## Approach

1. **Push the code** (workstation, before the run). Write the VM, the
   classifier, the stubs, the ctypes binding, the harness, the C driver,
   `prep.py`, `select_tests.py`, `setup.sh`, `run.sh`, `provenance.sh`,
   `summarise.py`; unit-test the VM on the workstation against a local
   Debug build of `upstream/` (out of tree, in `<workdir>`); fill
   `pins.json` (including the Loghub archive and its sha256, and the
   OCaml tarball's sha256); commit and push the branch.

2. **Setup** (bench host, about 45 min, 4 jobs). Clone the repository
   branch with `--recurse-submodules` into `<exp>/repo` and check
   `upstream/` is at `f95747b`. Create switches `ffi` and `ffi-flambda`
   in `<cache>/opam` with the pins above and install dune, ctypes,
   ctypes-foreign, re, mtime (the two switch builds run one after the
   other, `--jobs=4`). Build libonig twice out of tree:
   `cmake -S <exp>/repo/upstream -B <exp>/build/onig-release
   -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON` and the same with
   `Debug` in `onig-debug`; record the effective C flags
   (`CMAKE_C_FLAGS_RELEASE`, from `CMakeCache.txt`). Run
   `onig-debug/test/test_utf8` and `onig-release/test/test_utf8` as a
   sanity check (1554 cases each).

3. **Subjects** (in parallel with step 2, about 5 min). Extract the
   OCaml source tarball and download the Loghub archive into
   `<exp>/dl/`, check sha256, build the 1 MiB and 16 MiB subjects, and
   record their sha256 and line counts.

4. **Build the engines** (about 5 min). `dune build` in both switches:
   the harness with the VM, stubs, ctypes and `ocaml-re` columns behind
   one `ENGINE` signature (`compile`, `search` into a preallocated
   result buffer, `get_capture`); `ocaml-re` is a reference only, on
   the cases it can express (its byte semantics recorded). C driver:
   `gcc -O2`, linked to the same `libonig.so`. Compiler flags recorded
   (`-O3` for `ffi-flambda`, `-unsafe` not used).

5. **Prepare workloads** (about 5 min). `prep.py` reads the JSONL
   files, runs the classifier on every (triple, subject), writes the
   in-subset cases to `<exp>/out/<run-id>/work/` in the flat format, and
   writes the coverage table: per family, distinct triples admitted /
   total, calls admitted / total (VS Code also weighted by frequency),
   and the rejection reasons. The large-subject pattern list is chosen
   here.

6. **Regular-subset test cases** (criterion 1, about 5 min).
   `select_tests.py` extracts every `x2`, `x3`, `n` and `e` case of
   `upstream/test/test_utf8.c` (1554 cases, with their line numbers),
   runs the classifier on each pattern, and writes the selected set.
   The VM runs it; the result is passed/total with each failure listed.
   `e` cases in the subset (patterns Oniguruma rejects) count as passed
   only if the VM also rejects them.

7. **Workload agreement** (criterion 7, about 5 min). On every
   in-subset case of step 5, the C driver, the stubs, ctypes and the VM
   each output result code, match span and all capture positions; the
   C driver is the reference (it is Oniguruma). The three FFI columns
   must agree byte for byte (a check of the bindings); every VM
   disagreement is listed with pattern, subject offset and both
   answers. The C driver's spans are also compared with experiment #1's
   recorded `expected` where one exists (jq and PHP calls; VS Code
   scanner searches whose members are all in the subset).

8. **No allocation in the match loop** (criterion 1, about 2 min). For
   each switch, N = 1,000,000 bare VM searches on a fixed short case
   with a preallocated result buffer, `Gc.minor_words ()` and
   `(Gc.quick_stat ()).major_words` read just before and just after the
   loop (their own allocation is a constant, measured on an empty loop
   and subtracted). Pass: zero delta, or a constant per call attributed
   to the result value with the reason. The same check is recorded for
   the stubs column (expected zero) and the ctypes column (expected
   non-zero: ctypes allocates per call), as data for criterion 2.

9. **Pilot** (about 10 min). One untimed run of every cell (engine x
   shape x workload) to check timeouts and estimate the duration of
   steps 10-12. If over budget, reduce the large-subject pattern count
   (Machine budget) and record it.

10. **Short-subject series** (criterion 2). Columns: C driver, stubs,
    ctypes, VM (`ffi`), VM (`ffi-flambda`), `ocaml-re` (`ffi`). Each run
    of a cell is one process under `taskset -c 2`: one untimed warm-up
    pass, then the pass repeated until at least 0.5 s has elapsed; it
    reports calls, time per call, and minor and major words per call
    (`Gc` counters around the timed passes; zero by construction for
    the C driver). 10 runs per cell, interleaved: run r goes through
    every cell in an order shuffled with seed r (seeds recorded), so
    drift spreads over all columns. Statistic: min, median and IQR of
    the 10 per-run values. A cell whose IQR exceeds 10% of its median is
    repeated once (10 more runs); if it still does, it is reported as
    noisy with its data.

11. **Large-subject series** (criterion 2). Same columns and protocol;
    the timed unit is one full find-all scan of one subject by one
    pattern; per (source, size, pattern) the throughput in bytes per
    second, and per (source, size) the median over patterns. 10
    interleaved runs per cell, 120 s `timeout` per process; a cell that
    times out is recorded as such.

12. **Catastrophic patterns** (criterion 3). Columns as above (`ocaml-re`
    has no backtracking, so its time is a reference only). Each (engine,
    pattern, length) point is one process under `timeout 60`, 10
    interleaved runs, recording outcome (match, no match, -17 or the
    VM's equivalent, or `cap`) and time. A row stops at the first length
    where every run reaches `cap`. Agreement on the outcome with the C
    driver is checked per point.

13. **Fetch back** (about 10 min). `rsync` `<exp>/out/<run-id>/` to
    `<workdir>/e12/out/`, scan it for absolute paths, hostnames and
    addresses (redaction check), and copy the files that back a
    notebook entry into `lab/results/`.

14. **Report.** `summarise.py` builds the tables: per shape and
    family, each column's median and spread; FFI crossing cost (stubs
    minus C driver, ctypes minus C driver) and engine cost (VM minus C
    driver, both switches); and the conclusion of criterion 6. Commit
    from the local worktree, push, open the PR, and post the summary on
    issue #10.

## Provenance

`provenance.sh` records, per series: upstream commit `f95747b`; CMake
build type and effective C flags of both builds; GCC and CMake
versions; OCaml version and flambda flag of each switch, with the
`ocamlfind ocamlopt -config` lines that matter (`flambda`,
`flat_float_array`); ctypes, ctypes-foreign and libffi versions; dune,
re and mtime versions; CPU model, RAM, kernel version, the CPU used for
timing and the CPU set for builds, the CPU 2 governor; load average
before and after; the other experiments running (by experiment number);
repository commit, start time and duration. It does not record the
hostname, addresses, user names or absolute paths.

## Lab notebook

With the lab-notebook skill: `lab/notebook.md` (index, one line per
recorded run, under a new "Experiment #12" heading) and
`lab/results/<date>-exp-12-<topic>.md` (append-only), with raw data in
CSV beside it. Planned entries:

1. `provenance`: switches, C builds and flags, subjects (sources,
   sha256, sizes), coverage table of the subset.
2. `vm-tests`: criterion 1, the selected `test_utf8.c` cases
   (passed/total, failures) and the allocation check of step 8.
3. `agreement`: criterion 7, disagreements listed.
4. `short`: criterion 2 for short subjects.
5. `large`: criterion 2 for large subjects (pattern list included).
6. `catastrophic`: criterion 3.
7. `conclusion`: criterion 6, the per-shape FFI crossing cost and
   engine cost and which way the evidence points.

Pilot runs and repeated noisy cells are recorded only as part of the
entry they explain. The maintainer decides on any further entry.

## Outputs

- `lab/12-ffi-vs-native/` (VM, bindings, harness, scripts, pins).
- The lab notebook entries above, with raw CSV.
- Summary tables and the conclusion posted on issue #10.
- Switches `ffi` and `ffi-flambda` in the shared `<cache>`, reusable by
  issue #22, documented in the `provenance` entry.

## Done-criteria (from the issue)

1. Hand-written OCaml VM:
   - it passes the mechanically selected regular-subset cases of `upstream/test/test_utf8.c`; the report gives passed/total and the subset's coverage of the experiment #1 workloads;
   - its match loop performs no allocation: zero `Gc.minor_words` and major-words delta across N bare calls with a preallocated result buffer, measured around the calls only.
2. For each engine (OCaml VM, C via `[@@noalloc]` stubs, C via ctypes, C-only driver) and each workload shape, the results table reports:
   - time per call on short subjects;
   - throughput in bytes per second on large subjects;
   - minor and major words allocated per call;
   - median and spread over repeated runs: at least 10 interleaved runs per cell, warm-up excluded, process pinned with `taskset` to one core of the set 0-3/32-35 (Decision 2), load average recorded, spread given as a named statistic (min/median/IQR, or the 95% CI of an OLS fit).
3. Catastrophic patterns: each engine runs under the same retry budget, and the table reports time to reach the budget and agreement on the outcome (match, no match, or limit error).
4. Moved to issue #22 (Decision 1): the same measurements for the Why3-extracted and Pulse-extracted OCaml of the same VM. This issue closes without it.
5. Every run is recorded in the lab notebook with provenance: upstream commit `f95747b`; CMake build type and C flags; OCaml version and flambda flag; ctypes and libffi versions; CPU model, RAM, kernel, cores used and load average. Hostnames and user-bearing paths are not recorded.
6. A short conclusion states, for each workload shape, the FFI crossing cost (stubs or ctypes minus C driver) and the engine cost (OCaml VM minus C driver), which option costs less, and which way the evidence points on the open question.
7. Agreement on the workloads: match span and capture positions agree with Oniguruma on every experiment #1 workload case run; disagreements are listed.

## Risks

- **Subset coverage may be thin.** Many TextMate patterns use
  lookaround, backreferences or `\b`, and the `\d \w \s` rule drops
  non-ASCII subjects. If fewer than about 20% of VS Code calls are
  admitted, the short-subject figures still stand (they are per call)
  but the coverage table says how representative they are; widening the
  subset would change scope and goes to the maintainer.
- **Semantics drift in the VM** (empty-loop check, captures in loops,
  `$` per syntax). Step 7 lists every disagreement, and speed figures
  are reported only for cases where the VM agrees; a disagreement rate
  above a few percent stops the timing and is reported first.
- **Search optimisers dominate large subjects.** `onig_search` skips
  ahead with BMH or a first-character map (`upstream/src/regint.h:364`);
  the VM does not. The large-subject engine cost will mix "no optimiser"
  with "OCaml code"; the conclusion says so, and the notebook records,
  per pattern, the optimiser Oniguruma chose, read from the
  `ONIG_DEBUG_COMPILE` output of a third out-of-tree build
  (`-DCMAKE_C_FLAGS=-DONIG_DEBUG_COMPILE`, as experiment #2 did), never
  used for timing.
- **Noise from the shared host.** Other experiments and background
  services run on other cores and share memory bandwidth and the
  package's power budget; L3 complex 0 also takes most interrupts. The
  10 interleaved runs, the IQR gate, and the recorded load average and
  running experiments bound this; CPU 2 is used, not CPU 0.
- **ctypes `ocaml_string` with libffi**: if passing an OCaml string
  without copy is refused in `ctypes-foreign` mode on OCaml 5.4.1, the
  ctypes column copies the subject into a preallocated C buffer once per
  subject (outside the timed region for large subjects, inside it for
  short ones), and the notebook says so.
- **Loghub download** may be unavailable or smaller than expected; the
  log rows are then missing with the reason (no synthetic substitute).
- **Flambda switch build time** may exceed the estimate; it runs first,
  and if it is not ready when the timed phases start, the flambda column
  moves to the follow-up and is recorded as missing.
- **Retry-budget fidelity.** If the VM's retry count differs from
  Oniguruma's on the catastrophic patterns (outcome disagreement at some
  length), the disagreement is the finding and is reported as such, not
  tuned away.
