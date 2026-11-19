# Plan: experiment #13, upgrade cost

Issue: https://github.com/tarides/maquizcoatl/issues/3 (the issue body is
the reference for scope, inputs and done-criteria; this plan says how).
Source: maintainer's state-of-the-art report, section "Experiments before
deciding", row #13: https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc

## Objective

Measure what it costs to keep a verified project building when its prover
moves on, for the tools of the candidate stacks. The experiment refines
the tool selection criterion ("only actively maintained tools qualify")
into "active, and at what cost to follow".

Scope follows the decisions on the issue
(https://github.com/tarides/maquizcoatl/issues/3#issuecomment-7010009861):

1. **Baseline: option C.** Part A builds the latest commit of each of the
   five projects on its pinned tool version and on the latest release.
   Part C mines each project's history for the changes that adapted it to
   a new tool version, and reports the cost per tool release.
2. **Stacks D and F: mining only.** Part C also covers one Verus project
   (stack D) and six AFP entries (Isabelle, stack F). Building sample
   projects for D and F moves to a follow-up issue, to run once #4 and #5
   say which stacks remain.

Part C runs first: it needs no toolchain and no large machine, and it
gives the per-release figures that Part A only samples once.

**Naming.** By decision on the issue, the two halves are now called
**mining** (Part C) and **builds** (Part A); the letters A, B and C
denote only the baseline options. This plan keeps the old names where it
was written with them.

## Snapshot

Date D = 2026-11-19. Releases published after D are ignored. The mining
window is the year before D (2025-11-19 to 2026-11-19) for every project.
Project commits are frozen at D:

| Project | Tool | Repository | Commit at D |
| --- | --- | --- | --- |
| Warblre | Rocq | `LindenRegex/Warblre` | `d4b0e22` (2026-11-10) |
| Linden | Rocq | `LindenRegex/Linden` | `3ef2cb4` (2026-11-11) |
| lean-regex | Lean 4 | `pandaman64/lean-regex` | `32af6f3` (2026-09-30) |
| EverParse CBOR (`lib/everparse/cbor`) | F\* + Pulse | `project-everest/everparse` | `270f5aa` (2026-11-19) |
| Why3 gallery (`examples/`) | Why3 | `why3/why3` on gitlab.inria.fr | tags `1.8.2`, `1.9.0` |
| Creusot | Why3 (development commits) | `creusot-rs/creusot` | `601d978` (2026-11-19) |
| Anvil | Verus | `anvil-verifier/anvil` | `e83ea0f` (2026-10-12) |
| Six AFP entries | Isabelle | `isabelle-prover/mirror-afp-<release>`, `mirror-afp-devel` | one repository per release |

**EverParse path.** The issue names `src/cbor/pulse`. At `270f5aa` that
directory holds only tests and the extracted C and Rust (4 `.fst`
files); the Pulse sources are in `lib/everparse/cbor/spec` (39
`.fst`/`.fsti`) and `lib/everparse/cbor/pulse` (73), on top of
`lib/everparse/lowparse`. The plan uses those paths. They exist only
since EverParse PR 343 (`3d13096c`, 2026-10-18); before it, the same
sources were in `src/cbor/spec`, `src/cbor/pulse` and `src/lowparse`.
The configuration measures both the current and the former paths,
limited to `.fst` and `.fsti` files. The first Part C run measured only
the current paths, so 12 of its 21 F\* bumps were 0 lines by
construction; it was re-run (files named `*-rerun-*`). EverParse is
maintained by the F\* developers, so it follows F\* closely and its
adaptation cost is paid by the tool's own team; the notebook says so when
comparing it with the other projects.

**AFP entries.** `Regular-Sets`, `Regex_Equivalence`, `Posix-Lexing`,
`Formula_Derivatives`, `MSO_Regex_Equivalence` and `Functional-Automata`.
Selection rule: entries of `mirror-afp-2026` whose main object is
regular expressions themselves (matching, lexing, equivalence,
derivatives). Automata-only, Kleene-algebra and language-theory entries
(`Myhill-Nerode`, `Coinductive_Languages`, `Kleene_Algebra`, ...) are left
out. In the AFP, the Isabelle developers adapt entries to each release
themselves, so the cost is real but not paid by the entry's authors.

**Creusot** (decision 3 below) follows Why3's development commits through a
pin in `creusot-deps.opam`: 9 commits touched it in the window, about 5
of them Why3 bumps. It is the stack E implementation route (Rust to
Why3), and the only Why3 user found with a pin history. The Why3 gallery
has no pin: it is always at its own commit, so it only gives one
release-to-release diff.

**Anvil** is the most active Verus project found outside `verus-lang`
(Kubernetes controllers). Its Verus pin history, from its CI workflows:

- `a65d68c` (2025-12-10): pins release 0.2025.11.30;
- `4fbff88` (2026-04-16): switches to Verus HEAD, then `52741e8` to the
  latest release at each CI run;
- `3c95bbb` (2026-07-23): re-pins release 0.2026.07.12;
- `aa757c8` (2026-07-28): unpins again.

So pins give about two rows; from 2026-04-16 to 2026-07-23 and after
2026-07-28, adaptations are found by message (see Part C).

## Tools and versions

Release lists are snapshot data, not logic. They are fetched once with
the GitHub API or `git ls-remote` (commands recorded in the lab notebook)
and committed as `experiments/13-upgrade-cost/releases/<tool>.tsv`
(`version`, `date`, `prerelease`, `source`):

- Rocq: GitHub releases of `rocq-prover/rocq`; latest at D: 9.3.0
  (2026-09-19).
- Lean 4: GitHub releases of `leanprover/lean4`; latest stable at D:
  v4.36.0 (2026-11-16), not v4.37.0-rc1. mathlib has a `v4.36.0` tag.
- F\*: GitHub releases of `FStarLang/FStar`; latest at D: v2026.11.15.
  KaRaMeL has no release; for Part A it comes from the F\* tree
  (submodule), at the revision F\*'s release pins.
- Why3: tags of `why3/why3` on gitlab.inria.fr, dates from the tag
  commits; latest at D: 1.9.0 (2026-10-19), previous 1.8.2 (2025-09-16).
- Verus: GitHub releases of `verus-lang/verus` (rolling, about weekly;
  52 stable releases in the window). The list also has a stable row
  `dependency/singular-4.3.2`, which is not a Verus release; the tool
  still counts it as a series (53), and the Part C summary does not.
- Isabelle: releases 2025, 2025-1, 2025-2 and 2026, from the AFP release
  mirrors. Release dates are taken from the Isabelle website and release
  announcements, with the URL in `source`; the mirrors' creation dates are
  only a cross-check.

Release cadence (criterion 1) is computed from these files: number of
stable release series whose first stable release falls in the window
(Rocq 2, Lean 11, F\* 28, Why3 1, Verus 52, Isabelle 3; patch releases
do not count), and between each project's pinned version and the latest
one. For Lean, the release candidates and the stable
release of one minor version count as one release; pre-releases are also
listed separately.

## Part C: history mining

### Unit of change

The unit is a change on the project's main branch, read along its
first-parent history: a merge commit stands for its whole pull request
(diff `merge^1..merge`), and a direct or squash-merged commit stands for
itself. Proof fixes often sit in commits of a pull request that touch no
pin file (Warblre PR #12 for Rocq 9.2: `18bade0`, `16b599b`, `8a388bf`;
PR #30 for 9.3: `846b5d9`, `28852c2`, `195ed84`, `75cbb59`; Linden
`91d8cd7` "fix proofs for 9.2"), so the pull request, not the commit, is
what gets measured.

### Selection

A unit is a **bump** when the tool version parsed from its pin files at
the end of the unit differs from the one at its start. Touching a pin
file is not enough: CI workflows and opam files also change for other
reasons (Warblre `5a9adbf` "Make the publishing workflow manual", Anvil
`e83ea0f` "Add 100 rlimit to CI"). A version may be a set: for a CI
matrix, "from" and "to" are sets, and the versions reached are the ones
added.

Pin files per project:

- Warblre, Linden: `*.opam` (constraints of `rocq-core`, `rocq-prover`
  and `coq`: an exact `= X` resolves to release X, a range is reported as
  `unresolved:<range>`; `rocq-stdlib` only shows a change), and the CI
  matrix keys `rocq` and `coq`. `dune-project` is not a pin file: its
  `(using rocq X)` is the version of the dune plugin, not of Rocq;
- lean-regex: `regex/lean-toolchain`, `correctness/lean-toolchain`,
  `docbuild/lean-toolchain` (stable at these paths since 2025-01, before
  the window); the lakefiles' dependency revisions (mathlib) are counted
  as pin lines;
- EverParse: `opt/hashes.Makefile` (`FStar_hash`);
- Creusot: `creusot-deps.opam` (Why3 and why3find commits);
- Anvil: CI workflows (`verus_release` and `VERUS_TAG` resolve to
  releases, `verus_commit` only shows a change), `Cargo.toml` (`vstd`,
  an inline git table, only shows a change), `rust-toolchain.toml`.

Two further selections, whose rows are **all** classified (see Manual
classification) whatever their size, since a message pattern also catches unrelated
commits:

- Rocq projects: units whose messages match
  `rocq|coq|9\.[0-9]|stdlib|compat` (case-insensitive) and that are not
  bumps already;
- Anvil, in its two unpinned periods: units matching
  `upgrade|bump|update|stabiliz|broken proofs|fix proofs|verus|vstd|z3`.

Keyword rows do not read pin values (their from and to are empty): the
pins did not change, and reading them would cost one network fetch per
commit in a blob-less clone.

**Grouping.** A bump joins the bump just before it when the two halves
of one upgrade are split over several pin files (lean-regex `a5c12a8`
moves `regex/`, then `96f5cd0` moves `correctness/` and `docbuild/`, to
the same Lean version). The rule is stricter than "same version", which
merged two Anvil bumps four months apart. A bump joins the previous one
only if no other selected unit lies in between, it reaches no new
release, it moves at least one pin file to a version that the previous
bump introduced, and every resolvable pin file it changes ends on
versions that the previous bump reached. A bump that only removes a pin,
only changes opaque pins (`rust-toolchain.toml`) or only drops versions
from a CI matrix keeps its own row.

**Commit pins.** EverParse and Creusot pin tool commits, not releases.
A pinned commit is mapped to the first release tag that contains it
(`git tag --contains`, in clones of F\* and Why3). A commit
contained in no release (EverParse sometimes pins an F\* pull-request
branch) gets the label `unreleased`.

**Measure.** For each row: units, date, from-version, to-version, number
of stable releases spanned (so that rows that skip releases can be
normalised: lean-regex skipped v4.30.0 and v4.33.0), and the
`--numstat` of the unit restricted to the configured paths and filtered:
files, lines added, lines removed. Excluded paths: pin files, lockfiles
(`lake-manifest.json`, `Cargo.lock`) and generated files, so that line
counts measure hand-written changes. Other lockfiles (`flake.lock`,
`package-lock.json`) are not excluded; the classification counts them
apart where they matter. Every measured directory must hold measured
files at the start of the window and at the head (in snapshot mode, in
the first and last release trees); the tool reports any that does not.

**Snapshot mode** (AFP, Why3 gallery). Diff the restricted paths between
consecutive releases (`mirror-afp-2025` to `-2025-1`, and so on; Why3
`1.8.2` to `1.9.0`), with the release mirrors fetched into one local
repository as remotes, at depth 1. Who made each AFP change comes from
the history of `mirror-afp-devel` (`git log -- thys/<entry>` between
release dates, blob-less clone), not from the depth-1 mirrors.
Caveat: an AFP release branch is forked before the Isabelle release date,
so authors and diffs can be misaligned by one release period (seen on
`Formula_Derivatives`). The notebook states it for each affected entry.
For `Formula_Derivatives` the authors were corrected by hand in the
results CSV, and the correction is re-applied after each run, until the
tool attributes AFP authors by content.

**Per release.** Several rows can reach one tool series (a release
candidate then the stable release, several pinned commits of one F\*
release, one row per AFP entry). The per-release table sums the rows by
(project, series reached) and divides by the releases the group spans.
Lines of rows that reach no release, go back to an older series, or
belong to a group that spans no release are reported as unattributed in
the summary. A bump reaches a series only if one of its pins resolves to
a release: a row that changes only opaque pins (Linden `b6396cb`,
Creusot's why3find-only bumps) is unattributed. In the first run such
rows joined the series of the release pins around them.

The tool's table has raw lines. The classified table
(`2026-11-19-exp-13-per-release-classified.csv`) applies one convention
to every tool, stated in the Part C summary:

- adaptation lines of a mixed row come from the counts in its reason,
  not from the rounded share (lines times share only where the reason
  gives no count);
- a keyword row whose classification ties it to a release joins that
  series (Warblre `5d7b76e`, Linden `a8c1859`);
- the median and the mean per release both take one value per stable
  release crossed (a series' adaptation lines divided by its span, once
  per release of the span); the yearly total and the yearly total per
  release of the tool's cadence are given in separate columns;
- spans are the tool's. Two series have none because their starting pin
  is in no release (F\* 2026.10.11, 12 releases by hand) or every pin is
  in one release (Creusot 1.9); they are shown with the hand count as a
  variant. Anvil's pins give no span: its per-release figure is the
  yearly total divided by the 52 Verus releases of the window, and
  Creusot counts as one release step. Both conventions are open
  (decision 5 of the classification file).

### Tool

An OCaml executable, `upgrade_mining`, in
`experiments/13-upgrade-cost/mining/` (own `dune-project`, like
`experiments/11-perf-baselines/ocaml_bench/`), with a `.mli` per module
and tests. It depends on the standard library and `unix` only, and runs
`git` as a subprocess on local clones. The project configurations are
typed OCaml values in `mining/src/projects.ml`, not separate
configuration files: per project, the clone, the commit at D, the pin
files and their format, the excluded and restricted paths, and the
message pattern. The window is given on the command line. The tool
never overwrites result files, and list fields in its CSVs use `; ` as
separator (the first run used a space).

Tests (`dune test`) run on fixtures, with no network and no clone: a
recorded first-parent `git log --numstat`, pin-file contents for each
format (`lean-toolchain`, opam constraints, Makefile hash, CI matrix,
`Cargo.toml`), and a small release list. They check version parsing,
bump detection on version change (and not on file touch), exclusion
filtering, grouping, release spans, and the mapping of a pinned commit to
a release (on a fixture ancestry relation).

### Manual classification

Every bump row above 100 changed lines or 10 files, every
pattern-selected row, and every non-empty snapshot diff gets a class,
decided by reading the diff:

- `adaptation`: only changes needed for the new version;
- `mixed`: adaptation plus unrelated work, with an estimate of the
  adaptation share and the reason;
- `unrelated`: no adaptation.

The classification was done by Claude agents in a background workflow,
one per project group, reading each row's diff in the local clones (and
PR descriptions, release notes or the tool's sources where useful). No
human has spot-checked the shares yet. Each `*-bumps.csv` gets two
columns after `class`: `adaptation_share` (0 to 1) and `reason`, which
gives counts where it can. Bump rows below the threshold were classified
too when cheap (18 rows), since they decide some per-release figures.
After a re-run, the class of a row whose units and lines did not change
is carried over; the other rows are read again.

The Why3 gallery snapshot (one 82,849-line row) was decomposed per
example and status with a one-off shell and awk pipeline, outside
`upgrade_mining`
(`2026-11-19-exp-13-why3-gallery-decomposition.csv`).

Known large bumps: lean-regex `e2e33d6` v4.26.0-rc2 (69 files, +3406
-4293), `153ed60` v4.27.0-rc1 (61 files), `e1600a1` v4.25.1 (35 files),
`cdfe4c8` v4.29.0 (22 files).

### What Part C cannot measure

The notebook says so explicitly:

- diff size is not effort: no hands-on time, no failed attempts, no time
  spent waiting for a dependency (mathlib, rocq-stdlib) to be released;
- a project that skips releases shows one larger diff, normalised by the
  number of releases spanned but not equal to the per-release cost;
- for EverParse and the AFP, the cost is paid by the tool's own
  developers;
- message patterns can miss adaptations folded into feature commits;
  pattern-selected periods are reported apart from pinned periods.

## Part A: builds

For each of the five projects of the issue:

| Project | Side 1 (pinned) | Side 2 (latest release) |
| --- | --- | --- |
| Warblre `d4b0e22` | Rocq 9.2.0 | Rocq 9.3.0 |
| Linden `3ef2cb4` | Rocq 9.2.0, with Warblre `4321379` | Rocq 9.3.0 |
| lean-regex `32af6f3` | v4.34.0-rc1 (`lean-toolchain`) | v4.36.0 |
| Pulse examples (`pulse/share/pulse/examples` at F\* tag v2026.10.25) | F\* v2026.10.25 | F\* v2026.11.15 |
| Why3 gallery | sessions of tag 1.8.2, Why3 1.8.2 | same sessions, Why3 1.9.0 |

- **Pinned version for Rocq.** For both projects, side 1 is the newest
  version of the CI matrix below the latest release: 9.2.0. Each Rocq row
  then measures one release step, like the other tools (decision 2
  below). Warblre's matrix already contains 9.3.0, so its side 2 is
  expected to pass; that is a datum, not a flaw.
- **Pulse sample.** EverParse cannot be used here: its pin at `270f5aa`
  (F\* `c689523`, 2026-11-17) is 24 commits ahead of v2026.11.15, so
  building it on the latest release would be a downgrade. Part A uses
  Pulse's own examples from the previous F\* release, v2026.10.25, built
  with that release and with v2026.11.15 (the issue's selection rule
  allows a sample "taken from an older release" of the tool). This is one
  release step, in line with option C (decision 1 below). EverParse stays
  in Part C.

- **Linden's Warblre.** `linden.opam` pin-depends on Warblre `4321379`
  (2026-07-01), whose CI stops at Rocq 9.2.0. Side 1 uses it. On side 2,
  a failure inside Warblre is recorded, then Warblre is moved to
  `d4b0e22` (which has the 9.3 fixes), and that move counts as dependency
  cost, as the issue requires.
- **Why3 gallery.** The sessions come from tag 1.8.2, the direct
  predecessor of 1.9.0 (the issue suggested 1.8.0; 1.8.2 isolates one
  release step, in line with option C). The whole gallery is replayed
  (every `why3session.xml` under `examples/`) with the prover versions
  each release documents; if the time box does not allow it, a fixed
  subset is chosen before the run and recorded. As run: the fixed subset
  is the sessions named in the gallery's own `reduced_regtests.list`
  files at tag 1.8.2 (11 sessions); the whole gallery (453 sessions) was
  replayed within a 3-hour budget. The prover versions deviate (see
  "Deviations of the builds").
- "Builds and checks" is as defined in criterion 2 of the issue
  (`dune build` plus `rocqchk`; `lake build` in `regex/` and
  `correctness/`; the project's Pulse verification target, identified
  from its Makefiles; `why3 replay`).
- A failure on side 2 starts the porting step of criterion 3, within the
  issue's time box (half a day hands-on per project).
- Criterion 4 (latest/pinned wall-clock ratio): same `-j` on both sides,
  run back to back, `nproc` and load recorded.

## Machine budget

- **Part C** runs on the local workstation: clones and `git` only.
- **Part A** runs on the shared bench host (64 threads, 503 GB
  of memory, about 140 GB of free disk on 2026-11-19), shared with the
  a production service and with the other experiments. On
  2026-11-19 at 13:20 UTC, #3 was fuzzing on CPUs 8-31 and 40-63 (a
  campaign of about 110 minutes); #11, done, no longer pinned CPUs 4-7
  and 36-39; #7 runs its timed runs one at a time on one L3 complex.
  - Part A was first planned with at most 8 parallel jobs, starting
    once the CPU set had been agreed with the maintainer. The decision
    on the issue became: the pipeline picks whichever cores are free at
    run time, away from any timed run, and records the set it used. As
    run: cores 16-31 (four L3 complexes of 4 cores, SMT siblings 48-63
    left idle), one complex per project, `-j 4` per project, at most 16
    jobs at once, every command under `nice -n 10` and `taskset`.
  - Criterion 4 timings run on one L3 complex left idle, pinned with
    `taskset`, never at the same time as another experiment's timed runs.
  - Disk budget: 60 GB under `<workdir>/exp13/` (opam switches for two
    Rocq versions, two elan toolchains and one mathlib cache at a time,
    two F\* releases, two Why3 installs).
- Long jobs run under `tmux`, with logs in `<workdir>/exp13/logs/`.

## Cost

Within the report's "days":

- `upgrade_mining` and `upgrade_builds` with their tests: about one day
  and a half;
- clones, configurations, run and manual classification: about one day;
- Part A: half a day hands-on per project at most (time box), plus build
  time on the bench host.

## Where things live

- Outside the repository, under `<workdir>/exp13/` (not in `upstream/`,
  not in the session scratchpad): `clones/` (blob-less clones of every
  project, of the F\* and Why3 repositories for the commit-to-release
  mapping, of `mirror-afp-devel`, and depth-1 fetches of the AFP release
  mirrors), `switches/`, `build/` and `logs/`.
- In the repository, branch `exp/13-upgrade-cost`:
  - `experiments/13-upgrade-cost/mining/`: the OCaml tool and its tests;
  - `experiments/13-upgrade-cost/releases/`: release lists;
  - `experiments/13-upgrade-cost/mining/`, second executable
    `upgrade_builds`: the Part A driver, in OCaml (decision 4 below). It
    installs the toolchains, runs each build and check with its
    `-j`, CPU set and timeout, times it, and writes the build rows and
    logs. Its command construction and result parsing are tested on
    fixtures; the builds themselves are not run by `dune test`;
  - `lab/notebook.md` and `lab/results/`: notebook entries and results.

## Lab notebook

One entry per run, and for the builds one row per project (criterion
"for each of the five projects"). Every entry records the commit of this repository,
the commands, the machine (CPU model, `nproc`, load before and after),
and the inputs' revisions. Part C entries add the window, the
configuration (`projects.ml` at the recorded commit) and the
classification decisions. Part A entries add, per project and side: tool
and prover versions (Z3, Alt-Ergo, CVC5), KaRaMeL revision, `-j`,
wall-clock time, outcome, and for a port: failing files, error
categories, patch size, hands-on time against the time box.

## Outputs

In `lab/results/`:

- `2026-11-19-exp-13-<project>-bumps.csv`: one row per bump, group or
  pattern-selected unit, with the class; `-rerun-bumps.csv` for the
  re-run;
- `2026-11-19-exp-13-per-release.csv`, `-rerun-per-release.csv`: the
  tool's table, one row per (project, tool series reached), raw lines
  and releases spanned;
- `2026-11-19-exp-13-mining-summary.md`, `-rerun-mining-summary.md`: the
  tool's summary, raw lines;
- `2026-11-19-exp-13-mining.md`, `-classification.md`, `-rerun.md`: run
  provenance, classification notes and decisions;
- `2026-11-19-exp-13-why3-gallery-decomposition.csv`: the gallery
  snapshot per example;
- `2026-11-19-exp-13-per-release-classified.csv`: one row per (project,
  series reached), raw and adaptation lines, releases spanned;
- `2026-11-19-exp-13-builds.csv`: Part A, one row per (project, side);
- `2026-11-19-exp-13-part-c-summary-v2.md` (it replaces
  `-part-c-summary.md`): the summary table across projects, Verus and
  Isabelle included;
- `2026-11-19-exp-13-mining-v3.md` and its CSVs: the mining figures with
  the maintainer's methodology decisions;
- `2026-11-19-exp-13-builds.md`, `-builds-files/`: the builds, patches
  and per-run provenance;
- `2026-11-19-exp-13-summary.md`: the final summary, mining and builds,
  one line per tool;
- `2026-11-19-exp-13-correction.md`, `-correction-2.md`: corrections
  after the maintainer's decisions and the results review.

## Steps

1. Fetch the release lists; commit them with the commands used.
2. Write `upgrade_mining` with its tests; `dune build @check` and
   `dune test` pass. `upgrade_builds` is written before step 5.
3. Clone the projects at D; write the configurations; run Part C.
4. Classify; write the Part C notebook entry; post Part C results on the
   issue.
5. Run Part A on cores the pipeline picks (decision on the issue), one
   notebook entry per project. As run: one notebook row for the five
   projects, then, after the results review, one row per project
   (criterion "for each of the five projects, a lab-notebook entry"),
   appended.
6. Summary table, results comment on the issue, follow-up issue for D and
   F builds, independent review of the results.

## Done-criteria mapping

| Issue criterion | Where it is met |
| --- | --- |
| 1. Versions, dates, cadence | Release lists and Part C, for every project |
| 2. Builds unchanged on pinned and latest | Part A |
| 3. Failing files, patch, time | Part A for the latest release; Part C gives the per-release history |
| 4. Wall-clock ratio | Part A |
| Summary table | Step 6, with Part C's per-release cost per tool, Verus and Isabelle included |

## Decisions taken with the plan

Raised by the plan review, decided by the experiment owner on
2026-11-19:

1. **Pulse sample for Part A**: Pulse's examples from F\* v2026.10.25,
   built on v2026.10.25 and v2026.11.15 (not EverParse, whose pin is
   newer than the latest release).
2. **Pinned version for Rocq**: the newest CI-matrix version below the
   latest release (9.2.0) for Warblre and Linden.
3. **Creusot** is added to Part C (stack E, the only Why3 user with a pin
   history).
4. **Part A driver** in OCaml, next to the mining tool.

## Open points

All closed by decisions on the issue:

1. **CPU set on the bench host**: the pipeline picks free cores and
   records them (cores 16-31 were used).
2. **Normalisation by project size**: raw lines and lines per kLOC are
   both reported (decision of 2026-11-19, 18:06 UTC).
3. **Verus division**: Anvil is divided by the 49 Verus releases of its
   active window (same decision).
4. **Human spot check**: waived (decision of 2026-11-19, 19:29 UTC); the
   results state that the shares of lean-regex `e2e33d6` (0.99), Anvil
   `cc8ab6a` (0.05) and the Why3 gallery (0.006) were estimated by
   Claude agents and not checked by a human. The other open decisions of
   the classification file were taken in the 18:06 decision.

## Deviations of the builds

The builds ([`2026-11-19-exp-13-builds.md`](../lab/results/2026-11-19-exp-13-builds.md))
differ from this plan as follows:

1. **Why3 prover versions.** The plan, then the maintainer's decision,
   asked for each project's pinned prover versions, then each prover's
   latest release. The replays used one installed version per prover on
   both sides (Alt-Ergo 2.6.2, CVC5 1.2.1, Z3 4.13.4), reached through a
   Why3 prover upgrade policy from the about 90 versions recorded in the
   1.8.2 sessions. Accepted by the maintainer, no rerun.
2. **CVC4 replayed with CVC5.** Through the same policy, the five
   recorded CVC4 versions (1.4 to 1.8) were replayed with CVC5 1.2.1, a
   different prover.
3. **Full gallery on two complexes at once.** To fit the 3-hour budget,
   the full gallery's two sides ran at the same time (pinned on cores
   28-31, latest on 16-19), not back to back; its latest / pinned ratio
   is indicative only.
4. **`prover/Prover` stopped.** That session alone would have exceeded
   the budget; it was stopped on both sides, and both drivers were
   stopped at the end of the budget. The comparison covers the 316
   sessions finished on both sides, out of 453.
5. **Reduced list.** The fixed subset is the sessions named in the
   gallery's own `reduced_regtests.list` files (11 sessions), not a
   subset chosen for this experiment.
6. **Two driver fixes during the run**, both committed: F\* archives are
   unpacked with two path components stripped (`24b8223`), and Warblre
   builds `@mechanization/all @engines/all` rather than its default
   targets, whose webpack rules need `npm install` (`6aecf11`).
7. **Parallelism and core set**: `-j 4` per project, up to 16 jobs, on
   cores picked by the pipeline (see "Machine budget"), instead of at
   most 8 jobs on an agreed set.

## Risks

- **Pin formats vary.** The version parser is tested per format; an
  unparsed bump is reported, never dropped.
- **Large clones** (EverParse, the AFP): blob-less, with sparse checkouts
  of the configured paths; AFP release mirrors at depth 1.
- **Shared bench host**: a run disturbed by another experiment is
  flagged in the notebook and repeated, never silently kept.
