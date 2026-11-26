# Plan: experiment #8 follow-up, discriminating lemmas

Issue: [#34](https://github.com/tarides/maquizcoatl/issues/34) (the issue
body is the reference for scope, inputs, tools and decisions; this plan
says how).
Parent: experiment #8, issue #12, plan `plans/08-hard-features.md`, merged
as PR #26 (lab files under `lab/08-hard-features/`, results
`lab/results/2026-11-19-exp-08-*`).
Conventions reused: experiment #9, issue #4, plan
`plans/09-representative-proof.md`, files under
`lab/09-representative-proof/`, comparison in
[this comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7175142784).
Source: maintainer's state-of-the-art report, "Experiments before
deciding", row of experiment #8
(https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

## Objective

Prove two lemmas on experiment #8's semantics
(`lab/08-hard-features/SEMANTICS.md`), each in Rocq (interactive) and in
Verus (SMT), that are large enough to show where SMT automation breaks:

1. **Lemma F over a symbolic subject**: ISO-8859-1 `0xDF` against the
   four spellings of `ss`, at the matcher level, in both pattern
   directions, for every subject, position and fuel above a bound.
2. **Absent desugaring equivalence**: experiment #8's direct absent
   semantics (`AbsRep`, `AbsExp`, the stopper) equals a model of the C
   desugaring built by `make_absent_engine`
   (`upstream/src/regparse.c:2995-3075`), through its code paths. This
   turns `SEMANTICS.md` section 2's design note "Since every branch
   carries its own `rr`, the explicit restores the C performs on
   backtracking are implicit" into a theorem, and confirmed behaviour
   CB-001 (`spec/confirmed-behaviours.md`) into a proof.

Then measure both proofs in experiment #9's units, re-check Verus across
Z3 versions and seeds as experiment #9's run 14 did, and compare with
experiment #9's table.

## Decisions folded in

From the issue body, section "Tools" (maintainer decision 2026-11-25,
[comment](https://github.com/tarides/maquizcoatl/issues/34#issuecomment-7163945679)
and the one after it): **Rocq is the interactive tool and Verus the SMT
tool.** Pulse is out of scope.

From the issue body, section "Decisions" (raised by the issue review,
[comment](https://github.com/tarides/maquizcoatl/issues/34#issuecomment-7192977861);
answered 2026-11-26 by the maintainer, each with the recommended option):

1. **Done-criteria and measurement record: (a).** Experiment #9's
   criteria 1-4 adapted (see "Done-criteria mapping").
2. **Constructs of lemma 2: (ii).** `AbsRep`, `AbsExp` and the stopper;
   the range clear is proved in a line or named out of scope.
3. **Equality under fuel: (i).** For every fuel on one side there is a
   fuel on the other with equal results, in both directions, on a
   monotonicity lemma adapted from experiment #9's `ProofSem`, with
   `occ`'s inner fuel as a parameter. Fuel adequacy stays later work.
4. **Model of the C desugaring: (i).** A state-threaded matcher,
   validated against the C library on the 11 absent cases plus new cases
   exercising the restores, before any proof. Its faithfulness is checked
   only against that corpus.
5. **Run budget: (i).** 3-5 runs of at most 4 hours each; experiment
   #9's stop rule applies.
6. **Lemma F: (c).** The scoped lemma F is the done-criterion; the
   one-level fold statement for every literal `w` is attempted if time
   remains, and the outcome is reported either way.

Nothing else is decided here. A question that comes up during a run and
is not covered by one of these answers is raised on issue #34, not
answered by the pipeline.

## Where things live

- **Bench host** (all runs). `<bench-workdir>/cache/` (written `<cache>`)
  is the shared toolchain cache of experiments #6-#9, used unchanged
  through `<cache>/env.sh` and `<cache>/verus-env.sh`; no toolchain is
  installed or upgraded. `<bench-workdir>/exp/08-discriminating-lemmas/`
  (written `<exp>`): a clone of the branch with `upstream/` at `f95747b`
  (read only, never built inside), per-tool build directories
  (`<exp>/build/<tool>/`) and raw outputs (`<exp>/out/<run-id>/`). The
  two C builds of experiment #8 (`<bench-workdir>/exp/08-hard-features/build/onig-debug/`
  and `.../onig-asan/`, both `f95747b`) are reused read-only through
  experiment #8's `cases/run-cases.sh`; if either is missing, run 1
  rebuilds it under `<exp>/build/` with
  `lab/08-hard-features/setup.sh onig`, and says so in the notebook.
- **Workstation.** `<workdir>` is the work directory outside the
  repository; the branch's worktree is
  `<workdir>/wt/08-discriminating-lemmas`. Raw outputs are copied back to
  `<workdir>/e08b/out/` before selection. No check runs on the
  workstation; if the bench host is unavailable the run waits.
- **Repository** (branch `exp/08-discriminating-lemmas`),
  `lab/08-discriminating-lemmas/`:
  - `LEMMAS.md`: the shared design both tools transcribe: the two
    statements, the desugaring function, the state-threaded matcher, the
    lemma plan, all with `upstream/` citations;
  - `cases/absent-restore.tsv`: the new absent cases, in experiment #2's
    eight-column format (`probes/README.md`), run on C with experiment
    #8's `run-cases.sh` and `join.py`;
  - `rocq/`: `Fold.v` and `Absent.v` copied from
    `lab/08-hard-features/rocq/` (unchanged except where a definition
    must take the fuel or `occ`'s inner fuel as a parameter, recorded per
    change), plus `FoldProof.v`, `Desugar.v` (desugaring and
    state-threaded matcher), `AbsentMono.v` (fuel monotonicity),
    `AbsentProof.v` (lemma 2), `Cases.v` (agreement on the corpus by
    computation);
  - `verus/`: the same split as a crate (`lib.rs`, `fold.rs`,
    `fold_proof.rs`, `absent.rs`, `desugar.rs`, `absent_mono.rs`,
    `absent_proof.rs`, `cases.rs`), starting from
    `lab/08-hard-features/verus/{fold,absent}.rs`;
  - scripts adapted from experiment #9 (`lab/09-representative-proof/`,
    on `main`): `timed.sh`, `axioms.sh`, `brittle.sh` (with
    `brittle_verus.py` unchanged), `loc.py`, `lemmas.py` unchanged,
    `provenance.sh`, `pins.json`, `effort.tsv`. The three shell scripts
    hard-code experiment #9's file lists, experiment directory and
    theorem name; the adaptation changes only those (file lists, `EXP`
    path, `Print Assumptions` targets, `CPUS` default) and is a commit of
    its own, so the diff against experiment #9's scripts is reviewable;
  - build output is gitignored (`*.vo*`, `*.glob`, `target`, caches).

Scripts take `<bench-workdir>` from `BENCH_WORKDIR` and never print
absolute paths, host names or addresses.

## Tools and versions

Checked read-only in `<cache>` on the bench host on 2026-11-26 while
writing this plan, identical to experiment #9's `pins.json`; re-recorded
by `provenance.sh` at run 1:

| Tool | Version | Role |
|------|---------|------|
| opam | 2.6.1, root `<cache>/opam` (default switch left as is) | `opam exec --switch provers --` only |
| Rocq | rocq-core 9.3.0, rocq-stdlib 9.2.0 (switch `provers`, OCaml 5.4.1) | interactive tool |
| Verus | 0.2026.11.02.8bf68ee, release profile (Rust toolchain 1.99.1) | SMT tool |
| Z3 for Verus | 4.16.0, bundled (`<cache>/verus/z3`) | default solver |
| Z3, other versions | 5.3.0 and 4.15.3 from the F\* 2026.11.15 release (`<cache>/fstar/lib/fstar/z3-*`) | brittleness only, through `-V no-solver-version-check` and `VERUS_Z3_PATH` |
| GCC, CMake | system (13.3.0, 3.28.3 at experiment #9) | C library, harness |
| Python | 3.12 (system, `-I`) | scripts |

A newer release of a tool appearing before a run does not change the pin
(comparability with experiment #9); it is noted.

## Lemma 1: lemma F over a symbolic subject

On `m` of `lab/08-hard-features/rocq/Fold.v` and `verus/fold.rs`, under
IGNORECASE, for every subject `s`, position `i` and fuel `f >= k` (`k` a
fixed small bound, fixed in `LEMMAS.md`; written `S (S ... f)` in Rocq and
with `reveal_with_fuel` on the variable fuel in Verus):

- (F1) `i + 2` is in `m s f [R (ILit [0xDF])] i` iff `s[i..i+2)` is one
  of `ss`, `SS`, `sS`, `Ss`;
- (F2) for each such spelling `w`, `i + 1` is in `m s f [R (ILit w)] i`
  iff `s[i] = 0xDF`.

The constant `fuel := 1000` never appears in a statement or a proof
(experiment #8's two Rocq failures,
`lab/results/2026-11-19-exp-08-absent.md`). `unravel` is applied to a
concrete literal, so the proof is an unfolding of `unravel` and of a few
steps of `m`, then a case split on `nth_error s i` and
`nth_error s (i+1)`; `prefix_at` is related to `nth_error` by a small
lemma.

**Stretch (decision 6, attempted if time remains in the run that closes
F1-F2):** the one-level fold statement for every literal `w`: `e` is in
`m s f [R (ILit w)] i` iff `s[i..e)` is a concatenation of one
alternative per segment of `unravel w`, written as a declarative
relation in `LEMMAS.md`, by induction on `w` (through `unr`). The
outcome (closed, partial with the open sub-lemmas, or not attempted) is
reported in both tools' entries either way.

## Lemma 2: absent desugaring equivalence

### The desugaring (written once in `LEMMAS.md`)

A new AST `dre` extends experiment #8's absent-free core (`Eps`, `Chr`,
`Any`, `AnyO`, `Seq`, `Alt`, `Star`) with the gimmicks the C parser
emits, and `desugar : re -> dre` follows `upstream/src/regparse.c` at
`f95747b`:

- `(?~absent)` (`AbsRep a`), simple path
  (`make_absent_tree` enters it at `:3317-3328`;
  `make_absent_tree_for_simple_one_char_repeat`, `:3252-3296`):
  `SaveRR id1; Engine(id1, a, AnyO, non-possessive); UpdRRFromStack id1`;
- `(?~|absent|\O*)` (`AbsExp a (Star AnyO)`; `\O*` is rejected by
  `is_simple_one_char_repeat`, `:3215-3236`), general path
  (`:3347-3384`): `SaveRR id1; SaveS id2; Engine(id1, a, AnyO, possessive);
  UpdSFromStack id2; e; Tail(id1)`; the plan covers every `AbsExp a e`
  with `e` absent-free, not only `\O*`;
- the stopper `(?~|absent)` (`Stopper a`): the general path without the
  tail (the four-node list, `:3371-3373`), the engine's alternative
  flagged `SUPER`;
- `Engine(id, a, step, poss)` = `make_absent_engine` (`:2995-3075`):
  `Alt (Star' ((SaveS j; a; UpdRRFromS j; Fail) | step) [Atomic if poss])
  (UpdRRFromStack id; Fail)`;
- `Tail(id1)` = `make_absent_tail` (`:3078-3124`):
  `SaveRR id3; Alt (UpdRRFromStack id1) (UpdRRFromStack id3; Fail)`;
- range clear `(?~|)` = `make_range_clear` (`:3127-3183`):
  `SaveRR id; Alt (RRInit) (UpdRRFromStack id; Fail)`, flagged `SUPER`.

Ids are allocated in the order the C allocates them; the model only
needs them distinct per construct, and `LEMMAS.md` states that.

### The state-threaded matcher (decision 4)

`md` mirrors `match_at` on these nodes, not experiment #8's per-branch
`rr`:

- the state is the right-range register `rr` (a local of `match_at`,
  `upstream/src/regexec.c:3189`, set only by `OP_UPDATE_VAR`,
  `:4548-4580`, and `INIT_RIGHT_RANGE`, `:2729`; read by `DATA_ENSURE`,
  `:2725-2727`) and a save store (the `STK_SAVE_VAL` entries of the
  backtrack stack, looked up by `STACK_GET_SAVE_VAL_TYPE_LAST_ID`,
  `:2211-2230`: the last entry of the id);
- the save store lives on the backtrack stack, so it is per branch; the
  register is not restored by backtracking: the results of `md` carry
  `(end, rr, saves)` and the alternative tried next starts from the
  register value the previous alternative failed with (`md` returns the
  ordered result list together with the register at final failure);
- `Atomic` (`BAG_STOP_BACKTRACK`) keeps the first result of its body
  and drops the body's other branches; register changes made in the body
  survive the cut, and so do its saves: `STK_SAVE_VAL` (`0x0600`,
  `regexec.c:1269`) is not in `STK_MASK_TO_VOID_TARGET` (`0x100e`,
  `:1276`) that `STACK_TO_VOID_TO_MARK` (`:2391`) voids; both facts are
  re-checked in run 1 and cited in `LEMMAS.md`;
- `SUPER` changes only which entries a cut voids; the direct AST has no
  atomic group or lookaround around an absent construct, so `SUPER` has
  no effect on the patterns of the lemma; `LEMMAS.md` states this as a
  scope condition;
- fuel: `md` takes a fuel, and `occ` (experiment #8's `mb fuel [R a]`)
  takes its inner fuel as a parameter `g` in both matchers (decision 3).

### Validation before any proof (run 1)

`md (desugar r)` and experiment #8's `m r` (with `occ`'s fuel as a
parameter) are run on the 11 cases of
`lab/08-hard-features/cases/absent.tsv` and on new cases in
`cases/absent-restore.tsv`, all also run on the Debug and ASan builds of
the C library. The new cases exercise each restore at least once:

- a continuation fails after an `AbsRep` and a later alternative must see
  the right range from before the absent (for example
  `(?:(?~abc)z|.*)` on `xabcyy`);
- the same after an `AbsExp` (tail restore through `id1`) and after a
  stopper (engine restore through `UpdRRFromStack id; Fail`);
- backtracking into `exp` of `(?~|abc|exp)` where `exp` has several
  matches (tail's second branch re-installs the cut through `id3`), for
  example `(?~|abc|x*)y` on `xxxabcy` and `(?~|abc|(?:x|xx)*)z`;
- the range clear backtracked over (`(?~|abc)(?:(?~|).*z|y)`-shaped);
- `AbsExp` with an `exp` that is not `\O*`, and an absent pattern that
  matches the empty string.

Run 1 fixes the exact list (at least 10 new cases) and their C results.
Agreement is required on every case for C, `m` and `md`, in Rocq (by
`vm_compute` in `Cases.v`, at a fuel above what the cases need) before
any proof starts, and in Verus (by `assert(...) by (compute)` or an
`exec` mirror, as experiment #8 did) before Verus's proofs. A
disagreement between C and the direct semantics on a new case is a
deviation-log candidate: it is raised on issue #34 with the case, and the
pipeline stops for that construct until the maintainer answers. A
disagreement between `md` and C is a bug in the model and is fixed first.
The model's faithfulness to C is established only on this corpus; the
results and the comparison say so.

### The statement (decisions 2 and 3)

For every absent-free `a` and `e`, every pattern `r` built from the core,
`AbsRep`, `AbsExp`, `Stopper` (and `RClear`, see below) with no absent
construct inside an absent pattern (nested absent is out of scope, as in
experiment #8), every subject `s`, position `i` and continuation:

- (2a) for every fuel `f` (and inner fuel `g`) at which the direct
  matcher returns its list, there is a fuel `f'` at which `md` on
  `desugar r` returns a list whose ends are the same, in the same order;
- (2b) the converse, from `md` to `m`;
- with fuel monotonicity on both sides: once a matcher has returned a
  complete (not out-of-fuel) result list at some fuel, every larger fuel
  returns the same list. The matchers are changed, if needed, to return
  `option (list _)` (`None` for out of fuel), as experiment #9's
  `compute_tree` does (`lab/09-representative-proof/rocq/ProofSem.v`,
  `ct_mono`, `ct_det`), so that "equal results" is about complete lists;
  the change is recorded and the 11 cases are re-run after it.

The register value seen by the continuation is related by an invariant:
after a desugared absent construct the register equals the direct
semantics' `rr` for that branch. That invariant, stated over the save
store's last entries, is the core of the proof.

**Range clear (decision 2):** its desugaring has the same restore shape
as the stopper's. It is included as one more case of the induction if it
closes in a few lines in each tool; otherwise `LEMMAS.md` and the
results name it out of scope, with the reason.

### Lemma plan (shared, in `LEMMAS.md`)

(a) core lemmas: `m` and `md` agree on absent-free patterns (the register
is never written); (b) fuel monotonicity and determinism for both
matchers (after `ProofSem`); (c) the scan: the engine's possessive or
greedy scan with `SaveS j; a; UpdRRFromS j; Fail` leaves the register at
`cut a i rr` (`occ` at the inner fuel `g`) and restores nothing else;
(d) `AbsRep`: the non-possessive scan yields the ends `[c, ..., i]` in
that order, then the restore; (e) `AbsExp`: `e` under the cut, then the
tail's two branches; (f) stopper; (g) the main theorem by induction on
the continuation and the fuel; (h) range clear, if kept.

## Approach and runs

Each run is one Claude Code session of at most 4 hours of wall clock on
the bench host, launched one by one by the maintainer, ending with its
notebook entries and a push to the branch. Nothing starts automatically.
A run that ends early leaves the rest to the next run in the list.

| Run | Content | Done when |
|-----|---------|-----------|
| 1 | Provenance; `LEMMAS.md`; new absent cases on both C builds; Rocq definitions (`desugar`, `md`, fuel parameters, `option` results) and `Cases.v` agreement; scripts adapted | C, `m` and `md` agree on all 11 + new cases in Rocq; case count reported |
| 2 | Rocq proofs: lemma F (F1, F2), lemma 2 (a)-(g), range clear (h) or named out; stretch of decision 6 if time remains; `axioms.sh rocq`, `timed.sh rocq`, `loc.py`, `lemmas.py` | `Print Assumptions` closed for both main lemmas; measurement entry |
| 3 | Verus definitions, agreement on the corpus, proofs of both lemmas, `axioms.sh verus`, `timed.sh verus`, `loc.py`, `lemmas.py` | `0 errors`, `--no-cheating` clean, scan clean; measurement entry |
| 4 | Verus brittleness (`brittle.sh verus`); comparison against experiment #9's table; comparison comment on issue #34 after the maintainer's review | every (version, seed) result recorded; comparison posted |
| 5 | Reserve: continues whichever tool's proofs are still open after its run | as runs 2 or 3 |

**Stop rule (experiment #9's, under decision 5).** A tool gets at most
three proof runs. If its lemmas are still open after the third, or when
the five runs are spent, whichever comes first, the pipeline stops that
tool, records the open lemmas (with their statement and the last error)
in the notebook, and asks the maintainer on issue #34 (more runs, or
report as is). The reserve run 5 counts as a proof run of the tool it
continues; if both tools close in runs 2 and 3, there is no run 5.

The draft PR is this plan's PR; it stays a draft through the runs and is
marked ready only after the comparison is posted, no decision is open,
and the maintainer agrees.

## Measurements (decision 1)

Per tool, in experiment #9's units and with experiment #9's scripts
adapted:

- **Axiom/admit report** (`axioms.sh`): Rocq `Print Assumptions` on
  `sharp_s_sym` (F1-F2 together) and `absent_desugar_eq` (lemma 2),
  expected "Closed under the global context", plus the source scan
  (`Admitted`, `admit`, `Axiom`, `Parameter`, `Conjecture`, `Hypothesis`,
  `Abort`); Verus full crate check (`0 errors`), a second one with
  `--no-cheating`, and the scan (`assume`, `admit`, `external_body`,
  `verifier::external`, `assume_specification`,
  `exec_allows_no_decreases_clause`, `no_verify`, `rlimit`). Raw output
  saved and quoted in the notebook.
- **Agreement**: the case table (C Debug, C ASan, `m`, `md`) per tool.
- **Effort**: failed checks and failing invocations (both, as experiment
  #9's M4 table names them), `effort.tsv` per-lemma attempts, an
  `invocations.tsv` per proof run with UTC timestamp and the SHA-256 of
  the compiled source (experiment #9 from run 10), first and last proof
  compile time, session wall clock, human interventions with a one-line
  reason each.
- **Size**: `loc.py` lines (spec, proof, cases), split into the reused
  experiment #8 definitions, the new definitions (`desugar`, `md`) and
  the proofs.
- **Lemmas**: `lemmas.py` count and automatic share (experiment #9's
  definitions: Rocq one automation tactic; Verus empty `proof fn` body).
- **Check time**: `timed.sh`, three clean full checks, median and
  spread, peak RSS, user and system time, load average before each
  check; Verus on `--num-threads 7` as experiment #9.
- **Verus brittleness** (experiment #9's run 14): Z3 4.16.0 (bundled)
  with the default seed and seeds 1-10; Z3 5.3.0 and 4.15.3 through
  `-V no-solver-version-check` and `VERUS_Z3_PATH`, each with the
  default seed and seeds 1-10, reported separately (unsupported
  configuration); `--rlimit` left at the value the proof was written
  with; every failure recorded with the failing function and its share
  of the rlimit, from `brittle_verus.py`'s per-function table; the
  largest rlimit share per function also for the passing checks, since
  margin is the figure experiment #9 compared (11.3% under 4.16.0, 34%
  under 5.3.0). 33 checks in all.
- **Comparison**: one table, experiment #9's columns (proof effort in the
  named units, lines, check time, automatic share, brittleness and worst
  rlimit share, agreement), with experiment #9's Rocq and Verus rows
  beside this experiment's, a short verdict per tool and per lemma, and
  the stretch outcome. It states that the desugaring model is checked
  only against the corpus and that fuel adequacy is not covered.

## Machine budget

Bench host (AMD EPYC 7502P, 64 threads), shared with other accounts'
work and other experiments:

- **Timed checks** (`timed.sh`, `brittle.sh`, the timed part of
  `axioms.sh`): one at a time under `flock <exp>/timed.lock`, pinned with
  `taskset -c 24-27,56-59` (one L3 complex, assigned to issue #34;
  passed as `CPUS`, since experiment #9's scripts default to
  28-31,60-63), `/usr/bin/time -v`, 16 GB cgroup memory cap
  (`systemd-run --user --scope -p MemoryMax=16G`), the load average and
  the busy share of the pinned CPUs recorded before each check (a check
  with the pinned CPUs busy above 10% is rerun when they are idle).
- **Untimed work** (interactive checks while writing proofs, case runs,
  `vm_compute` agreement): at most 4 parallel jobs under `nice -n 10`,
  `taskset -c 8-19,40-51`, never on 28-31,60-63 and never on 24-27,56-59
  while a timed check runs; the free CPUs are checked with `lscpu -e` and
  `ps -eLo psr,pcpu` at the start of each run.
- **Expected machine time**: minutes. Every experiment #8 file checked
  under 3.5 s and experiment #9's whole Verus crate in 5.3 s; 33
  brittleness checks of a crate of that size take well under an hour.
  The cost of the experiment is session time.
- **Disk**: 41 GB free on the bench work directory on 2026-11-26; floor
  20 GB. Budget at most 2 GB under `<exp>`: the clone with `upstream/`
  (under 0.5 GB), Rocq and Verus build directories (`<exp>/build/`, a
  few MB per check, about 50 checks), raw outputs (under 0.5 GB). Free
  space is checked with `df` before each run and before the brittleness
  series; under 20 GB the run stops and reports.
- No installation, no opam root upgrade, no change of opam's default
  switch; every opam command is `opam exec --switch provers -- ...` with
  `OPAMROOT` from `<cache>/env.sh`.

## Lab notebook

With the lab-notebook skill: one index line per recorded entry in
`lab/notebook.md`, entries `lab/results/<date>-exp-08-lemmas-<topic>.md`
(append-only), raw data in `lab/results/<date>-exp-08-lemmas-raw/`.
Planned entries:

1. provenance: hardware, OS, tool and Z3 versions, CPU sets, script
   commit, the experiment #8 C builds reused (run 1);
2. cases: new case list with C results on both builds, agreement table
   of C, `m` and `md` in Rocq (run 1);
3. Rocq: per proof run, lemmas closed, attempts, interventions; at the
   end, axiom report, lines, check time, automatic share, stretch
   outcome (run 2, and run 5 if used);
4. Verus: the same, plus agreement on the corpus (run 3, and run 5 if
   used);
5. Verus brittleness: 33 checks with per-function rlimit shares, and the
   refusal of a non-bundled Z3 without `-V no-solver-version-check`
   recorded once (run 4);
6. comparison and verdicts (run 4).

Deterministic re-runs (same commit, same inputs) are not kept twice;
seed and solver-version runs are data and are kept. The maintainer
decides what is recorded.

## Outputs

- `lab/08-discriminating-lemmas/` (design, both developments, cases,
  scripts).
- The notebook entries above.
- `spec/confirmed-behaviours.md` CB-001: its Limits line (which names
  issue #34 as the open follow-up) gets a pointer to the result once
  lemma 2 is closed in at least one tool; the entry's claim is not
  rewritten. `spec/deviations.md` changes only after a maintainer answer
  on a deviation candidate.
- The comparison comment on issue #34, and this draft PR.

## Done-criteria mapping

Decision 1 adapts experiment #9's criteria 1-4 (and 5 as the
comparison):

| Criterion | Evidence | Run |
|-----------|----------|-----|
| 1. Both lemmas machine-checked in Rocq and Verus, no `admit`/`assume` | `axioms.sh` output per tool, quoted in the notebook; scoped lemma F (F1, F2) and lemma 2 for `AbsRep`, `AbsExp`, stopper (range clear in or named out) | 2, 3 (5) |
| 2. The desugared model agrees with C on the 11 absent cases plus the new ones | agreement table (C Debug, C ASan, `m`, `md`) per tool, before any proof | 1, 3 |
| 3. Measurement record in experiment #9's units | `effort.tsv`, `invocations.tsv`, `loc.py`, `lemmas.py`, `timed.sh` (median of three) | 2, 3 |
| 4. Verus brittleness as experiment #9's run 14 | 33 checks, failures with rlimit shares, versions reported apart | 4 |
| 5. Comparison against experiment #9's table | comment on issue #34 | 4 |
| Decision 6 stretch | reported closed, partial or not attempted, per tool | 2, 3 |

## Risks

| Risk | Effect | Mitigation |
|------|--------|------------|
| The state-threaded model does not match C on a new case | lemma 2 would prove a wrong model | validation before any proof (run 1); fixed first; faithfulness stated as corpus-checked only |
| C and the direct semantics disagree on a new restore case (for example a range clear backtracked over) | lemma 2 false for that construct | raised on issue #34 as a deviation candidate; that construct waits for the maintainer; the others proceed |
| Fuel equality is awkward: the desugared side spends more steps per absent | (2a)/(2b) stall | existential fuel on each side (decision 3) and monotonicity first; fuel arithmetic kept in lemmas, never a constant |
| Rocq: kernel unfolds a large fuel at `Qed` (experiment #8) | slow or failing checks | no constant fuel in any statement; `Cases.v` computations by `vm_compute` only, in their own file |
| Verus: the `occ`/`cut` scan with a symbolic register needs many unfoldings | rlimit failures, the experiment's target | recorded as data (attempts, rlimit shares); a split into smaller `proof fn`s is the first remedy, raising `rlimit` the last, and every `rlimit` attribute is reported by the scan |
| Verus: own list type and large encodings (experiment #8) | more lines | reuse experiment #8's `verus/absent.rs` types; lines split into reused and new |
| Proofs exceed three runs for a tool or five in total | done-criterion 1 unfinished | stop rule: record open lemmas and ask |
| Stretch lemma consumes the proof run | scoped lemma F unrecorded | stretch only after F1-F2 and lemma 2 are closed in that tool |
| Bench host load from other work | noisy times | lock, pinning to 24-27,56-59, busy-share check, rerun when idle |
| Disk falls under 20 GB | run stops | `df` before each run and before brittleness |

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._
