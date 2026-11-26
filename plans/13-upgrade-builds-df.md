# Plan: experiment #13 follow-up, Verus and Isabelle builds

Issue: https://github.com/tarides/maquizcoatl/issues/25 (the issue body is
the reference for scope, decisions and done-criteria; this plan says how).
Parent: experiment #13, issue #3, plan `plans/13-upgrade-cost.md`, results
`lab/results/2026-11-19-exp-13-*`.
Source: maintainer's state-of-the-art report, section "Experiments before
deciding", row 13: https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc

## Objective

Fill the builds cells of the Verus (stack D) and Isabelle (stack F) rows of
experiment #13's summary table, today "not built (follow-up issue)", with
the method of experiment #13's builds: one sample project per stack, built
and checked on its pinned tool version and on the latest release, back to
back, with the same parallelism, then ported to the latest release within
the time box. Criteria 1 to 4 of issue #3 are recorded for each sample.

Decisions on issue #25 (2026-11-26,
https://github.com/tarides/maquizcoatl/issues/25#issuecomment-7166452261
and the maintainer's answer after it):

1. **Verus baseline: A.** Anvil at `3c95bbb`, its last release-pinned
   commit.
2. **Verification time: A.** One untimed full build on the pinned side
   first; a fixed subset only if it exceeds the driver's timeout, chosen
   and recorded in this plan before any timed pair.

## Snapshot

Date D' = 2026-11-26. Releases published after D' are ignored.

| Stack | Sample | Pinned side | Latest side | Releases crossed |
| --- | --- | --- | --- | --- |
| D | Anvil `3c95bbb` (2026-07-23, `anvil-verifier/anvil`) | Verus `release/0.2026.07.12.0b42f4c` (published 2026-07-13), Rust 1.96.0, `vstd =0.0.0-2026-07-12-0122` | Verus `release/0.2026.11.22.1ce6a59` (published 2026-11-23), Rust 1.100.0, `vstd =0.0.0-2026-11-22-0344` | 16 |
| F | Six AFP regex entries of AFP 2025-2, `isabelle-prover/mirror-afp-2025-2` at `fa30b560ab75` (2026-10-16, its last commit at D') | Isabelle2025-2 (2026-01-18) | Isabelle2026 (2026-10-24) | 1 |

**Verus releases.** The 16 stable releases after 0.2026.07.12, up to and
including 0.2026.11.22: the 15 of `verus.tsv` dated 2026-07-20 to
2026-11-02 (0.2026.07.18 to 0.2026.11.02), plus 0.2026.11.22, the only
stable release since. Rolling pre-releases (`release/rolling/...`, latest
`0.2026.11.26.a22d456` on 2026-11-26) are excluded, as in `verus.tsv`.
The release rows after `verus.tsv`'s last one are appended to it, with the
command used (`gh api 'repos/verus-lang/verus/releases?per_page=15'`).
Isabelle2026 is still the latest Isabelle release at D', so `isabelle.tsv`
gets no row; the plan says so in the results.

**Toolchain facts** (checked on 2026-11-26 in the Verus repository at
each release tag; recorded again at run time by the driver's probes):

| Release | `rust-toolchain.toml` | Z3 (`source/tools/get-z3.sh`) | x86-linux zip |
| --- | --- | --- | --- |
| 0.2026.07.12.0b42f4c | 1.96.0 | 4.12.5 | 32,514,386 bytes |
| 0.2026.11.22.1ce6a59 | 1.100.0 | 4.16.0 | 37,884,042 bytes |

The step crosses the Z3 4.16.0 upgrade (Verus PR 2578), which Anvil's
`febab3b` later adapted to. Isabelle2026 bundles `z3-4.4.0pre-8`,
`cvc5-1.3.4` and `verit-2026.05` (its `contrib/`); Isabelle2025-2's
components are read from its `contrib/` at install time.

**Anvil at `3c95bbb`** is one crate, `verifiable-controllers` (with a
`Cargo.lock`), whose `lib.rs` holds the shared modules
(`kubernetes_api_objects`, `kubernetes_cluster`, `reconciler`,
`shim_layer`, `state_machine`, `vstd_ext`, ...) and five controller
modules (`vreplicaset_controller`, `vdeployment_controller`,
`vstatefulset_controller`, `rabbitmq_controller`, `composition`). It
depends on `vstd` from crates.io and on `verus_temporal_logic`
(`anvil-verifier/verus-tla` at `8bb157b`), which itself pins
`vstd = "=0.0.0-2026-07-12-0122"`. Its CI job `full-verification` runs
`cargo verus verify --lib` with no `--rlimit` (the `--rlimit 100` came
later, at `e83ea0f`); on 2026-07-23 that job took 30 minutes on a GitHub
runner for this very commit (run 29982674823). Issue #25's "subset of
crates" therefore means a subset of **modules** of this one crate
(Verus `--verify-module`).

**AFP sessions.** The six entries define seven sessions:
`Regular-Sets`, `Regex_Equivalence`, `Posix-Lexing`,
`Formula_Derivatives`, `Formula_Derivatives-Examples`,
`MSO_Regex_Equivalence`, `Functional-Automata`. Their ROOT files at
`fa30b560ab75` require `HOL-Library`, `Efficient-Mergesort`
(and `HOL-Data_Structures`), `SpecCheck`, `List-Index`, `Deriving` (which
requires `Collections`, hence the Refinement Framework sessions),
`Coinductive_Languages`, and the sessions `While_Default`, `FSet_More` and
`List_More`. `Coinductive_Languages` itself requires `Regular-Sets`, so it
sits between two of the seven sessions: it is built in the timed phase
(see Isabelle below), and its time is reported apart.

## Builds and checks

As fixed in issue #25's body.

- **Verus:** `cargo verus verify --lib`, as Anvil's CI job, with
  `cargo -j 8` and the Verus arguments `--num-threads 8 --time-expanded`
  forwarded to Anvil's crate only (`--time-expanded` gives per-module
  times, used for the subset rule and for a partial ratio). The e2e tests
  (`kind`, a Kubernetes cluster) are out of scope.
- **Isabelle:** `isabelle build -b -o document=false -j 2 -o threads=4
  -d <afp>/thys` of the seven sessions (plus `Coinductive_Languages`),
  with `-c` so that the timed sessions are rebuilt from scratch.

### Untimed preparation and measured step

The driver separates `prepare` (untimed) from the measured run, as in
experiment #13.

- **Verus, prepare:** check out Anvil at `3c95bbb` in
  `build/anvil-<side>`; on the latest side apply the dependency edits
  (below); `cargo fetch`; build and verify the dependencies (`vstd`,
  `verus_temporal_logic`, `kube` and the other Rust crates) with Anvil's own
  verification off (forwarded `--no-verify` to Anvil's crate only), then
  `cargo clean -p verifiable-controllers` (the driver's `stale` rule for
  Anvil). The probe checks in cargo's log that the measured run that
  follows finds the dependencies `Fresh`, so that the timed scope is
  Anvil's crate only; if it does not, the dependencies' time is included
  on both sides and the notebook says so.
- **Verus, measured:** `cargo verus verify --lib`, as above.
- **Isabelle, prepare:** sparse checkout of `thys/` of the entries and their
  requirements at `fa30b560ab75` in `build/afp-regex-<side>`; build the
  requirements of the seven sessions that do not descend from any of them
  (`isabelle build -b -o document=false -R -x <each of the seven>` on the
  seven; the session list is first printed with `-n` and recorded), into an
  Isabelle user home of the experiment (`USER_HOME` under `switches/`), so
  that no heap goes into the shared cache.
- **Isabelle, measured:** the build above. Per-session times are read from
  the build log (`Finished <session> (... elapsed time ...)`), so that the
  six entries' time and `Coinductive_Languages`' time are both reported.

### Dependency edits (latest side, counted as cost)

As issue #3 requires, dependency moves are recorded apart from proof
repairs, like the mathlib bump of lean-regex or Linden's Warblre move.

- **Verus:** `rust-toolchain.toml` 1.96.0 to 1.100.0 (its comment asks to
  keep it in sync with Verus); `Cargo.toml` `vstd = "=0.0.0-2026-11-22-0344"`
  and `cargo update -p vstd` (the `Cargo.lock` diff is recorded, not counted
  as hand-written lines); `verus_temporal_logic` patched to a local checkout
  of `verus-tla` `8bb157b` whose `vstd` line is moved the same way
  (`[patch."https://github.com/anvil-verifier/verus-tla"]` in Anvil's
  `Cargo.toml`). `verus-tla` has no later commit pinning a release
  (`f1e9d05` pinned 0.2026.07.12, `ee48d2a` unpinned it on 2026-07-28), so
  any repair inside it is dependency cost, measured like the rest.
- **Isabelle:** none expected (the AFP 2025-2 entries are used as they are);
  a failure in a required entry is repaired and recorded as dependency
  cost, as for Linden's Warblre.

### Porting (criterion 3)

A failure on the latest side starts the port, by Claude Code, within the
issue's half-day hands-on time box per project **and** the run's 4-hour
cap, whichever comes first. Recorded: failing files (driver's
`Failures.files`), error categories, patch (`git diff --stat` and the
patch file), hands-on time. During the port, re-runs are restricted to
the failing modules (Verus `--verify-module`) or sessions (Isabelle) and
are not timed. For Isabelle, where AFP 2026 holds the upstream fixes
(Posix-Lexing 6 lines, `verit_` to `alethe_`; Formula_Derivatives 10
lines), the port is done first without looking at them, then compared
with them; the notebook says which.

## Method: CPU set, parallelism, timeouts

- **Timed set:** `taskset -c 24-27,56-59`, one L3 complex of the EPYC 7502P
  (cores 24-27 and their SMT siblings 56-59; 8 logical CPUs), same knobs
  on both sides: Verus `cargo -j 8`, `--num-threads 8`; Isabelle
  `-j 2 -o threads=4`. Every command runs under `nice -n 10` through the
  driver's `Limits`. Before each timed pair: no other process on those
  CPUs (`ps -eLo user,psr,pcpu,comm`, recorded), load average recorded
  before and after each side.
- **Untimed work** (installs, checkouts, preparation, port re-runs): at most
  4 jobs, or 12 for slow installs (the Isabelle dependency heaps), under
  `nice -n 10` on CPUs 8-19,40-51; never on 28-31,60-63 (reserved for
  other experiments' timed checks), and never on the timed set while a
  timed pair or the probe runs.
- **Driver timeout for the measured runs:** `--timeout 45m`. This is the
  "driver's timeout" of decision 2.

### Full-build probe and subset rule (decision 2)

The probe is the first thing run on the timed set, before any timed pair
of either stack: pinned side, prepare then one full measured-equivalent
`cargo verus verify --lib` with the timed knobs, under a 75-minute limit
so that it can show by how much it exceeds 45 minutes and still print
`--time-expanded`'s per-module times.

- **Probe within 45 minutes:** the full crate is built on both sides; this
  section gets one line saying so.
- **Probe over 45 minutes, finished:** a fixed subset is chosen from the
  probe's per-module times: the shared modules (everything outside the
  five controller modules), then controller modules added in the CI's
  order (`vreplicaset_controller` first, the controller the CI job is named
  after, then `vdeployment_controller`, `vstatefulset_controller`,
  `rabbitmq_controller`, `composition`) while the projected total stays
  within 30 minutes. Every module path under the kept modules is passed
  with `--verify-module`; the rest is type-checked, not verified.
- **Probe killed at 75 minutes:** the subset is the shared modules plus
  `vreplicaset_controller`.

In both subset cases this plan is amended (section "Subset", with the
probe's times and the module list) and the amendment is committed and
pushed before the first timed pair. The probe's wall-clock time is
recorded in the notebook; it is not a criterion-4 figure.

## Driver changes

`upgrade_builds` (`experiments/13-upgrade-cost/mining/`, library
`builds/`) has closed lists, so the extension is code, with `.mli` and
fixture tests as before:

1. **`Toolchain.t`:** two constructors, `Verus of string` and
   `Isabelle of string`, and the four versions above in `all`.
   - Verus: the release's x86-linux zip, unpacked in
     `switches/verus-<v>`; the release's Rust toolchain through `rustup`
     with `RUSTUP_HOME` and `CARGO_HOME` under `switches/` (not the shared
     cache's). Neither publishes a digest: the SHA-256 is recorded at first
     download, written into `toolchain.ml` and checked from then on, as
     for Z3 and CVC5.
   - Isabelle: the Linux tarball of Isabelle2025-2, unpacked in
     `switches/isabelle-Isabelle2025-2` (tarball removed after unpacking,
     digest kept); Isabelle2026 reuses the shared cache's unpacked
     distribution read-only, through a symbolic link
     `switches/isabelle-Isabelle2026` (an install step whose result
     exists is skipped), with the digest of the cache's tarball recorded.
     `USER_HOME` points to `switches/isabelle-home` for both versions.
   - `command`: Verus with its directory and `CARGO_HOME/bin` in front of
     `PATH`; Isabelle through its `bin/isabelle`.
   - `probes`: Verus `version.json`, bundled `z3 --version`, `rustc`
     and `cargo` versions; Isabelle `isabelle version` and its `contrib/`
     components (z3, cvc5, veriT).
2. **`Target.all`:** two projects, `anvil` (Verus 0.2026.07.12.0b42f4c,
   0.2026.11.22.1ce6a59) and `afp-regex` (Isabelle2025-2, Isabelle2026),
   with `prepare`, `stale`, `measured`, `probes` as above; the latest
   side's dependency edits through the existing `Edit` module; a variant
   `subset` for Anvil, only if the probe calls for it.
3. **`Failures.format`:** `Rustc` (an `error` line, then
   ` --> <file>:<line>:<col>`) and `Isabelle` (`*** ... (line N of
   "<file>")`), each with fixture tests from recorded log excerpts.
4. **Rows:** one per (project, side) in a new
   `2026-<run-date>-exp-13-builds-df.csv`, same columns as
   `2026-11-19-exp-13-builds.csv`.
5. **Built** on the bench host as in experiment #13 (`dune build` and
   `dune test` with `opam exec --switch <s> --`, never changing the default
   switch), and locally (`dune build @check`, `dune test`) before the run.

About one day of work, inside the "one day per tool" estimate.

## Disk and time budget

**Disk.** 50 GB free on the bench host on 2026-11-26; floor 20 GB, so at
most 30 GB, budgeted at 25 GB under `<bench-workdir>/exp/13-upgrade-builds-df/`:

| Item | Estimate |
| --- | --- |
| Two Rust toolchains with `rustc-dev` | 3.5 GB |
| Two Verus releases | 0.5 GB |
| Cargo registry and git checkouts | 1 GB |
| Two Anvil `target/` directories | 8 GB |
| Isabelle2025-2 (tarball 1.2 GB, removed after unpacking; 2.8 GB unpacked) | 3 GB |
| Heaps of both sides (Collections and Refinement Framework included) | 4 GB |
| AFP 2025-2 sparse checkout, logs | 1 GB |
| Total | about 21 GB |

`df` is checked before each install and preparation; the run stops as
blocked if free space would fall below 20 GB.

**Time.** One run of at most 4 hours of wall clock, long steps under
`nohup` or `tmux`:

| Phase | Where | Worst case |
| --- | --- | --- |
| 1. Build the driver, installs, checkouts, `cargo fetch` | untimed CPUs | 0:30 |
| 2. Verus probe (pinned prepare plus full verify, limit 75 min); meanwhile Isabelle prepare on both sides and Verus latest-side prepare (dependency edits, `verus-tla` repairs) | timed set; untimed CPUs | 1:15 |
| 3. Subset decision, if any, committed | local | 0:05 |
| 4. Isabelle timed pair (2 x 45 min limit; expected about 15 min each) | timed set | 0:40 |
| 5. Verus timed pair (2 x 45 min limit, or 2 x 30 min with a subset) | timed set | 1:00 to 1:30 |
| 6. Ports, final latest rerun if a port completes and time remains, copy back | untimed CPUs | rest |

The worst cases cannot all happen at once (a probe over 45 minutes implies
a subset of at most 30 minutes per side), so phases 1 to 5 fit in 3:40 at
worst. At 3:45 the ports stop where they are and are recorded as
incomplete (errors fixed, errors left). If the Verus latest side fails and
no full rerun fits, criterion 4 is reported as the ratio over the modules
verified on both sides (from `--time-expanded`), labelled as partial.

## Where things live

- Bench host, `<bench-workdir>/exp/13-upgrade-builds-df/`: the driver's
  work directory (`switches/`, `downloads/`, `build/`, `cache/`, `logs/`),
  the driver's source copy and the run scripts. The shared toolchain cache
  (`<bench-workdir>/cache/`: Verus 0.2026.11.02, Rust 1.99.1, Isabelle2026
  and AFP) is only read; the F\* and Rocq installs there are not touched;
  the default opam switch is not changed.
- Repository, branch `exp/13-upgrade-builds-df`: the driver changes in
  `experiments/13-upgrade-cost/mining/`, the appended release rows in
  `experiments/13-upgrade-cost/releases/verus.tsv`, results in
  `lab/results/`, notebook rows in `lab/notebook.md`, section
  "Experiment #13".

## Lab notebook and outputs

One notebook row per run (the probe, each timed pair, each port), each
with a results entry giving the commit of this repository, the commands,
the machine (CPU model, `nproc`, load before and after, CPUs used), the
inputs' revisions, tool and prover versions, `-j`, wall-clock time,
outcome and, for a port, failing files, error categories, patch size and
hands-on time against the time box. Redacted raw logs go with them. In
`lab/results/` (the run date in the names):

- `<date>-exp-13-builds-df.md`, `-builds-df.csv`, `-builds-df-files/`
  (patches, dependency edits, per-module and per-session times);
- `<date>-exp-13-summary-df.md`: experiment #13's summary table with the
  Verus and Isabelle builds cells filled, and an erratum pointer appended
  to `2026-11-19-exp-13-summary.md` (results files are append-only; the
  rows are not rewritten in place), as the experiment #13 corrections did.

## Done-criteria mapping

| Criterion (issue #3, as taken over by issue #25) | Where it is met |
| --- | --- |
| 1. Versions, dates, cadence | Snapshot table above; `verus.tsv` rows appended; 16 Verus releases, 1 Isabelle release crossed |
| 2. Builds and checks unchanged on pinned and latest, with prover versions | Timed pairs (phases 4, 5) and the driver's probes (bundled Z3 of each Verus release; Isabelle's z3, cvc5, veriT) |
| 3. Failing files, error categories, patch, hands-on time within the time box | Ports (phase 6), dependency edits recorded apart |
| 4. Wall-clock latest / pinned ratio | Timed pairs on the timed set, same `-j`; partial ratio over modules verified on both sides if the Verus latest side cannot be completed |
| Summary cells | `<date>-exp-13-summary-df.md` and the erratum pointer |

## Steps

1. This plan; the issue moves to `stage:plan`.
2. Driver changes with their tests (`dune build @check`, `dune test`),
   committed on the branch.
3. Run on the bench host, phases 1 to 6 above; plan amended before the first
   timed pair if the probe calls for a subset.
4. Notebook rows and results; completed summary and erratum pointer;
   results comment on issue #25.

## Risks

- **The Verus latest side fails broadly.** Expected (the mining found proof
  repairs at `aa757c8`, `febab3b`, `2edac69`, `e83ea0f` after this commit),
  and the datum wanted. The port is bounded by the time box and the run cap;
  an incomplete port is a result, recorded with what is left.
- **Two `vstd` versions.** If the `verus-tla` patch does not make cargo
  resolve a single `vstd`, the latest side cannot even build its
  dependencies; that is recorded as a dependency failure, with the edit
  tried, before any proof repair.
- **Dependencies not `Fresh` in the measured run** (cargo-verus may
  re-verify them): timed scope widened to them on both sides, said in the
  notebook.
- **Probe longer than expected.** The subset rule above is fixed now, so
  no decision waits on the maintainer during the run.
- **Isabelle dependency heaps are slow** (Collections and the Refinement
  Framework): built untimed, in parallel with the probe; if they are not
  ready when phase 4 starts, phase 5 goes first.
- **Disk:** 50 GB free, 20 GB floor; checked before each install.
- **Shared bench host:** a timed pair with another process on the timed set,
  or a load average out of line with the other side's, is flagged and
  repeated if time allows, never silently kept.
- **Isabelle2025-2's `contrib/`** may lack a solver Isabelle2026 has (or
  the reverse); recorded as part of criterion 2, not repaired.

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._
