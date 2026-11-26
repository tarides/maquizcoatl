# Experiment #13 follow-up, builds: Verus (Anvil) and Isabelle (AFP regex entries)

Plan: [`plans/13-upgrade-builds-df.md`](../../plans/13-upgrade-builds-df.md)
(decisions 1 to 3 of issue #25). Issue:
https://github.com/tarides/maquizcoatl/issues/25 (follow-up of issue #3).
Parent results: [`2026-11-19-exp-13-builds.md`](2026-11-19-exp-13-builds.md).
Source: maintainer's state-of-the-art report,
https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc (row 13 of "Experiments
before deciding").

## What and why

Experiment #13 built five projects on Rocq, Lean, F\* and Why3, each on its
pinned tool version and on the latest release, and left the Verus (stack
D) and Isabelle (stack F) rows of its summary as "not built (follow-up
issue)". This run fills them with the same method: one sample project
per stack, built and checked on the pinned version and on the latest
release back to back on one CPU set with the same parallelism, then ported
to the latest release, with the port's failing files, error categories,
patch and time recorded (criteria 1 to 4 of issue #3).

- **Verus:** Anvil at `3c95bbb` (2026-07-23), its last commit pinning a
  Verus release (decision 1), on Verus 0.2026.07.12.0b42f4c and on
  0.2026.11.22.1ce6a59, the latest stable release at D' = 2026-11-26.
- **Isabelle:** the six AFP regex entries of AFP 2025-2
  (`mirror-afp-2025-2` at `fa30b560ab75`), on Isabelle2025-2 and on
  Isabelle2026.

## Results

| Project | Pinned (date) | Latest (date) | Releases crossed | Pinned build and check | Latest, unchanged | Edits to build on the latest release | Pinned s | Latest s | Latest / pinned |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Anvil `3c95bbb` | Verus 0.2026.07.12.0b42f4c (2026-07-13), Rust 1.96.0, Z3 4.12.5 | Verus 0.2026.11.22.1ce6a59 (2026-11-23), Rust 1.100.0, Z3 4.16.0 | 16 | ok (911 verified, 0 errors) | fails. Dependency verus-tla `8bb157b`: 1 error (rlimit exceeded, `src/rules.rs:2173`). Anvil: 17 errors in 9 files (894 verified): 15 rlimit exceeded, 2 assertion failures | Dependencies (scripted, recorded apart): `rust-toolchain.toml` 1 line, `Cargo.toml` 2 lines (`vstd` move, verus-tla as a path dependency), verus-tla `Cargo.toml` 1 line, `Cargo.lock` re-resolved (+23 -27, not hand-written). Dependency repair: verus-tla 1 line (`#[verifier::rlimit(30)]`). Anvil port: 9 files, +25 lines (17 `#[verifier::rlimit(100)]`, 2 `#[verifier(spinoff_prover)]`, one 6-line frame assertion) | 817.8 | 954.4 | 1.17 |
| AFP 2025-2 regex entries (`fa30b560ab75`) | Isabelle2025-2 (2026-01-18); z3 4.4.0pre-4, cvc5 1.2.0-1, veriT 2021.06.2-rmx-3 | Isabelle2026 (2026-10-24); z3 4.4.0pre-8, cvc5 1.3.4, veriT 2026.05 | 1 | ok (8 sessions) | fails: 3 sessions finished, 5 unfinished. Entries: Posix-Lexing (2 files, `verit_comp_simplify1` undefined). Dependencies: Deriving (`BNF_LFP_Rec_Sugar.primrec` signature), Efficient-Mergesort (`[code del]` discontinued); after them Formula_Derivatives (`[code del]`, `cut` constant gone) and Show (`addsimps`, `clear_simpset` gone) | 14 files, +15 -16 lines. Entries: Posix-Lexing 2 files 3 lines, Formula_Derivatives 5 files 5 lines (4 `code del`, 1 `hide_const` removed). Dependencies: Deriving 3 files 3 lines, Show 3 files 4 lines, Efficient-Mergesort 1 line | 776.1 | 761.4 | 0.98 |

Times are the measured step, `cargo verus verify --lib` or `isabelle build
-c` of the eight sessions, on the timed set (CPUs 24-27,56-59: four cores
of one L3 complex and their SMT siblings; `cargo -j 8 --num-threads 8`,
`isabelle build -j 2 -o threads=4`), pinned then latest back to back,
`nice -n 10`, after checking that no other process ran on those CPUs. The
ratio is from the final pair, run after the port, with the latest side
ported; the pinned side was run again just before it, so that the pair is
back to back (plan, decision 3). Experiment #13's builds used `-j 4` on
four cores with their SMT siblings idle; these runs use 8-way parallelism
on four cores and their siblings, so the absolute times are not comparable
with experiment #13's, only the ratios.

### All timed runs

| Run | Project, side | UTC start | Wall s | Outcome | Load before / after |
| --- | --- | --- | --- | --- | --- |
| probe (decision 2, untimed for criterion 4) | Anvil, pinned | 07:53:58 | 822.6 | ok | 1.38 / 13.16 |
| pair 1 | AFP regex, pinned | 08:07:53 | 786.7 | ok | 12.24 / 4.77 |
| pair 1 | AFP regex, latest (unchanged) | 08:21:00 | 268.0 | failed (5 unfinished sessions) | 4.77 / 2.61 |
| pair 1 | Anvil, pinned | 08:25:30 | 823.5 | ok | 2.61 / 12.89 |
| pair 1 | Anvil, latest (dependency edits and verus-tla repair only) | 08:39:14 | 1,294.3 | failed (17 errors, 9 files) | 12.89 / 2.67 |
| final | AFP regex, pinned | 09:50:32 | 776.1 | ok | 0.72 / 5.62 |
| final | AFP regex, latest (ported) | 10:03:29 | 761.4 | ok | 5.62 / 2.93 |
| final | Anvil, pinned | 10:16:51 | 817.8 | ok | 2.10 / 4.75 |
| final | Anvil, latest (ported) | 10:30:29 | 954.4 | ok | 4.75 / 3.38 |

The load averages are host-wide: the ports and preparations of this run
ran at the same time on other CPUs (8-23,40-55), never on the timed set.
The one-minute load is therefore not the same on the two sides of a pair
(for example 12.89 before the Anvil latest run, from the port's untimed
verification); the timed set itself was idle at each check
(`ps -eLo user,psr,pcpu,comm`, recorded in
[`timed.times`](2026-11-26-exp-13-builds-df-files/timed.times); one
`sshd` thread at 1.9% at 08:07:53, from the run's own connection). The
probe and the two final pairs show the pinned times repeat within 1.5%
(822.6, 823.5 and 817.8 s for Anvil; 786.7 and 776.1 s for
the AFP sessions).

### Anvil: the port

Patches: [`anvil-port-src.patch`](2026-11-26-exp-13-builds-df-files/anvil-port-src.patch)
(Anvil, hand-written), [`anvil-deps.patch`](2026-11-26-exp-13-builds-df-files/anvil-deps.patch)
(scripted dependency edits), [`anvil-Cargo.lock.diff`](2026-11-26-exp-13-builds-df-files/anvil-Cargo.lock.diff)
(re-resolved by cargo), [`verus-tla.patch`](2026-11-26-exp-13-builds-df-files/verus-tla.patch)
(scripted `vstd` move plus the 1-line repair).

| Error on 0.2026.11.22 | Where | Fix | Category |
| --- | --- | --- | --- |
| rlimit exceeded | verus-tla `src/rules.rs:2173` (`spec_entails_eventually_always_within_dynamic_finite_domain`) | `#[verifier::rlimit(30)]` | dependency, solver resource (Z3 4.12.5 to 4.16.0) |
| rlimit exceeded, 15 functions | `kubernetes_cluster/proof/req_resp.rs`; `vreplicaset_controller/proof/{guarantee.rs, liveness/resource_match.rs (3)}`; `vdeployment_controller/proof/liveness/api_actions.rs`; `vstatefulset_controller/proof/{helper_invariants.rs, liveness/proof.rs (5), liveness/resource_match.rs (2)}`; `rabbitmq_controller/proof/liveness/resource_match.rs` | `#[verifier::rlimit(100)]` on each | solver resource |
| assertion failed | `vdeployment_controller/proof/helper_invariants/proof.rs:1127` (in `..._during_api_server_step`) | `#[verifier::rlimit(100)]` and `#[verifier(spinoff_prover)]` on the function | solver instability (no proof change) |
| assertion failed | `vreplicaset_controller/proof/liveness/resource_match.rs:3114` (`lemma_inductive_current_state_matches_preserves_from_s_to_s_prime`, a function its authors already mark "this proof is flaky") | `rlimit(100)`, `spinoff_prover`, and in the branch of a step of another key a 6-line `assert forall` that every in-flight API-server message of `s_prime` was already in flight in `s`; the failing branch was found by adding one assertion per branch, removed afterwards | proof repair (a lost frame fact) |

No error needed a change of specification or of executable code; 16 of
the 18 errors (verus-tla included) are solver-resource limits, as expected
from the Z3 4.16.0 upgrade that the step crosses. Upstream Anvil did the
same adaptation over four commits after `3c95bbb` (`aa757c8` +187 -947,
26 files, unpinning Verus; `febab3b` +193 -3,047, 17 files, "Proof
stabilization needed for the upgrade to Z3 4.16.0"; `2edac69` +52 -4;
`e83ea0f` +6 -38, a global `--rlimit 100` in CI); the port here was done
without reading them, and its per-function `rlimit(100)` is the local
form of the global `--rlimit 100` that upstream adopted. The diff sizes
are not comparable: upstream also rewrote proofs and removed code.

**Time.** The port started at 07:58 UTC (verus-tla, repaired by 08:02;
Anvil's errors read from 08:27, from an untimed full verification run
started at 08:05 on the untimed CPUs) and the ported crate verified in
full (911 verified, 0 errors, untimed) at 10:02: 2 hours 4 minutes of
elapsed time, by Claude Code, within the half-day time box. About 50
minutes of it (08:57 to 09:47) were an unattended wait, with no port
work, and most of the rest is machine time: four focused re-runs
(`cargo verus focus` on the failing modules or function, 2 to 5 minutes
each) and one full verification (10 minutes). The hands-on share is about
1 hour 15 minutes; it was not timed separately. The run did not need a
second run (decision 3): the port finished in the first one.

**Why the ported latest side is slower.** Both final runs verify the
same 911 items; the SMT time summed over the threads grows from 5,708 s
to 6,578 s (+15%) and the SMT resource count from 2.83e9 to 3.15e9
(+12%), as reported by `--time-expanded`. The difference was not
attributed further: the 19 ported functions may now use up to ten times
Verus's default resource limit, and the solver (Z3 4.12.5 against 4.16.0)
and Verus's encoding both changed; the per-module times are in the run
logs.

**Criterion 4 before the port.** The unported latest run took 1,294.3 s
(ratio 1.57 against 823.5 s), but it stopped on 17 errors, so this is
not a build-time ratio; the final pair gives it.

### AFP regex entries: the port

Patch: [`afp-regex-Isabelle2026.patch`](2026-11-26-exp-13-builds-df-files/afp-regex-Isabelle2026.patch)
(14 files, +15 -16). A first version also changed `[code del]` in five
entries that the eight sessions do not load (Collections, Containers,
Native_Word, Finger-Trees, Word_Lib; 41 lines,
[`afp-port-full.patch`](2026-11-26-exp-13-builds-df-files/afp-port-full.patch));
those edits were reverted and the build checked again before the final
pair.

| Error on Isabelle2026 | File | Fix | Category | Entry or dependency |
| --- | --- | --- | --- | --- |
| `BNF_LFP_Rec_Sugar.primrec`: `false` given for `{verbose: bool}` | Deriving `comparator_generator.ML`, `equality_generator.ML`, `hash_generator.ML`; Show `show_generator.ML` | `primrec {verbose = false}` | Isabelle/ML API change | dependency |
| `[code del]` discontinued ("Bad arguments for attribute code") | Efficient-Mergesort `Efficient_Sort.thy`; Formula_Derivatives `Presburger_Formula.thy`, `WS1S_Formula.thy`, `WS1S_Alt_Formula.thy`, `Examples/WS1S_Alt_Examples.thy`; Show `Show.thy`, `Show_Instances.thy` | `[code drop]` | code generator attribute removed | entry (4) and dependency (3) |
| Undefined constant `cut` | Formula_Derivatives `WS1S_Prelim.thy` (`hide_const (open) cut`) | line removed | HOL library change | entry |
| Undefined fact `verit_comp_simplify1` | Posix-Lexing `Positions.thy` (2), `Extensions/Positions3.thy` | `alethe_comp_simplify1` | SMT fact rename (veriT to Alethe) | entry |
| `clear_simpset`, `addsimps` undeclared | Show `show_generator.ML` | `Simplifier.clear_simpset`, `Simplifier.add_simps` | Isabelle/ML API change (Simplifier) | dependency |

Compared afterwards with AFP 2026 (the shared cache's copy of
2026-11-19): the same 14 files are changed there. 6 of the 14 ported files
are identical to AFP 2026's; the others differ only in form: AFP 2026
deletes the `[code del]` attribute instead of turning it into
`[code drop]` (6 files), and orders the `show_generator.ML` simpset
operations differently (1 file); `WS1S_Prelim.thy` differs by one blank
line. The mining had found 6 lines in Posix-Lexing and 10 in
Formula_Derivatives for this release step; the port here has 3 and 5,
plus 8 lines in the dependencies (Deriving, Show, Efficient-Mergesort),
which the mining did not cover.

**Time.** From 08:27 UTC (errors read) to 09:01 (all eight sessions
built on Isabelle2026, untimed): 34 minutes, by Claude Code, three
rebuild cycles of 5 to 12 minutes; plus the reduction check (09:47,
about 1 minute of work). Within the half-day time box, in the first run.

**What the timed step covers.** The preparation built the sessions that
the eight sessions require as parents (on both sides only `HOL-Library`
needed building), not the AFP entries they import theories from through
`sessions` (Deriving, Show, Efficient-Mergesort, List-Index,
SpecCheck...): Isabelle loads those theories inside the importing session,
so their processing is part of the measured step on both sides. The plan
expected them to be built in the preparation; this does not change the
ratio, since both sides process the same theories.

**Per-session times** (final pair, from the build logs):

| Session | Isabelle2025-2 | Isabelle2026 (ported) |
| --- | --- | --- |
| Regular-Sets | 0:00:41 | 0:00:42 |
| Coinductive_Languages | 0:00:22 | 0:00:18 |
| Functional-Automata | 0:00:23 | 0:00:23 |
| Regex_Equivalence | 0:01:11 | 0:01:11 |
| Posix-Lexing | 0:04:25 | 0:03:20 |
| Formula_Derivatives | 0:04:48 | 0:04:57 |
| Formula_Derivatives-Examples | 0:00:32 | 0:00:36 |
| MSO_Regex_Equivalence | 0:12:39 | 0:12:23 |
| Whole build (`-j 2`) | 0:12:53 | 0:12:37 |

`Coinductive_Languages` (an entry that requires `Regular-Sets`, so built
in the timed step, as the plan says) takes 18 to 22 s; without it the
ratio is the same to two decimals.

## Deviations from the plan

- **verus-tla as a path dependency** instead of a `[patch]` section: the
  driver's `Edit.Replace` cannot add text that contains the text it
  replaces. The effect is the same (verus-tla `8bb157b` checked out next
  to Anvil, with the `vstd` move).
- **AFP checkout:** 23 entries, not the 20 the plan's requirement list
  gave: `isabelle build` reads every session of each `-d` directory, so
  the entries required by any session of a listed entry are needed
  (Show's `Old_Datatype_Show` needs Datatype_Order_Generator; Collections
  and Containers bring CAVA_Automata and Containers). The requirement
  list is printed with `isabelle sessions` (the plan's `isabelle build
  -n` lists nothing and exits 1 when something is to build).
- **Untimed jobs:** the preparations and ports ran with up to 12 jobs
  each, at most three at a time, on CPUs 8-23,40-55 (never on 24-27,56-59
  or on 28-31,60-63).
- **Port work on copies** (`build/anvil-port`, `build/afp-regex-port`),
  so that the first latest runs measured the unported code; the patches
  were then applied to the latest checkouts for the final pairs.

## Provenance

- Repository: branch `exp/13-upgrade-builds-df`, driver at `b946ab8`
  (plan amendments `d416e22`, `d56e08a`), PR #39.
- Machine: the bench host, AMD EPYC 7502P (32 cores, 64 threads), 503 GB,
  Linux 6.8.0-100-generic, Ubuntu 24.04.5 LTS; `nproc` 64.
- Driver: `upgrade_builds` (`experiments/13-upgrade-cost/mining/`) built
  with OCaml 5.4.1 and dune 3.25.0 (opam switch `provers` of the shared
  cache, `opam exec --switch provers --`; the default switch is not
  changed); its tests (38) pass locally (`dune test`).
- Commands: `upgrade_builds install|prepare|run --workdir
  <bench-workdir>/exp/13-upgrade-builds-df/work --cpus C -j N --nice 10
  --table builds-df --out <bench-workdir>/exp/13-upgrade-builds-df/results`,
  through the wrappers `drv.sh` and `timed.sh` (timed runs: `--cpus
  24-27,56-59 -j 8 --timeout 45m`; the probe `--timeout 75m --table
  builds-df-probe`).
- Toolchains: Verus x86-linux zips with SHA-256
  `f6f4f5d0...` (0.2026.07.12) and `c955d595...` (0.2026.11.22), rustup
  1.29.3 (`b1c8cb14...`), Rust 1.96.0 and 1.100.0 (default profile);
  Isabelle2025-2 tarball `a20a507b...` (identifier `89701cf1768e`),
  Isabelle2026 from the shared cache (tarball `858c995b...`, identifier
  `096842708b28`), both with ML system polyml-5.9.2. Full digests in
  `experiments/13-upgrade-cost/mining/builds/toolchain.ml`.
- Inputs: Anvil `3c95bbbe812dfa488ac59b341932f1858d01f343`, verus-tla
  `8bb157b50b6200296d4b04d1302644d269e29443`, `vstd`
  `=0.0.0-2026-07-12-0122` and `=0.0.0-2026-11-22-0344` (crates.io),
  `mirror-afp-2025-2` `fa30b560ab754bfbb7a721ee45a921d4b3c04358`.
- Raw data: [`2026-11-26-exp-13-builds-df.csv`](2026-11-26-exp-13-builds-df.csv)
  (every preparation and run, failed ones included),
  [`2026-11-26-exp-13-builds-df-probe.csv`](2026-11-26-exp-13-builds-df-probe.csv),
  and [`2026-11-26-exp-13-builds-df-files/`](2026-11-26-exp-13-builds-df-files/):
  `timed.times` (CPU checks and load), the logs of the measured runs and
  their `versions.txt` and `steps.csv`, the port logs, the patches.
  Home paths are written `<bench-workdir>` and the host `bench-host`.

## Criteria (issue #3, as taken over by issue #25)

1. **Versions, dates, cadence:** above; Verus 16 stable releases crossed
   (rows appended to `releases/verus.tsv`), Isabelle 1 (Isabelle2026 is
   still the latest release at D', so `isabelle.tsv` gets no row).
2. **Builds and checks unchanged, pinned and latest, with prover
   versions:** both pinned sides build and check; neither latest side
   does unchanged; prover versions in the table (Verus's bundled Z3,
   Isabelle's z3, cvc5 and veriT components).
3. **Failing files, error categories, patch, time:** above; both ports
   finished within the half-day time box in the first run.
4. **Wall-clock latest / pinned:** Anvil 1.17, AFP regex entries
   0.98, same knobs and CPU set on both sides.

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._

Erratum (2026-11-26, after the results review): corrections in
[`2026-11-26-exp-13-builds-df-correction.md`](2026-11-26-exp-13-builds-df-correction.md).
