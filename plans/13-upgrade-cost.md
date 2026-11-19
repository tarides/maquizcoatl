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
`lib/everparse/lowparse`. The plan uses those paths. EverParse is
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
  53 stable releases in the window).
- Isabelle: releases 2025, 2025-1, 2025-2 and 2026, from the AFP release
  mirrors. Release dates are taken from the Isabelle website and release
  announcements, with the URL in `source`; the mirrors' creation dates are
  only a cross-check.

Release cadence (criterion 1) is computed from these files: number of
stable releases in the window, and between each project's pinned version
and the latest one. For Lean, the release candidates and the stable
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

- Warblre, Linden: `*.opam` (`rocq-core`, `rocq-stdlib` constraints),
  CI workflow matrices, `dune-project`;
- lean-regex: `regex/lean-toolchain`, `correctness/lean-toolchain`,
  `docbuild/lean-toolchain` (stable at these paths since 2025-01, before
  the window); the lakefiles' dependency revisions (mathlib) are counted
  as pin lines;
- EverParse: `opt/hashes.Makefile` (`FStar_hash`);
- Creusot: `creusot-deps.opam` (Why3 and why3find commits);
- Anvil: CI workflows (Verus release), `Cargo.toml` (`vstd` version),
  `rust-toolchain.toml`.

Two further selections, whose rows are **all** classified by hand
whatever their size, since a message pattern also catches unrelated
commits:

- Rocq projects: units whose messages match
  `rocq|coq|9\.[0-9]|stdlib|compat` (case-insensitive) and that are not
  bumps already;
- Anvil, in its two unpinned periods: units matching
  `upgrade|bump|update|stabiliz|broken proofs|fix proofs|verus|vstd|z3`.

**Grouping.** Consecutive bumps whose pin files reach the same version
form one group (lean-regex `a5c12a8` moves `regex/`, then `96f5cd0` moves
`correctness/` and `docbuild/`, to the same Lean version).

**Commit pins.** EverParse and Creusot pin tool commits, not releases.
A pinned commit is mapped to the first release tag that contains it
(`git merge-base --is-ancestor`, in clones of F\* and Why3). A commit
contained in no release (EverParse sometimes pins an F\* pull-request
branch) gets the label `unreleased`.

**Measure.** For each row: units, date, from-version, to-version, number
of stable releases spanned (so that rows that skip releases can be
normalised: lean-regex skipped v4.30.0 and v4.33.0), and the
`--numstat` of the unit restricted to the configured paths and filtered:
files, lines added, lines removed. Excluded paths: pin files, lockfiles
(`lake-manifest.json`, `Cargo.lock`) and generated files, so that line
counts measure hand-written changes.

**Snapshot mode** (AFP, Why3 gallery). Diff the restricted paths between
consecutive releases (`mirror-afp-2025` to `-2025-1`, and so on; Why3
`1.8.2` to `1.9.0`), with the release mirrors fetched into one local
repository as remotes, at depth 1. Who made each AFP change comes from
the history of `mirror-afp-devel` (`git log -- thys/<entry>` between
release dates, blob-less clone), not from the depth-1 mirrors.

### Tool

An OCaml executable, `upgrade_mining`, in
`experiments/13-upgrade-cost/mining/` (own `dune-project`, like
`experiments/11-perf-baselines/ocaml_bench/`), with a `.mli` per module
and tests. It depends on the standard library and `unix` only, and runs
`git` as a subprocess on local clones. One configuration file per
project, in `experiments/13-upgrade-cost/projects/`, gives the clone, the
commit at D, the window, the pin files and their format, the excluded and
restricted paths, and the message pattern.

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
  subset is chosen before the run and recorded.
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
- **Part A** runs on the bench host `blocksci-bench` (64 threads, 503 GB
  of memory, about 140 GB of free disk on 2026-11-19), shared with the
  argostrace production server and with the other experiments. On
  2026-11-19 at 13:20 UTC, #3 was fuzzing on CPUs 8-31 and 40-63 (a
  campaign of about 110 minutes); #11, done, no longer pinned CPUs 4-7
  and 36-39; #7 runs its timed runs one at a time on one L3 complex.
  - Part A uses at most 8 parallel jobs (`opam --jobs=8`, `make -j8`,
    `lake` with 8 threads), under `nice`, never on a complex where
    another experiment times, and starts only after the CPU set has been
    agreed with the maintainer on the issue.
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
  - `experiments/13-upgrade-cost/projects/`: one configuration per
    project;
  - `experiments/13-upgrade-cost/releases/`: release lists;
  - `experiments/13-upgrade-cost/mining/`, second executable
    `upgrade_builds`: the Part A driver, in OCaml (decision 4 below). It
    installs the toolchains, runs each build and check with its
    `-j`, CPU set and timeout, times it, and writes the build rows and
    logs. Its command construction and result parsing are tested on
    fixtures; the builds themselves are not run by `dune test`;
  - `lab/notebook.md` and `lab/results/`: notebook entries and results.

## Lab notebook

One entry per run. Every entry records the commit of this repository,
the commands, the machine (CPU model, `nproc`, load before and after),
and the inputs' revisions. Part C entries add the window, the
configuration files and the classification decisions. Part A entries
add, per project and side: tool and prover versions (Z3, Alt-Ergo, CVC5),
KaRaMeL revision, `-j`, wall-clock time, outcome, and for a port: failing
files, error categories, patch size, hands-on time against the time box.

## Outputs

In `lab/results/`:

- `2026-11-19-exp-13-<project>-bumps.csv`: one row per bump, group or
  pattern-selected unit, with the class;
- `2026-11-19-exp-13-per-release.csv`: one row per (project, tool
  release reached), lines changed and releases spanned;
- `2026-11-19-exp-13-builds.csv`: Part A, one row per (project, side);
- `2026-11-19-exp-13-summary.md`: the summary table across projects, one
  line per tool on the observed upgrade cost, Verus and Isabelle
  included.

## Steps

1. Fetch the release lists; commit them with the commands used.
2. Write `upgrade_mining` with its tests; `dune build @check` and
   `dune test` pass. `upgrade_builds` is written before step 5.
3. Clone the projects at D; write the configurations; run Part C.
4. Classify; write the Part C notebook entry; post Part C results on the
   issue.
5. Agree the CPU set on the bench host with the maintainer; run Part A,
   one notebook entry per project.
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

1. **CPU set on the bench host** for Part A, to agree with the
   maintainer on the issue before step 5.

## Risks

- **Pin formats vary.** The version parser is tested per format; an
  unparsed bump is reported, never dropped.
- **Large clones** (EverParse, the AFP): blob-less, with sparse checkouts
  of the configured paths; AFP release mirrors at depth 1.
- **Shared bench host**: a run disturbed by another experiment is
  flagged in the notebook and repeated, never silently kept.
