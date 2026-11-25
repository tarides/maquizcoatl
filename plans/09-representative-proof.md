# Plan: experiment #9, representative proof

Issue: [#4](https://github.com/tarides/maquizcoatl/issues/4) (the issue
body is the reference for scope, inputs, measurements and done-criteria;
this plan says how).
Source: maintainer's state-of-the-art report, "Experiments before
deciding", row of experiment #9, and stacks A to G in "Option matrix and
open questions" (https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

## Objective

In each of the three tools the maintainer selected, Rocq (stack A),
F\* + Pulse (stack C) and Verus (stack D), prove that a backtracking VM
in the style of `match_at` (`upstream/src/regexec.c:3068`), run on the
bytecode produced by a compiler for the fragment, agrees with a
reference semantics for every pattern of the fragment (literals,
concatenation, `|`, greedy `*`, plain capture groups), every subject and
every start position: same match or no match, same match end, same span
for every capture group. Run both on the upstream test cases of the
fragment against the C library, then measure what the proof cost:
effort, size, check time, share of automatic lemmas, and, for F\* and
Verus, SMT brittleness across solver versions and seeds. End with a
comparison table across the three tools, posted on the issue.

## Decisions folded in

From the maintainer's
[comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7022935327)
(option (a): the maintainer picks the tools once experiments #4 and #5
have closed) and the pick in
[this comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7133794658),
recorded in the issue's Decisions section:

1. **Tools: Rocq, F\* + Pulse, Verus.** Two SMT-based tools, so
   done-criterion 4 compares two tools.
2. **Lean 4 + Aeneas (stack B) not selected**, because of Aeneas (no
   unsafe Rust, interior mutability or raw pointers; 122 trusted lines
   and an "external, unknown definitions" warning in experiment #5;
   toolchain pinned to a Rust nightly and a Lean release candidate; Rust
   route overlapping Verus's). It can be reconsidered if a later
   experiment changes the Aeneas picture; this plan has no Lean row.
3. **Why3 (stack E) and Isabelle/HOL (stack F) not selected.** The
   Lean, Why3 and Isabelle checks of done-criterion 1 do not apply.
   Issue #30 (the Isabelle-LLVM follow-up of experiment #5, listed as
   "after experiment #5 or with experiment #9") is therefore not part
   of this plan.
4. **Empty-iteration rule: the spec's current rule, DEV-008.** First
   decided as DEV-003's rule (option (a) of the plan review's question,
   [comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7134436728)).
   Experiment #6's milestone 2 (issue #28, run 2) then found DEV-003's
   literal rule exponential and not observably equal to upstream, and
   DEV-008 superseded it: the empty-iteration check compares only the
   groups that some backreference of the pattern names, in every loop,
   bounded or not. The fragment has no backreferences, so under DEV-008
   no group is compared and the rule is upstream's plain check. The
   maintainer amended decision 4 accordingly
   ([comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7140581824)):
   the fragment's compiler equals upstream's on the empty check, so
   `OP_EMPTY_CHECK_END_MEMST` and the capture-change termination measure
   leave the fragment. DEV-008 is on `main` (PR #31, merged as
   `8febe2e`). Consequence, recorded in the comparison (M4): DEV-008's
   termination obligation (a continued empty iteration must change a
   group named by a backreference) is exercised by no experiment now,
   since the fragment has no backreferences; the reason first given for
   option (a), measuring the capture-change rule, no longer holds.

Order: the maintainer's dependency order (experiments #4 and #5 before
#9) is satisfied. The report's suggested order also puts #6 and #8
before #9: experiment #6 (milestones 1 and 2) and experiment #8 are
merged (PRs #24, #31, #26). Milestone 2 changed the spec's empty-loop
rule (DEV-008, decision 4), which on the fragment is upstream's plain
check.

## Where things live

- **Bench host** (all runs). `<bench-workdir>/cache/` (written
  `<cache>`) is the shared toolchain cache of experiments #6-#8, used
  unchanged through `<cache>/env.sh` and `<cache>/verus-env.sh`.
  `<bench-workdir>/exp/09-representative-proof/` (written `<exp>`): a
  clone of the branch with `upstream/` at `f95747b` (read only), the
  out-of-tree C build (`<exp>/build/onig/`), per-tool build directories
  (`<exp>/build/<tool>/`) and raw outputs (`<exp>/out/<run-id>/`).
- **Workstation.** `<workdir>` is the work directory outside the
  repository; the branch's worktree is `<workdir>/wt/09-representative-proof`.
  Raw outputs are copied back to `<workdir>/e09/out/` before selection.
  No toolchain is installed on the workstation; every check goes to the
  bench host, and no run starts without the bench host (if it is
  unavailable the run waits; it does not fall back to the
  workstation). The issue's feasibility note about a 16-CPU / 4 GB
  machine is therefore moot under this plan.
- **Repository** (branch `exp/09-representative-proof`),
  `lab/09-representative-proof/`:
  - `FRAGMENT.md`: the shared design every tool transcribes (AST,
    bytecode, compilation scheme, semantics, capture and empty-iteration
    rules, theorem statement), with `upstream/` citations;
  - `cases/select.py`: filters experiment #6's in-subset cases
    (`lab/results/2026-11-20-exp-06-raw/in.tsv`) down to the fragment;
    `cases/fragment.tsv` (committed, small) and the per-reason counts;
  - `oracle/`: experiment #6's `oracle.c`, reused as is, run on the
    fragment's cases;
  - `rocq/`, `fstar/`, `verus/`: per tool, `Syntax` (AST, bytecode),
    `Sem` (reference semantics), `Compile`, `Vm`, `Proof` (or the
    tool's equivalent split), a case module generator and a driver;
  - `check.sh` (full check of one tool, through `<cache>/env.sh`,
    `ulimit -v`, `nice`), `timed.sh` (three pinned full checks, adapted
    from experiment #8's `timed.sh` and experiment #6's `tm.sh`),
    `axioms.sh` (done-criterion 1 checks), `loc.py` (from experiment
    #8), `lemmas.py` (automatic-lemma count), `brittle.sh`
    (done-criterion 4), `provenance.sh`, `pins.json`, `effort.tsv`
    (one line per lemma attempt and per human intervention). Experiment
    #8's `timed.sh`, `check.sh`, `loc.py`, `pins.json` and
    `provenance.sh` come from `lab/08-hard-features/` on `main` (merged
    as `6630262`, PR #26); `provenance.sh` records the commit used;
  - build output is gitignored (`_build`, `*.vo*`, `*.checked`,
    `target`, caches).

Scripts take `<cache>`, `<exp>` and `<bench-workdir>` from environment
variables (`BENCH_WORKDIR`) and never print absolute paths, hostnames or
addresses into their output.

## Tools and versions

All actively maintained; the versions already in `<cache>`, recorded by
experiments #6-#8 (`lab/results/2026-11-20-exp-06-provenance.md`,
`lab/results/2026-11-19-exp-07-toolchains.md`, experiment #8's
`pins.json`), and re-recorded by `provenance.sh` at the first run:

| Tool | Version | Role |
|------|---------|------|
| Rocq | rocq-core 9.3.0, rocq-stdlib 9.2.0 (opam switch `provers`, OCaml 5.4.1) | stack A: definitions, proof, extraction to OCaml for the driver |
| F\* + Pulse | F\* 2026.11.15 binary release (commit `b92b0f87`, Pulse included) | stack C: definitions, proof, OCaml extraction for the driver |
| Z3 for F\* | 4.13.3, 4.15.3, 5.3.0 bundled with the release (also 4.8.5) | selected with `--z3version` |
| Verus | 0.2026.11.02.8bf68ee (Rust toolchain 1.99.1) | stack D: definitions, proof, executable driver |
| Z3 for Verus | 4.16.0, shipped with the release (`<cache>/verus/z3`) | default solver |
| GCC, CMake | 13.3.0, 3.28.3 (system) | C library and oracle |
| Python | 3.12 (system, stdlib, `-I`) | case selection, summaries |

If a newer release of a tool appears before a run, the pin is kept for
comparability with experiments #6-#8 and the newer release is noted.

### SMT solver versions and seeds (done-criterion 4)

Checked on the bench host while writing this plan (`verus --help`, the
F\* release tree):

- **F\*** checks the Z3 version it is given and accepts the bundled
  ones by name. Versions: `--z3version 5.3.0` (the version experiments
  #6-#8 used, the baseline) and `--z3version 4.15.3`; 4.13.3 is a third
  data point if the run has time. Seeds: `--z3seed N`, N = 1..10, plus
  the default seed. The brittleness runs (only) add `--query_stats`,
  so that failing queries are named.
- **Verus** ships Z3 4.16.0 and refuses another version unless told
  otherwise. The second version uses the documented opt-out:
  `-V no-solver-version-check` with `VERUS_Z3_PATH` pointing at the
  F\* release's Z3 5.3.0 (and 4.15.3 if time allows). The refusal
  without the flag is recorded once, as the issue asks, and the run with
  the flag is reported separately from the default-solver run (it is an
  unsupported configuration, so a failure there counts as brittleness
  across versions, not as a proof bug). Seeds:
  `--smt-option smt.random_seed=N` (the flag `verus --help` documents),
  N = 1..10, plus the default. `-V cvc5` exists but cvc5 is not in
  `<cache>`; it is not installed (out of scope, noted in the record).
- `--rlimit` (Verus) and `--z3rlimit` (F\*) stay at the values the
  proof was written with; the brittleness runs do not raise them.

## The fragment, the VM and the theorem

Written once in `FRAGMENT.md` (run 1) and transcribed per tool:

- **AST:** `Lit` (one byte string of ASCII bytes), `Cat`, `Alt`,
  `Star` (greedy), `Group k`, and the empty pattern. No character
  classes (experiment #6's subset has them; the fragment does not), no
  multibyte literal.
- **Bytecode** (issue's list, `upstream/src/regint.h:496-597`): one
  literal opcode (the `OP_STR_*` variants collapsed), `OP_PUSH`,
  `OP_JUMP`, `OP_FAIL`, `OP_MEM_START`, `OP_MEM_START_PUSH`,
  `OP_MEM_END`, `OP_EMPTY_CHECK_START`, `OP_EMPTY_CHECK_END`, `OP_END`,
  and `OP_FINISH` as the
  backtrack-stack sentinel (`upstream/src/regexec.c:3074`). Peephole
  variants (`OP_PUSH_OR_JUMP_EXACT1`, `OP_PUSH_IF_PEEK_NEXT`,
  `OP_ANYCHAR_STAR*`) are outside the theorem. The issue's list also
  names `OP_EMPTY_CHECK_END_MEMST`; `f95747b` never emits it for a
  fragment pattern (no backreferences), and under decision 4 neither
  does the fragment's compiler, so it is left out.
- **Compiler**, after `compile_quantifier_node`
  (`upstream/src/regcomp.c:1399`), `compile_bag_memory_node` (`:1699`),
  alternation in `compile_tree` (`:2575-2598`) and the empty check
  (`:958-1000`); `OP_MEM_START_PUSH` for groups inside an alternation
  or a variable repeat (`:5819-5821`). The star layout follows the
  infinite-greedy branch of `compile_quantifier_node` (`:1434-1515`).
  Upstream emits nothing for a body of compiled length zero
  (`:1407`, `tlen == 0`); fragment syntax cannot write one, but the AST
  can (`Star` of the empty pattern), so `FRAGMENT.md` states that the
  fragment's compiler elides it the same way.
- **Captures** are kept across loop iterations (a group not re-entered
  in the last iteration keeps its earlier span: experiment #2, probe
  ei11, `(?:(a)|())*` on `ab` gives `1=0-1 2=1-1`); the VM restores
  captures on backtracking through `OP_MEM_START_PUSH` stack entries.
- **Empty iterations:** the spec's rule, `spec/deviations.md` DEV-008
  (decision 4), which supersedes DEV-003. It compares only groups named
  by a backreference of the pattern; the fragment has none, so after an
  iteration that consumed nothing the loop stops: upstream's plain
  check. `f95747b` emits `OP_EMPTY_CHECK_END_MEMST` only when the
  quantifier carries `EMPTY_STATUS_CHECK`
  (`upstream/src/regcomp.c:984-989`), set only for a group
  backreferenced outside the loop (`:3941-3957`), so for every fragment
  pattern it emits `OP_EMPTY_CHECK_START` / `OP_EMPTY_CHECK_END`, and
  the fragment's compiler does the same: the proven VM runs the bytecode
  the C compiler emits. `OP_EMPTY_CHECK_END_MEMST` is not in the
  fragment's VM. The check applies to every star whose body may match
  the empty string (experiment #2 run 2, ei04, ei05, ei07-ei09, ei11).
- **Reference semantics:** a backtracking-tree semantics in Linden's
  style (Rocq development, MIT licence; techniques reused, not its
  JavaScript definitions): the tree of choices in priority order
  (left alternative first, greedy star), whose leftmost success is the
  result. Defined first-order and executable. Termination: with the
  plain check, an iteration that consumed nothing ends the loop, so
  (remaining subject, pattern size) decreases lexicographically. Each
  tool may still use a fuel argument (returning `OutOfFuel` when it runs
  out) if that is cheaper than a structural measure; then completeness
  lemma (d) covers it: some fuel makes the semantics return a result,
  and the result does not change with more fuel. `FRAGMENT.md` says
  which a tool uses. The measure is the semantics'; in a
  continuation-passing presentation the fact that `Star` recurses only
  at a strictly larger position is hidden in a closure, so the tool
  either uses the tree form or carries that invariant. The VM itself
  terminates by fuel only. The cross-check below is kept, as a
  transcription check (not a check between two rules): the semantics
  is compared on the cases with experiment #6's executable semantics of
  the same tool, preferably milestone 2's
  (`lab/06-spec-speed/{rocq/Spec2.v,fstar/Spec2.fst,verus/spec2.rs}`),
  which implements DEV-008 itself
  (`lab/06-spec-speed/rocq/Spec2.v:292`: `same_refs` with no
  backreferences is the plain check), so the comparison also tests the
  reduction of DEV-008 to the plain check executably; milestone 1's
  `Spec.v:120-121` implements the plain check directly. Any difference
  is a bug in one of the two and is analysed before anything else.
- **VM:** a function from (bytecode, subject, start position, fuel) to
  `Match (end, captures) | NoMatch | OutOfFuel`, with an explicit
  backtrack stack bottomed by `OP_FINISH`. `OP_EMPTY_CHECK_END` finds
  its iteration's start as upstream does, by scanning the stack down to
  the `STK_EMPTY_CHECK_START` entry with the same id
  (`upstream/src/regexec.c:2409-2419`, `EMPTY_CHECK_START_SEARCH`;
  `USE_REPEAT_AND_EMPTY_CHECK_LOCAL_VAR` is off in the default build). Rocq: Gallina; F\*: total F\*
  over lists and sequences (the Pulse imperative VM is experiment #10's
  question, not this one's); Verus: `exec` Rust with `Vec`, proved
  against `spec fn`s.
- **Theorem** (done-criterion 1), per tool: for every pattern `r` of
  the fragment, subject `s` and start `p <= |s|`, (soundness) whenever
  the VM on `compile r` returns `Match` or `NoMatch` it equals the
  semantics' result at `p`, and (completeness) some fuel makes it
  return a result other than `OutOfFuel`. That is the unbounded VM of
  the issue; the C retry limit is outside the theorem. Results compare
  match/no match, match end and every group's span (unset as -1).
  "Every pattern of the fragment" means every pattern whose capture
  group numbers are distinct (`NoDup (groups r)`, decision 5 of issue
  #4, [comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7165293346)):
  found necessary by Rocq's run 4 (a group nested in a group of the
  same number makes the statement false), it excludes no pattern the
  parser produces; the three statements carry it (`FRAGMENT.md`
  section 7).

## Approach

1. **Shared design and cases** (run 1, workstation and bench host).
   Write `FRAGMENT.md`. `select.py` keeps from experiment #6's `in.tsv`
   the cases whose pattern uses only literals, concatenation, `|`, `*`
   and plain `( )` groups, default syntax and options, no case folding,
   no multibyte literal (counts per kind `x2`, `x3`, `n`, `e` and per
   reason dropped). Experiment #6 found 152 in-subset cases (151 from
   `test_utf8`, one from `test_options`); the fragment is a subset of
   those, and `select.py` re-checks against the full extraction
   (`lab/06-spec-speed/cases/extract.py`) that no case outside #6's
   subset belongs to the fragment. Build the C library (Release, out of
   tree) and run the oracle on `fragment.tsv`, start positions left to
   right as `search_in_range` without the optimiser; cases where the C
   library hits the retry limit are excluded and listed.
2. **Rocq M1: definitions** (run 1). AST, semantics, compiler, VM in
   Rocq; extraction to OCaml; driver over `fragment.tsv` iterating start
   positions; agreement of the VM and the semantics with the C oracle
   (done-criterion 2) and with experiment #6's Rocq semantics.
3. **F\* M1 and Verus M1** (runs 2 and 3), the same for each tool. F\*
   driver: extraction to OCaml (`--codegen OCaml`), as experiment #6;
   the extracted part uses `Prims` only, as experiment #6's did, since
   the release's `fstar.lib` is compiled by OCaml 5.3.0 and cannot be
   linked from the 5.4.1 switch (a 5.3.0 switch or an `fstar.lib` build
   would be a new toolchain, which the budget excludes).
   Verus driver: the `exec` VM compiled by Verus's rustc, as experiment
   #6.
4. **M2: equivalence proofs** (runs 4-12, three per tool, one tool at a
   time: Rocq, then F\*, then Verus). Lemma plan, shared across tools
   in `FRAGMENT.md`: (a) compiler invariants (code layout, jump targets
   in range, group numbering); (b) VM simulation of one construct with
   a continuation (the backtracking-tree / continuation-passing
   argument Linden uses), by induction on the pattern, with the stack
   discipline of `OP_PUSH` and `OP_MEM_START_PUSH`; (c) the star case
   with the plain empty check, on the measure (remaining input, then
   pattern size); (d) completeness (a fuel bound, where a tool uses
   fuel); (e) the main theorem and `axioms.sh`. Each run
   continues where the last stopped; the run's notebook entry says which
   lemmas are closed. If after its third M2 run a tool's theorem is
   still open, the pipeline stops that tool, records the open lemmas
   and asks the maintainer (more runs, or report as is).
5. **Axiom and admit checks** (end of each tool's M2). `axioms.sh`:
   Rocq `Print Assumptions main_theorem.` (expected "Closed under the
   global context"); F\*: full check with `--admit_smt_queries false`
   (explicit, although it is the default), and a scan finding no
   `admit`, `assume`, `assume val`, `--admit_smt_queries true`,
   `--lax` or `#lang-` escape in the sources; Verus: full
   `verus --crate-type=lib` check (`--no-verify` absent) reporting
   "0 errors", a second full check with `--no-cheating` (present at the
   pinned commit `8bf68ee`), and a scan finding no `assume(`, `admit(`,
   `#[verifier::external_body]`, `#[verifier::external]` or
   `#[verifier::exec_allows_no_decreases_clause]` on any function the
   theorem depends on. The output is saved raw and quoted in the
   notebook.
6. **Measurements** (done-criterion 3), per tool after M2, in the
   tool's M2 closing run: `loc.py` lines (non-blank, non-comment) of
   semantics, compiler + VM, proof; `timed.sh`: three full clean checks
   pinned to one L3 complex, median and spread, peak RSS, load average
   per run; `lemmas.py`: lemmas total and automatic. A lemma is a
   named statement: Rocq `Lemma`, `Theorem`, `Corollary`, `Fact`,
   `Proposition`; F\* a top-level `val`/`let` whose type is a `Lemma`;
   Verus a `proof fn`. Inline proof blocks, `assert ... by`, `calc`
   steps and local `have`/`assert` are not lemmas, so the counts are
   comparable across tools. Automatic: (Rocq: the proof is one
   call of an automation tactic, `lia`, `auto`, `eauto`, `easy`,
   `congruence`, `intuition` or `firstorder`, possibly with hints; a
   single other tactic such as `reflexivity` or `inversion` does not
   count; F\*: body `()`, the default SMT discharge, with no explicit
   call to another lemma; Verus: empty `proof fn` body, likewise); effort
   from `effort.tsv`.
7. **M3: SMT brittleness** (done-criterion 4; one run per SMT tool,
   runs 13-14). `brittle.sh`: full check for each solver version above
   and each seed 1..10 plus the default, serial, pinned; every failure
   recorded with the failing query or function, solver version and seed.
8. **M4: comparison** (run 15). The table across the three tools
   (proof effort, lines, check time, automatic share, brittleness,
   agreement), a short verdict per tool, posted on issue #4 after the
   maintainer's review (done-criterion 5); the draft PR is opened. The
   comparison states that DEV-008's termination obligation is not
   covered (decision 4). Each attempt figure names its unit (run-4 review): failed
   checks and compile invocations are comparable across tools (Rocq
   M2: 19 failed checks, 23 invocations); `effort.tsv`'s per-lemma
   attempts (a clean compile counts once per lemma it contains; Rocq
   M2: 67) and run 3's per-module Verus rows are not. Failing
   invocations are reported beside failed checks (run-7 review): Rocq's
   19 failed checks are all its failing invocations, while F\*'s 7 leave
   out 6 failing reruns of an unchanged file that its `invocations.tsv`
   cannot identify, so the table gives failing invocations (Rocq 19,
   F\* 13) and failed checks (Rocq 19, F\* 7, the latter resting on the
   session record).

## Runs (launched one by one by the maintainer)

Each run is one Claude Code session of at most 4 hours wall-clock on the
bench host, ending with its notebook entry and a push. A run that ends
early leaves the rest to the next run in the list; nothing starts
automatically.

| Run | Milestone | Content | Done when |
|-----|-----------|---------|-----------|
| 1 | M0 + Rocq M1 | `FRAGMENT.md`, `select.py`, oracle, provenance; Rocq definitions and agreement | count reported, Rocq VM and semantics agree with C on every case |
| 2 | F\* M1 | F\* definitions and agreement | as above, F\* |
| 3 | Verus M1 | Verus definitions and agreement | as above, Verus |
| 4-6 | Rocq M2 | lemmas (a)-(e); run 6 closes with axioms and measurements | `Print Assumptions` clean, measurement entry |
| 7-9 | F\* M2 | same | F\* checks recorded, measurement entry |
| 10-12 | Verus M2 | same | Verus checks recorded, measurement entry |
| 13 | F\* M3 | brittleness, F\* | every (version, seed) result recorded |
| 14 | Verus M3 | brittleness, Verus | same |
| 15 | M4 | comparison table, verdicts, draft PR | table posted on issue #4 |

If a tool's M2 closes in fewer runs, its measurement entry moves to
that run and the next run starts the next tool. The maintainer can
reorder the tools between runs.

## Machine budget

Bench host (64 threads, 503 GB RAM at experiment #6), shared with other
experiments:

- Per run at most 4 hours of wall-clock; the whole experiment is 15
  runs at most, about 60 hours of wall-clock.
- Untimed work (builds, interactive checks while writing proofs, case
  runs) at most 4 parallel jobs under `nice -n 10`, on CPUs no other
  experiment pins (checked with `lscpu -e` at the start of the run).
- Timed checks (`timed.sh`, `brittle.sh`) one at a time under a lock,
  pinned to one L3 complex (`taskset -c 28-31,60-63`, as experiments
  #6-#8, unless another experiment holds it at run time), one tool at a
  time, with `/usr/bin/time -v`, a memory cap (`ulimit -v 16G`) and the
  load average before each check.
- Disk: stop and report if free space on the bench work directory falls
  below 20 GB (52 GB free when this plan was written). No new toolchain
  is installed.
- Expected brittleness cost: a full check is a few seconds to a few
  minutes; F\* runs 2-3 versions x 11 seeds, Verus 2 versions x 11 seeds,
  well inside one run each.

## Effort recording

Per run, in `effort.tsv` and the notebook entry: session wall-clock
(start and end, UTC); per lemma the number of attempts (a check that
fails and leads to an edit counts as one attempt); for each M2 run, the
UTC timestamps of the first and the last compile of the proof, so the
proof time per tool is a recorded figure (run-4 review); from run 10
on, each line of an M2 run's `invocations.tsv` also carries the SHA-256
of the compiled source file, so a rerun of an unchanged file is
identifiable from the raw file (run-7 review); human
interventions (count, with a one-line reason each); person-days only for
work a person did. Session time is engineering effort, reported apart from machine
time.

## Lab notebook

With the lab-notebook skill: `lab/notebook.md` (one index line per
recorded entry) and `lab/results/<date>-exp-09-<topic>.md`
(append-only), raw data beside it under
`lab/results/<date>-exp-09-raw/`. Planned entries:

1. provenance: hardware, OS, tool versions, Z3 versions, pinning, script
   commit (run 1; amended by a new entry if a later run changes
   anything);
2. fragment cases: counts per kind and per reason, C oracle results,
   excluded retry-limit cases (run 1);
3. one entry per tool for M1: agreement with C and with experiment #6's
   semantics (runs 1-3);
4. one progress entry per M2 run: lemmas closed, attempts, interventions;
5. one entry per tool at M2's end: axiom/admit report output, lines,
   check time, automatic share, effort totals;
6. one brittleness entry per SMT tool, including Verus's refusal without
   `-V no-solver-version-check`;
7. the comparison and verdicts.

Raw outputs that are deterministic re-runs (same commit, same inputs)
are not kept twice; seed and solver-version runs are data and are kept.
The maintainer decides what is recorded.

## Outputs

- `lab/09-representative-proof/` with the shared design, the three
  developments, the scripts and the case file.
- Notebook entries above; `spec/deviations.md` is not changed unless an
  agreement difference reveals a new deviation candidate, which is then
  raised on the issue, not decided.
- The comparison table posted on issue #4 and a draft PR.
- The proven VMs are experiment #10's input (issue #8).

## Done-criteria (from the issue)

For each selected tool:

1. A machine-checked proof that, for every pattern of the fragment,
   every subject and every start position, the VM and the semantics
   agree on match or no match, on the match end, and on every capture
   group's span. The proof contains no `admit`, `sorry`, `assume` or
   equivalent, except for stated axioms about the solver or the
   standard library. Checked with the tool's axiom/admit report
   (`Print Assumptions` in Rocq, `#print axioms` in Lean,
   `--admit_smt_queries false` in F\*, the Verus/Why3/Isabelle
   equivalents named in the plan), whose output is recorded in the
   notebook.
2. The VM and the semantics both run on the upstream test cases of the
   fragment. Their results agree with the C library. "Test cases of the
   fragment" are the cases whose pattern uses only literals,
   concatenation, `|`, `*` and plain `( )` groups, under default syntax
   and options, with no case folding and no multibyte literal; the count
   is reported. The harness iterates start positions left to right
   (that is, `search_in_range` without the optimiser), so the comparison
   with `onig_search`-based tests is defined. Cases that hit the C retry
   limit are excluded from the comparison.
3. A measurement record, kept with the lab-notebook skill: effort (see
   Cost for the unit); lines of spec, VM and proof; full check time; the
   share of lemmas proven automatically. A lemma counts as automatic
   when its proof is a single call to the tool's automation; count
   lemmas, not lines.
4. For SMT-based tools: the proof is re-checked with at least two solver
   versions (where the tool allows it, see Dependencies) and at least 10
   random seeds. Every failure is recorded.
5. A comparison table across the tools, with a short verdict on each,
   posted on this issue.

(Selected tools: Rocq, F\* + Pulse, Verus. The Lean, Why3 and Isabelle
checks named in criterion 1 do not apply; the Verus check is step 5's.)

## Risks

| Risk | Effect | Mitigation |
|------|--------|------------|
| The proof takes longer than 3 runs per tool (report: 2-4 weeks per tool) | M2 unfinished | stop after the third M2 run, record open lemmas, ask the maintainer |
| Star with empty check: the measure through an empty iteration is awkward in a tool | lemma (c) stalls | state the measure in `FRAGMENT.md` first; Linden's handling of empty iterations as the model |
| Rocq: `simpl` or conversion unfolds fuel (experiment #8's two failures) | slow or failing checks | keep fuel out of lemma statements, abstract the VM as experiment #8 did |
| Verus: own list type and large encodings (experiment #8) | more lines, slower interpreter | reuse experiment #6's `spec.rs` types |
| F\* + Pulse: the selected stack's native-C route is Pulse, but this VM is total F\* | the proof says less about Pulse | stated in the comparison; the Pulse VM is experiment #10's |
| Verus with another Z3 is unsupported | spurious failures | reported apart from the default-solver results |
| No upstream fragment case has a star over a nullable body (none of the 152 in-subset cases does), so the upstream suites never exercise the empty check | done-criterion 2 says nothing about it | always add experiment #2's loop probes (ei04, ei05, ei07, ei11) as extra cases, kept separate from the upstream count; ei11 `(?:(a)\|())*` is not fragment syntax and is transcribed as `((a)\|())*` (group numbers shift by one) |
| Agreement difference with C | criterion 2 fails | analyse against DEV-008 and experiment #2; raise a deviation candidate on the issue |
| Bench host load from other experiments | noisy check times | lock, pinning, load average per run; rerun when idle if needed |
