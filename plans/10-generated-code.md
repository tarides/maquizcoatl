# Plan: experiment #10, generated code quality

Issue: [#8](https://github.com/tarides/maquizcoatl/issues/8) (the issue
body is the reference for scope, inputs, measurement protocol and
done-criteria; this plan says how). Source: maintainer's
state-of-the-art report, "Experiments before deciding", row of
experiment #10 (https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

## Objective

Measure how fast the code each candidate route generates for the VM
proven in experiment #9 runs, against Oniguruma `f95747b`'s `match_at`
on the same bytecode, the same subjects and the same retry budget, in
both of Oniguruma's dispatch styles (direct-threaded and switch). Per
route, report time per match, throughput, ratios to the two `match_at`
builds and to experiment #11's baselines, agreement of results, and
whether threaded dispatch is expressible inside the proof. The figures
feed the report's open question "Which stack, A to G?"; no pass/fail
verdict is given here.

## Decisions folded in

From the maintainer's
[comment](https://github.com/tarides/maquizcoatl/issues/8#issuecomment-7023136027):

- **A. Identical bytecode: (a).** Patterns are compiled by Oniguruma
  through the public `onig_new`; only those whose compiled code stays
  inside experiment #9's opcode subset are timed. The share of each
  workload they cover is reported (experiment #12 found 63% of jq
  calls, 38% of PHP calls, 26-29% of VS Code calls for a comparable
  regular subset; the bytecode-level share is expected to be lower,
  because star loops often compile to peephole opcodes).
- **B. Ratios only.** The verdict is taken at the stack decision,
  against two reference points from experiment #11: the switch-dispatch
  build (0.74-0.80x of direct-threaded on real workloads; experiment
  #11's rerun revised its jq figure to 0.94x, so the reference values
  are read from experiment #11's latest notebook entry, not hard-coded)
  and the direct-threaded build.
- **C. Native routes too**, for every route still standing.
- **D. Bench host**, pinned to a free and idle cache complex, with the
  protocol of experiments #11 and #12.

The route list is fixed once experiment #9 reports (its tools are
picked by the maintainer once experiments #4 and #5 close). This plan
is therefore parametrised by route: the shared part (steps 1-6) does
not depend on experiment #9's tools; each route gets one section
instantiated from the template below.

## Where things live

- **Workstation.** `<workdir>` is the work directory outside the
  repository; this branch's worktree is `<workdir>/wt/10-generated-code`.
  Engineering (driver, classifier, adapters, route extraction) happens
  here, with a Debug build of `upstream/` out of tree under
  `<workdir>/e10/build/`. Extraction from the provers runs here or
  wherever experiment #9 installed its toolchains; only the extracted
  sources travel to the bench host.
- **Bench host** (never named in public text). `<cache>`: the shared
  toolchain cache of earlier experiments (opam root with the `provers`,
  `compcert` and `ffi` switches; the Rust toolchain of experiment #11).
  `<exp>`: `<bench-workdir>/exp/10-generated-code/`, holding a clone of
  this branch with `upstream/` at `f95747b` (read only), the
  out-of-tree builds (`<exp>/build/`), the route builds
  (`<exp>/routes/<route>/`) and raw outputs (`<exp>/out/<run-id>/`).
  Nothing installed system-wide, no root.
- **Repository** (branch `exp/10-generated-code`), under
  `lab/10-generated-code/`:
  - `setup.sh` (clone check, the three Oniguruma builds, route builds),
    `pins.json`, `provenance.sh`;
  - `driver/`: the C driver (`onig_match_with_param` per start
    position, plus a separately labelled `onig_search_with_param`
    column) and the common work-file reader;
  - `classify/`: the bytecode classifier and the dump-to-subset
    translator (step 3);
  - `routes/<route>/`: per route, the extracted VM sources as generated
    (committed, with the extraction command and tool versions), and a
    thin hand-written adapter to the common harness protocol;
  - `run.py`, `summarise.py`;
  - `lab/notebook.md` and `lab/results/`.

Scripts take `<cache>` and `<exp>` from environment variables and never
print absolute paths, hostnames or addresses.

## Approach

Shared part (once, independent of experiment #9's tools):

1. **Inputs.** Read, without modifying them: experiment #1's workloads
   (`experiments/01-pattern-inventory/workloads/data/` on `main`);
   experiment #12's work-file format, `prep.py`, classifier and harness
   protocol (`lab/12-ffi-vs-native/`); experiment #11's build recipe,
   dispatch probe, catastrophic-pattern set and baselines (branch
   `exp/11-perf-baselines`, read only, owned by another contributor);
   experiment #9's opcode subset from issue #4 (`OP_STR_*`, `OP_PUSH`,
   `OP_JUMP`, `OP_FAIL`, `OP_MEM_START`, `OP_MEM_START_PUSH`,
   `OP_MEM_END`, `OP_END`), updated to whatever experiment #9 actually
   proves.

2. **Three out-of-tree Oniguruma builds**, experiment #11's recipe
   (static, `Release`, identical flags apart from one macro):
   `onig-threaded` (default), `onig-switch`
   (`-DCMAKE_C_FLAGS=-DONIG_DISABLE_DIRECT_THREADING`), and, for
   classification only, `onig-dump` (`Debug`,
   `-DCMAKE_C_FLAGS=-DONIG_DEBUG_COMPILE`), which makes `onig_compile`
   print the compiled bytecode list
   (`upstream/src/regcomp.c:7636-7639`). The dispatch style of the two
   timing builds is checked with experiment #11's dispatch probe and by
   comparing the `regexec.c.o` hashes (they must differ). `test_utf8`
   is run on each build as a sanity check (1554 cases).

3. **Bytecode classifier and translator.** The C driver compiles each
   (pattern, syntax, options) triple with `onig_new` on `onig-dump`,
   captures the printed opcode list, and classifies the triple as *in
   subset* (every opcode in experiment #9's subset) or *out*, with the
   first offending opcode logged. Only the public API and the debug
   output are used: no internal symbol, no `regint.h` structure
   (DEV-005, from experiment #4). For in-subset triples, the translator
   turns the dump into experiment #9's bytecode format (jump targets
   resolved, string operands decoded). Its correctness is checked by the
   equal-results criterion (step 8), and the dump parser is unit-tested
   on hand-picked patterns, one per opcode in the subset.

4. **Coverage table** (Decision A). Per workload (jq, PHP, VS Code,
   with VS Code also weighted by experiment #1's frequency profile):
   triples and calls in subset / total, the most frequent offending
   opcodes, and the comparison with experiment #12's pattern-level
   subset. If a workload's coverage is below about 5% of calls, it is
   reported but its timing rows are labelled as not representative.

5. **Workloads.** In-subset cases written in experiment #12's flat
   format, in three shapes: short subjects (as recorded by experiment
   #1), large subjects (experiment #12's 1 MiB cuts of the OCaml source
   and Loghub SSH log, top 16 in-subset patterns per source, find-all
   loop), and catastrophic patterns (experiment #11's set, `"a"*n "!"`
   for n = 16 to 4096, only those whose bytecode is in subset). Retry
   budget: 10,000,000 per match through `OnigMatchParam`, the generated
   VMs given the same counter (one retry per backtrack pop) and the
   same stop-the-search rule as experiment #12; time-to-limit reported
   where the limit is hit.

6. **C reference columns.** The driver times `onig_match_with_param`
   at each start position (the generated VMs have no search optimiser,
   so this is the comparison point), on both timing builds; an
   `onig_search_with_param` column is timed as well and labelled
   "whole search, not comparable".

Per route (template below, once per route still standing):

7. **Build** the route's extracted VM with the adapter, on the bench
   host, with the compiler the route's proof assumes (and GCC `-O2` as
   well where they differ, as an extra column).
8. **Agreement** on every in-subset case: return code, match span and
   all capture positions against `onig-threaded`; every difference is
   recorded (and, if Oniguruma is the one wrong, goes to
   `spec/deviations.md`).
9. **Allocation** (OCaml routes only): `Gc.minor_words` and
   `Gc.promoted_words` delta per match over the loop, Why3 and Pulse
   outputs reported separately.
10. **Dispatch inspection**: what the route emits (`switch`, `match`,
    function table, tail calls), whether the compiler turns it into a
    jump table at the optimisation level used (disassembly check),
    and whether threaded dispatch could be expressed inside the proof.
11. **Timed series**: interleaved with the two `match_at` columns in
    the same series, so ratios are same-session.

Close-out:

12. **Summary**: per route, time per match and throughput (median,
    min/max and IQR over at least 10 runs), ratios to both `match_at`
    builds and to experiment #11's baselines; coverage table;
    agreement; dispatch findings. Recorded in the lab notebook and
    summarised in a comment on issue #8, with no verdict (Decision B).

## Per-route section template

Each route gets a section in the run's notebook entry with these
fields, filled before its timed run:

- **Route**: name and stack (A-G).
- **Source**: experiment #9's proof artefact and commit.
- **Extraction**: tool, version, command; generated files committed
  under `routes/<route>/`, with their sha256.
- **Compile**: compiler and flags on the bench host (and the
  additional GCC `-O2` column if the route's own compiler differs).
- **Adapter**: what the hand-written glue does (reading the work file,
  the outer search loop, the retry counter if outside the proof), and
  which of it is outside the proof.
- **Dispatch**: what is emitted; jump table or not; threaded dispatch
  expressible inside the proof (yes / no / only by post-processing).
- **Results**: agreement, allocation (OCaml), timing, ratios.

Routes and their specifics (instantiated only for the routes experiment
#9 leaves standing):

| Route | Stack | Generated | Compiled on the bench host with | Notes |
|-------|-------|-----------|---------------------------------|-------|
| Why3 → C | E (Why3) | C | GCC (version recorded) | Why3's C printer emits `switch`; no labels-as-values |
| Pulse → C via KaRaMeL, and via Custard if experiment #9 uses it | C (F\*/Pulse) | C, with krmllib headers vendored next to it | GCC | Same VM through each back end if both are standing, as separate columns |
| Verus Rust | D | Rust (the source is the verified artefact) | rustc, experiment #11's pinned toolchain or the one Verus pins, recorded | No computed goto in Rust; `match` |
| Aeneas Rust | B | Rust | rustc, as above | Same as Verus |
| hax Rust | A (or C) | Rust | rustc, as above | Native route of stack A |
| VST/CompCert C | A | C | CompCert (`compcert` switch), plus GCC `-O2` | CompCert is the compiler the proof covers |
| Isabelle-LLVM | F | LLVM IR | `llc`/Clang of a recorded LLVM version | Needs LLVM on the bench host; if absent, built into `<cache>` (counted as setup) |
| generated OCaml | whichever tool proved the VM (Why3, Pulse, Rocq, Isabelle) | OCaml | OCaml 5.4.1 (`ffi` switch, shared with experiment #12) | Shares code with issue #22; allocation measured |

## Tools and versions

All actively maintained (report, "active" rows). No new prover installs
for this experiment: provers and extractors are the ones experiment #9
uses, already in the shared cache (experiment #7 recorded Why3 1.9.0,
F\* 2026.11.15 with Pulse and bundled krml, Rocq 9.3.0, Lean 4.36.0,
OCaml 5.4.1). Pinned in `pins.json`, versions actually used recorded in
the notebook:

| Tool | Version |
|------|---------|
| Oniguruma | `f95747b` (`upstream/` submodule) |
| GCC | Ubuntu 24.04 package (13.3.0) |
| CMake | system (3.28.3) |
| OCaml, dune | 5.4.1, switch `ffi` of experiment #12 |
| Rust | 1.100.0 (experiment #11), or the toolchain the Rust route pins |
| CompCert | the `compcert` switch's version (VST route only) |
| LLVM | version recorded (Isabelle-LLVM route only) |
| Python | 3.12, stdlib only, run with `-I` |

## Machine budget

Bench host, one free and idle L3 cache complex chosen at the start of
the run (from the dashboard and `ps`; recorded by CPU numbers only),
all jobs under `taskset` on that complex, at most 4 parallel jobs.
Timed runs on one core of that complex, one process at a time, nothing
else of this experiment running; load average and other running
experiments (by number) recorded before and after each series;
governor recorded; warm-up pass before each cell. At most 3 hours of
wall-clock for the whole run, setup included. Engineering on the
workstation (driver, classifier, adapters, extraction) is not part of
the 3 hours.

| Phase | Steps | Time |
|-------|-------|------|
| Clone, three Oniguruma builds, sanity tests | 2 | 20 min |
| Classification, coverage, workload preparation | 3-5 | 15 min |
| C reference columns (pilot) | 6 | 10 min |
| Per route: build, agreement, allocation, dispatch check, timed series | 7-11 | about 30 min each |
| Summary, redaction check, record | 12 | 20 min |

**Milestone 1** (fits in 3 hours): steps 1-6 and 12, plus up to three
routes, taken in this order among those standing: the generated OCaml
route (shared with issue #22), the first C-emitting route, the first
Rust route. **Follow-up**, outside this budget, listed on the issue:
the remaining routes, one run of about 30 min each, using the same
builds and work files; larger subjects (16 MiB cuts).

If experiment #9 has not reported when this experiment is scheduled,
steps 1-6 can run alone as a first, route-free milestone (coverage
table and C reference columns), and the routes follow.

## Recorded with the lab-notebook skill

In `lab/notebook.md` (section "Experiment #10") and `lab/results/`, one
entry each, nothing overwritten:

- provenance: builds, dispatch probe, `regexec.c.o` hashes, compiler
  and toolchain versions, cache complex and protocol;
- coverage table (bytecode-level subset, per workload);
- C reference columns;
- per route: agreement, allocation, dispatch inspection, timing and
  ratios (one entry per route, from the template);
- summary with the ratios table.

Deterministic re-runs are not logged twice; repeated timing series are
kept as data. The maintainer decides what is worth recording.

## Outputs

- `lab/10-generated-code/` (driver, classifier, translator, adapters,
  extracted route sources, scripts).
- Notebook entries and result files above.
- Any match-result difference in `spec/deviations.md` when it reveals
  an Oniguruma bug.
- A summary comment on issue #8, then a PR from this branch.

## Done-criteria (from the issue)

- Coverage: for each workload, the share of patterns (and of calls,
  where weighted) whose compiled code stays inside the experiment #9
  subset.
- For each route still standing (native routes included), plus both
  upstream dispatch builds: throughput (bytes/s) and time per match on
  each workload in the subset, as the median of at least 5 runs with
  the spread recorded, on one pinned machine with its configuration
  recorded.
- Each route's speed as a ratio to direct-threaded `match_at` and to
  switch-dispatch `match_at`.
- Every generated VM gives the same match results as `match_at` on all
  benchmark inputs (positions and captures); any difference is
  recorded.
- For generated OCaml: allocation in the match loop, as the
  `Gc.minor_words` delta per match (and `Gc.promoted_words`), reported
  separately for the Why3 and the Pulse output.
- For each route: whether it can express threaded dispatch, and
  whether that dispatch stays inside the proof.
- Results recorded in the lab notebook, with a summary comment on the
  issue that gives, per route, the ratios against both `match_at`
  builds and against the experiment #11 baselines, with no pass/fail
  verdict: the verdict is taken at the stack decision (Decision B).

## Risks

- **Experiment #9 not finished, or proves a different subset.** The
  shared part runs first; the subset list in the classifier is read
  from experiment #9's result, not from issue #4's text.
- **Low bytecode-level coverage.** Peephole opcodes
  (`OP_PUSH_OR_JUMP_EXACT1`, `OP_PUSH_IF_PEEK_NEXT`, `OP_EMPTY_CHECK_*`,
  `OP_REPEAT*`) push most star patterns out of subset; the timed set may
  be small and skewed towards simple patterns. Mitigation: coverage is a
  criterion in itself; rows below a few per cent are labelled, and the
  bias is stated in the summary.
- **`onig_match` per start position** pays per-call setup (match
  argument, region) that `match_at` inside `onig_search` does not; the
  generated VMs' outer loop is in their adapter. Mitigation: both sides
  use the same per-position structure, and the per-call overhead of
  `onig_match` is measured on an empty pattern and reported.
- **Debug-print build parsing.** The dump format is not an API; if it
  is ambiguous for some opcode, the classifier marks the triple out and
  logs why.
- **Route-specific runtime support** (krmllib, Rust crates, OCaml
  libraries from the provers) may need extra build steps; counted in
  the route's 30 minutes, overflow moved to follow-up.
- **Bench host contention.** If no cache complex is idle, the run
  waits; a series started with load above the threshold of experiment
  #12 is flagged.
- **Reference ratios drift between sessions** (experiment #11 saw 3-7%):
  ratios are taken within the same interleaved series only.
