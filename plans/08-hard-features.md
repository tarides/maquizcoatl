# Plan: experiment #8, hard-feature spec probe

Issue: [#12](https://github.com/tarides/maquizcoatl/issues/12) (the
issue body is the reference for scope, inputs and done-criteria; this
plan says how).
Source: maintainer's state-of-the-art report, "Experiments before
deciding", row of experiment #8
(https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

## Objective

Write a formal semantics for the four Oniguruma features that no
existing formal work covers (subexpression calls with the nest limit,
the absent operator, `ONIG_OPTION_FIND_LONGEST`, multi-character case
folding over ISO-8859-1 bytes) in four tools, Rocq, Lean 4, F\* with
Pulse and Verus. Run each semantics on test cases checked against the C
library at `f95747b`, prove one lemma per feature, and record, per tool
and feature, the size, the checking time and every place where
automation failed or needed help. The outcome is a per-feature
comparison: which semantics fit which tool, and where SMT automation
breaks down. It feeds the choice of stack; it does not make it.

## Decisions folded in

From the maintainer's
[comment](https://github.com/tarides/maquizcoatl/issues/12#issuecomment-7022493004):

1. **Four tools**, two of each kind: Rocq (stack A) and Lean 4 (stack
   B), interactive; F\* with Pulse (stack C) and Verus (stack D),
   SMT-based. This widens the report's two-tool design; the issue's
   cost estimate is about 5 weeks (4–6).
2. **Calls first.** Subexpression calls are probed first, in every
   tool (experiment #1: 18 of 82 VS Code grammars use them).
3. **Contingency.** A tool whose stack experiment #5 eliminates is
   dropped. If no SMT-based tool survives, the least-eliminated one
   runs as a control.

## Gate

Execution waits for experiment #5 (issue #13, PR #21), which reports
which of stacks A to D remain. Experiment #4's mechanism 4 is still
pending; if it reports before step 2 and eliminates a stack, that tool
is dropped too. Steps 1 and 2 (toolchains and the case corpus) do not
depend on the eliminators and may start as soon as the maintainer
allows; steps 3 onwards start only on the tools left standing. The tool
list actually used is recorded in the first notebook entry.

## Approach

1. **Toolchains.** Reuse experiment #7's toolchains on the bench host
   (`lab/07-large-tables/setup.sh`: Rocq, Lean 4, F\* with Pulse; not
   re-installed if present and at the pinned versions). Add Verus with
   `lab/08-hard-features/setup.sh verus`: the pinned release archive
   (sha256 checked), the Rust toolchain it names installed by rustup
   under `<cache>/rustup` and `<cache>/cargo`, and Verus's bundled Z3.
   Smoke test per tool: one trivial lemma checked (the smoke tests also
   validate the memory cap, see "Machine budget"). Build the C library
   out of tree from `f95747b` twice, a Debug build
   (`<exp>/build/onig-debug/`) and an ASan/UBSan build
   (`<exp>/build/onig-asan/`), with the flags of `probes/README.md`
   ("Replay"); `test_utf8` must print `FAIL: 0` on both.
   `lab/07-large-tables/setup.sh onig` builds a Release tree, so
   `lab/08-hard-features/setup.sh onig` makes its own two builds rather
   than reusing it.
2. **Case corpus, shared by all tools.** For each feature, write the
   cases once in `lab/08-hard-features/cases/<feature>.tsv`, in
   experiment #2's eight-column probe format (`probes/README.md`): id,
   syntax, encoding, options, pattern, subject, js (left empty), note.
   There is no input "expected result" column: `probes/harness.c`
   (which already handles `ISO-8859-1` and `FIND_LONGEST`) computes the
   result, and the expected column is derived by joining its Debug and
   ASan outputs per case id, as `probes/compare.mjs` does, so the corpus
   replays with the existing tools. A small driver
   `lab/08-hard-features/cases/nest.c` covers the cases that need
   `onig_set_subexp_call_max_nest_level`, with the same output format. At least 4 cases per feature
   (one more than the criterion, in case one turns out to exercise an
   out-of-scope path):
   - calls: `upstream/test/test_utf8.c:701`, `707`, `714`, `729`, and
     one written case that hits the nest limit (fails at limit 2, matches
     at 20), on ASCII subjects;
   - absent operator, non-nested only: `upstream/test/test_utf8.c:840`,
     `842`, `847`, plus one absent expression `(?~|abc|\O*)` and one
     absent stopper case written for the experiment (`test_utf8.c:850`,
     a nested use, is excluded and listed as a spec gap). `(?~abc)` and
     `(?~|abc|\O*)` are run on the same subjects: `upstream/doc/RE:368`
     says they are equivalent, but they compile through different code
     paths (see step 3), so agreement is a finding and disagreement a
     deviation-log candidate;
   - FIND_LONGEST, forward search: `upstream/test/test_options.c:217`
     and three written cases (equal-length tie, a longer match at a
     later start, a longer match through a lower-priority alternative);
   - ISO-8859-1 folding: experiment #2's cf21 and cf22, and written cases
     for `0xDF` against each of `ss`, `SS`, `sS`, `Ss` and back, ported
     from `upstream/test/test_utf8.c:326-341` and
     `upstream/sample/encode.c:92-95,140-145`.
   Each case is checked against both the Debug and the ASan builds, as
   experiment #2 did. A case where the two disagree, or where the C
   result contradicts `upstream/doc/RE` or `doc/API`, becomes a
   deviation-log candidate, and the semantics states the correct result
   (bug-free goal), not the C one.
3. **Prose semantics, once.** `lab/08-hard-features/SEMANTICS.md` fixes
   the shared design before any tool code, so that the four tools
   formalise the same thing:
   - Linden's backtracking-tree style (style only): a match function
     returns the priority-ordered list of results; first match is the
     head of that list. The semantics of lookbehind, empty loops and case
     folding it relies on follows `spec/deviations.md` (DEV-001 to
     DEV-004; DEV-005 and DEV-006 from experiment #4's branch when it
     merges).
   - Calls: the matcher state carries the nest depth (number of live call
     frames) and the limit is a parameter of the search, 20 by default;
     a call beyond the limit fails that branch. Only patterns accepted by
     upstream's never-ending-recursion check are in scope; the check is a
     precondition stated as a hypothesis, not modelled. Termination is
     shown by a lexicographic measure (remaining input, remaining nest
     budget, pattern size); a tool that cannot accept that measure falls
     back to fuel with an adequacy lemma. Fuel used only so that a tool
     can *compute* with the definition (Rocq and Lean cannot reduce
     well-founded recursion conveniently, while F\* and Verus run
     `decreases`-based definitions directly) is recorded under a separate
     heading, "computability help", not as an automation failure.
   - Absent operator: a direct semantics, not the gimmick desugaring of
     `make_absent_engine`. The matcher state carries a right-range
     register (the end bound the stopper and range clear act on), and the
     four forms are defined on it. The register rules are derived from
     the C wiring, not from `doc/RE`'s prose, and `SEMANTICS.md` cites
     it: `make_absent_tree` (`upstream/src/regparse.c:3299-3380`)
     compiles `(?~absent)` (body `\O*`) through
     `make_absent_tree_for_simple_one_char_repeat`, step-wise, and every
     other form through `make_absent_engine` (`regparse.c:2995-3076`):
     save the right range, save s, a possessive scan
     `((SAVE_S absent CUT FAIL) | \O)*` that cuts the right range at the
     first position where `absent` matches within it, rewind s, then
     `exp` bounded by the cut; `make_absent_tail`
     (`regparse.c:3078-3127`) restores the right range on exit and
     re-installs the cut when backtracking into the group, and the
     stopper (`is_range_cutter`) skips the tail. The cut is the position
     *before* the absent match (`UPDATE_VAR_RIGHT_RANGE_FROM_S_STACK`,
     `upstream/src/regexec.c:4563-4571`), and the right range bounds
     every consumption through `DATA_ENSURE` (`regexec.c:2725-2727`),
     which is why `(?~abc)` on `abc` gives `[0,0)`
     (`test_utf8.c:841`). Equality with the C behaviour is checked on
     the test cases (step 4), not proved against the desugaring; a proof
     of that equality is follow-up work.
   - FIND_LONGEST: a search-level function over the results of all
     start positions in the range: the first result of maximal length in
     (start ascending, then priority) order, as the strict comparison in
     `upstream/src/regexec.c:3298-3299` gives. Forward search only. The
     mechanism, cited next to the definition: with the option,
     `match_at` continues after every `OP_END` (`goto fail`,
     `regexec.c:3404`) and returns `ONIG_MISMATCH` at `OP_FINISH`
     (`regexec.c:4655-4660`), so `search_in_range` visits every start
     and reads `msa.best_len`/`msa.best_s` afterwards
     (`regexec.c:5993-5999`); the early exit at `regexec.c:3305` (a match
     reaching the range end) is the only short cut.
   - ISO-8859-1 folding: a 256-entry byte fold table, read from
     `upstream/src/iso8859_1.c`, plus the one multi-character fold
     `0xDF` to `ss`. A folded literal's language is the one-level,
     per-position alternation of the original bytes and the items
     returned by `get_case_fold_codes_by_str` (`iso8859_1.c:126-160`
     maps any two-byte spelling of `ss` to `0xDF`, `173-199` maps `0xDF`
     to `ss`, `SS`, `sS`, `Ss`), as `unravel_case_fold_string` expands
     it; not a transitive closure, which could admit strings the C
     rejects. Match length and pattern length can differ. Experiment
     #2's cf21 and cf22 already confirm both directions. Character
     classes (`[\xDF]`, `apply_all_case_fold`) are a separate path and
     out of scope.
   - Lemma statements, fixed here once for all tools so that the proof
     columns compare the same proposition. Since every tool accepts a
     `decreases` measure, "termination" is the definition's acceptance,
     not a lemma; the calls lemma is instead: every result of the calls
     semantics is produced with nest depth at most the limit at every
     step (or, for a fuel version, fuel adequacy: fuel = f(input length,
     limit, pattern size) suffices). The other three are the issue's
     examples, stated precisely in `SEMANTICS.md`: no result of the
     absent repeater contains the absent pattern as a substring;
     FIND_LONGEST's result is no shorter than the first-match result
     over the same range; `0xDF` matches each of `ss`, `SS`, `sS`, `Ss`
     and back.
4. **Per tool, per feature, calls first.** For each surviving tool, in
   the order calls, absent operator, FIND_LONGEST, ISO-8859-1 folding:
   write the definitions, run the cases, prove the lemma.
   - Running the cases: Rocq `vm_compute` then `reflexivity` (expected
     to get stuck on `Fix`/`Acc` unless the accessibility proofs are
     transparent, so the fuel version or `Equations` with transparent
     well-foundedness is the likely route); Lean `decide` or `rfl`, then
     `decide +kernel` (experiment #7 found plain `decide` fails on
     well-founded recursion and `decide +kernel` works), and
     `native_decide` only if those fail, recorded, since it adds the
     `Lean.ofReduceBool` axiom; F\* `assert_norm`;
     Verus `assert(...) by (compute_only)`. A case that cannot be run
     this way is run through the tool's extraction or executable mirror
     and the gap is recorded.
   - Lemmas: the four statements fixed in `SEMANTICS.md` (step 3), the
     same in every tool.
   - F\* with Pulse: the semantics is pure F\* (Pulse is F\*'s
     separation-logic layer for imperative code and a semantics has
     none); it is checked with the Pulse-enabled `fstar.exe` of the
     stack C toolchain. Verus: the semantics is `spec fn`s and the
     lemmas are `proof fn`s.
   - Assumption check after each feature: Rocq `Print Assumptions` on
     every lemma plus a grep for `Admitted`/`admit`/`Axiom`; Lean
     `#print axioms` plus a grep for `sorry`; F\* a grep for
     `assume`/`admit`/`assume_val` and `--admit_smt_queries`; Verus a
     grep for `assume`/`admit`/`external_body`/`external`. Output kept
     in the raw results.
5. **Measurements.** Per tool and feature: lines of specification and
   of proof (counted by `lab/08-hard-features/loc.py`, with per-tool
   comment syntax and this spec/proof rule, also written in the script's
   header: Rocq, `Lemma`/`Theorem` statements and `Proof.`…`Qed.`/
   `Defined.` blocks are proof; Lean, `theorem`/`lemma` declarations and
   their bodies; F\*, `let`s with a `Lemma` type and `assert`/`calc`
   blocks; Verus, `proof fn` bodies, `by` blocks and `assert` lines;
   everything else that is not blank or a comment is specification),
   wall-clock checking time (three runs of the full check after the
   work is done, median kept), peak RSS (`/usr/bin/time -v`, whose
   "Maximum resident set size" is that of the largest single
   descendant, not of the process tree: `lake`, `opam exec`, `verus` →
   `rust_verify` + `z3`; noted next to the column, or the tree sampled
   from `/proc`), solver names and versions, a list of every automation
   failure or manual help (triggers, `decreases` hints, `by` blocks,
   rewriting, split lemmas), and a separate list of computability help
   (fuel or executable mirrors added only to run cases), each with file
   and line.
6. **Comparison.** A short per-feature table of the four tools
   (interactive against SMT-based, and within each kind), posted on
   issue #12, plus the list of deviation-log candidates found.

## Where things live

- **Bench host.** Nothing is installed system-wide.
  - `<bench-workdir>/cache/` (written `<cache>`): shared toolchains from
    experiment #7 (`<cache>/opam` with Rocq, `<cache>/elan` with Lean,
    `<cache>/fstar` with Pulse and krml, `<cache>/env.sh`), plus Verus
    added by this experiment (`<cache>/verus/`, `<cache>/rustup/`,
    `<cache>/cargo/`), reusable by later experiments.
  - `<bench-workdir>/exp/08-hard-features/` (written `<exp>`): a clone
    of `tarides/maquizcoatl` at this branch with `upstream/` at
    `f95747b` (`<exp>/repo/`, read only for `upstream/`), the
    out-of-tree C builds (`<exp>/build/onig-debug/`,
    `<exp>/build/onig-asan/`), per-tool build directories
    (`<exp>/build/<tool>/`) and raw outputs (`<exp>/out/<run-id>/`).
- **Workstation.** `<workdir>` is the work directory outside the
  repository; this branch's worktree is under `<workdir>/wt/`. Raw
  outputs are copied back to `<workdir>/e08/out/` before selection.
- **Repository** (branch `exp/08-hard-features`), under
  `lab/08-hard-features/`: `setup.sh` (Verus; calls experiment #7's
  script for the others), `pins.json`, `SEMANTICS.md`, `cases/`
  (TSV corpus and `nest.c`), `rocq/`, `lean/`, `fstar/`, `verus/`
  (the semantics, cases and lemmas), `check.sh` (one tool, timed, with
  the assumption check), `loc.py`, `provenance.sh`. Scripts take
  `<cache>` and `<exp>` from environment variables and never print
  absolute paths, hostnames or addresses, so raw files can be committed
  after a redaction check.

## Tools and versions

All actively maintained. `pins.json` records every version and the
notebook records the versions actually installed.

| Tool | Version | Source on the bench host |
|------|---------|--------------------------|
| Rocq | 9.3.0 (`rocq-core`, `rocq-stdlib`), OCaml 5.4.1 switch | experiment #7's opam root |
| Lean 4 | v4.36.0 (elan v4.4.0) | experiment #7's `ELAN_HOME` |
| F\* with Pulse | v2026.11.15 (Pulse bundled in the release), Z3 as F\* requires it | experiment #7's `<cache>/fstar` |
| Verus | `release/0.2026.11.02.8bf68ee` (the latest non-rolling release; the rolling build of 2026-11-19 is too recent to pin) | release archive, sha256 checked |
| Rust | the toolchain the Verus release names | rustup, `RUSTUP_HOME=<cache>/rustup` |
| Z3 (Verus) | the version bundled with the Verus release | release archive |
| GCC, CMake | Ubuntu 24.04 packages | system (C library, `nest.c`) |
| Python | 3.12, stdlib only, run with `-I` | system |

If experiment #5 or the setup finds that a pinned version cannot be
used, the next release of the same tool is used and the reason recorded;
switching to another tool needs the maintainer's decision.

## Machine budget

At most 4 parallel jobs (`make -j4`, `opam --jobs=4`, at most four tool
checks at a time, never more), and at most 3 hours of wall-clock for a
run. Each check runs under `timeout` and a memory cap; hitting either
is recorded as a failure for that tool and feature. The cap is not
`ulimit -v`: that limits address space, which OCaml 5 (Rocq) and Lean
reserve in large ranges at start-up, so it can fail a check
spuriously. It is a cgroup limit (`systemd-run --user --scope -p
MemoryMax=…`), or `prlimit --as` if the cgroup is unavailable, with a
value below the host's RAM, validated by the smoke tests; the mechanism
and value used are recorded. Timed checks (step 5) run one after
another, not concurrently with each other.

Bench-host etiquette: issue #13's accepted rules for experiment #5 apply
here too. The Verus install and every timed check run under `taskset`
on free cores and under `nice`, and no heavy install runs on the cores
reserved for experiment #11's timed runs. The load at each timed run is
recorded.

The machine work of the whole experiment does not fit one 3-hour run
next to the writing work it depends on, so it is split into milestones,
each one run of at most 3 hours:

- **Milestone 1 (this plan's first run):** step 1 (Verus setup, smoke
  tests, C builds), step 2 for all four features (corpus checked against
  the C library), step 3 (`SEMANTICS.md`), and step 4 for calls only in
  every surviving tool, with its assumption check and measurements.
  Estimated machine time: setup under 45 minutes, corpus under 15
  minutes, checks a few minutes per tool; the rest is writing.
- **Follow-up milestones:** absent operator in every tool; FIND_LONGEST
  in every tool; ISO-8859-1 folding in every tool; the timed runs
  (step 5) and the comparison (step 6). Each is one run under the same
  budget.

## Lab notebook

Recorded with the lab-notebook skill, in `lab/notebook.md` (a new
"Experiment #8" table) and `lab/results/`, files named
`2026-MM-DD-exp-08-<topic>.md` with raw outputs in
`lab/results/2026-MM-DD-exp-08-raw/`. Planned entries, each recorded
only when the maintainer agrees it is worth keeping:

- `exp-08-setup`: tools kept after experiments #4 and #5, installed
  versions, smoke tests, provenance (CPU model, kernel, OS, tool
  versions, branch commit).
- `exp-08-corpus`: the case corpus with the C results (Debug and ASan),
  and any deviation-log candidate.
- `exp-08-<feature>` (one per feature): per tool, lines of spec and
  proof, check time, peak RSS, solvers, assumption-check output, cases
  run and agreement, the lemma, and the list of automation failures.
- `exp-08-comparison`: the timed runs and the per-feature comparison.

## Outputs

- `lab/08-hard-features/`: scripts, `SEMANTICS.md`, the case corpus and
  the four tools' sources.
- Notebook entries and raw results as above.
- Deviation-log candidates, listed in the results and on issue #12
  (entries in `spec/deviations.md` only once the maintainer accepts
  them; the two found so far are in the issue body).
- A comparison comment on issue #12, and a PR from this branch.

## Done-criteria (from issue #12)

- For each of the four tools (Rocq, Lean 4, F\* with Pulse, Verus;
  minus any tool dropped after experiment #5), all four features have a
  semantics that type-checks or verifies with no admitted or assumed
  definitions. The nest limit for calls is a parameter, with 20 as its
  default. "No admitted or assumed definitions" is checked per tool and
  the output is recorded in the lab notebook: Rocq `Print Assumptions`
  plus a grep for `Admitted`/`admit`/`Axiom`; Lean `#print axioms` plus
  a grep for `sorry`; F\* with Pulse a grep for
  `assume`/`admit`/`assume_val` and for `--admit_smt_queries`; Verus a
  grep for `assume`/`admit`/`external_body`/`external`.
- For each tool, the semantics runs, or is proved by computation, on at
  least 3 test cases per feature (at least 12 cases per tool), and
  agrees with the C library on each of them. Cases come from upstream
  tests where they exist; otherwise they are written for the experiment
  and checked against the C library built from `f95747b`.
- For each tool, at least one lemma per feature is proved. Examples:
  termination of calls under the nest limit; FIND_LONGEST returns a
  match no shorter than the first-match result over the same range; ß
  matches each of `ss`, `SS`, `sS` and `Ss` (and back) under ISO-8859-1
  case folding.
- For each tool and feature: lines of specification, lines of proof,
  wall-clock checking time, solver(s) and versions, and every place
  where automation failed or needed manual help, recorded in the lab
  notebook.
- A short comparison of the four tools per feature (interactive versus
  SMT-based, and within each kind), posted on issue #12.
- Each disagreement between the docs and the code, or deviation from
  upstream found during the work, is recorded as a deviation-log
  candidate.

## Risks

- **Experiment #5 is late or eliminates stacks.** Execution waits;
  steps 1 and 2 can still be prepared. If no SMT-based tool survives,
  the least-eliminated one runs as a control (Decision 3).
- **Termination of the calls semantics.** Calls do not always consume
  input, and empty loops around calls interact with the empty-loop
  check (DEV-003). A tool may reject the measure; the fuel fallback
  keeps the probe going and is itself a finding.
- **Computation in SMT tools.** Running cases by `assert_norm` (F\*) or
  `by (compute_only)` (Verus) may time out on backtracking trees;
  executable mirrors with an equality lemma are the fallback, recorded
  as manual help.
- **Verus setup.** Verus needs a specific Rust toolchain and is new on
  the bench host; if the pinned release does not build or run there,
  the next release is tried (recorded); the setup time counts against
  milestone 1.
- **Absent-operator semantics.** The direct semantics with a
  right-range register may disagree with the C behaviour on corner
  cases of the stopper; each disagreement is either a deviation-log
  candidate (C wrong) or a fix to the semantics, decided case by case
  and recorded.
- **Cost.** Four tools roughly double the report's estimate; if the
  writing work runs far beyond 5 weeks, the per-feature milestones let
  the maintainer stop after any feature with complete data for it.
- **Shared bench host.** Other experiments may run there; the 4-job cap
  and sequential timed runs keep the measurements comparable, and the
  load at the time of each timed run is recorded.
