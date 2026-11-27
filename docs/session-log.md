# Session log

A running record of how Maquizcoatl is being bootstrapped with Claude Code,
kept as material for a presentation. Newest entries at the bottom. Times are
local (CET).

## 2026-11-17 — Bootstrap of the repository

Reconstructed from git history.

| Time  | Commit    | Step |
| ----- | --------- | ---- |
| 12:40 | `da34b1d` | Initial empty commit |
| 12:44 | `2212947` | `kkos/oniguruma` added as the `upstream/` submodule, pinned to its last commit `f95747b` (v6.9.10-28); provenance (SWHID, licence, citation convention) recorded in `spec/SOURCES.md` |
| 12:59 | `ce4c67b` | `CLAUDE.md`: project goal, layout, how to build and test the upstream C library, architecture of the three core files |
| 13:20 | `81a1263` | BSD-2-Clause licence, as Oniguruma |
| 13:23 | `231a6c2` | Onigmo (Ruby's fork) compatibility made a non-goal |
| 13:34 | `f3f8805` | Bug-free goal (no bug-for-bug compatibility); tool selection criterion: actively maintained, proficiency irrelevant |
| 13:44 | `fd2c367` | Two deliverables: a libonig drop-in (same C API and ABI) and an OCaml library without FFI cost |

Every commit was co-authored with Claude.

## 2026-11-17 — State-of-the-art report

A Claude Doc, "Verified reimplementation of Oniguruma: state of the art",
surveys the plan: soundness of the spec-first approach, prior art (Warblre,
Linden, lean-regex, …), candidate specification and implementation languages,
methodology, performance, ReDoS, deliverables, and seven candidate stacks (A
to G). It ends with 13 experiments to run before choosing a stack, and the
decisions and open questions so far.

## 2026-11-19 — From report to experiments

1. **"What are the 12 tests to conduct?"** The report's experiment table had
   grown to 13 (experiment #13, upgrade cost, was added later). Claude listed them from
   the doc.
2. **Repository published.** `gh repo create tarides/maquizcoatl --public`,
   after checking that no tracked file leaks local paths or host details.
3. **Prompt review.** The maintainer drafted a 13-step prompt to drive every
   experiment through issue → review → plan → review → execution → review.
   Claude reviewed it without running it. Main findings: plan mode is
   session-wide and needs approval, so plans become files; asking a question
   blocks the whole session, so decisions become a `needs-decision` label;
   experiments depend on each other, so the prompt needs an order; "test"
   should read "experiment"; comments posted under the maintainer's account
   must be marked as automated.
4. **Final prompt**, after the maintainer chose parallel execution, one branch
   and draft PR per experiment, automatic lab-notebook recording, and a
   workflow:

   > Run the 13 experiments in "Experiments before deciding" of the
   > state-of-the-art doc through the pipeline below, in tarides/maquizcoatl.
   >
   > Use a workflow.
   >
   > Order: #1, #2, #3, #7, #11 first; then the eliminators #4 and #5; #6,
   > #8, #9 only on the stacks still standing; #10 after #9; #12 after #1.
   > Run independent experiments in parallel. Never block the whole session
   > on one experiment.
   >
   > Per experiment:
   > 1. Open an issue: goal, what it decides, cost, inputs, dependencies,
   >    done-criteria, link to the doc. Labels: `experiment`, `stage:issue`.
   > 2. Spawn a Fable subagent to review the issue. Give it the issue, the doc
   >    section and CLAUDE.md, not your own opinion. Post its review as an
   >    issue comment headed "Automated review (Claude Fable 5.1)".
   > 3. Apply the review's decision-free fixes to the issue body.
   >    Decision-free means it does not change scope, cost, tool choice or
   >    done-criteria, and does not contradict CLAUDE.md. If a point needs my
   >    decision, label the issue `needs-decision`, put the question in the
   >    dashboard, and move on to other experiments. Batch your questions to
   >    me.
   > 4. Write the plan as `plans/NN-<slug>.md`, review it the same way
   >    (steps 2-3), and open it as a draft PR linked to the issue. Label
   >    `stage:plan`.
   > 5. Execute on branch `exp/NN-<slug>`. Builds and toolchains live outside
   >    the repo; upstream/ stays untouched. Record results with the
   >    lab-notebook skill, recording every run automatically.
   > 6. On an unexpected blocker: comment progress on the issue, label
   >    `blocked`, notify me, continue with other experiments.
   > 7. On completion: comment a summary on the issue, spawn a Fable review
   >    of the results, post it as a comment, label `stage:done`.
   >
   > Also:
   > - Keep a session log in `docs/session-log.md` for a presentation. Start
   >   with the repo's bootstrap (reconstructed from git history), the
   >   state-of-the-art doc, and this prompt. Append one dated entry per
   >   milestone. Redact it as for any public content.
   > - Publish a dashboard artifact: one row per experiment with stage,
   >   labels, issue and PR links, last update and pending questions. Update
   >   it at every stage change.

5. **Setup.** Labels created (`experiment`, `stage:issue`, `stage:plan`,
   `stage:run`, `stage:done`, `needs-decision`, `blocked`). A dashboard
   artifact tracks the 13 experiments. Experiment #13 had no place in the
   order, so it joins the first wave with experiment #7, as the report
   suggests ("#7 and #13 (cheap)"). Experiment #11 uses the experiment #1
   workloads, so it runs after experiment #1 like experiment #12.
   The machine has 16 CPUs but little free memory and disk, so at most two
   experiments execute at once.

## 2026-11-19 — First workflow run: 13 issues, 13 reviews, 13 decisions

The workflow ran 39 agents in about 8 minutes (2.75 M subagent tokens, 515
tool calls). For every experiment it opened an issue, had Claude Fable 5.1
review it independently, posted the review as a comment, and applied the
review's decision-free fixes (8 to 13 per issue, several of them correcting
line citations into `upstream/`).

All 13 reviews also raised at least one point that changes scope, cost, tool
choice or done-criteria, so all 13 issues stopped at `needs-decision` before
any plan was written: 25 questions in total. The recurring themes:

- **Thresholds.** What "fast enough", "acceptable table cost" or "reaching
  the speed target" means, which the report left open.
- **Tool choice.** Which provers experiments #5, #8 and #9 cover, and who picks them
  after the eliminators.
- **Benchmark hygiene.** Where timing runs happen (shared workstation versus
  a dedicated machine) and how they avoid noise from fuzzing.
- **Scope edges.** Corpus sources and licences (experiment #1), legacy-encoding
  probes (experiment #2), sanitizer and fuzzer configurations
  (experiment #3), splitting experiment #12's dependency on experiment #10.

Issue numbers on GitHub do not match experiment numbers, since the issues
were opened in parallel.

## 2026-11-19 — Answers in the tracker; first experiment done

The maintainer answered on the issues; a monitor in the session picked up
each answer within a minute and resumed that experiment from its plan.
Plan reviews raised two more decisions (experiment #4: F\* to C through KaRaMeL,
Custard or both; experiment #11: root on the bench host for the CPU governor). The
maintainer moved experiments #3, #5, #7 and #11 to a dedicated bench host and raised the
cap on concurrent runs from 2 to 4.

**Experiment #2 (semantic probes) is the first one done**, about 25 minutes
after the answer: 134 probes on the C library under Debug and
ASan/UBSan builds, compared with JavaScript as Linden's reference. Verdicts:
Linden's semantics adapts for captures in loops, unset backreferences, empty
iterations and case folding; its lookbehind node must be rewritten (Oniguruma
steps back then matches forward, so captures differ). Three candidate
deviation-log entries came out of it. The Fable review replayed the run
byte for byte, then corrected one verdict by dumping the bytecode: the
capture-status check on empty iterations applies only to groups referenced
from outside the loop.

## 2026-11-19 — Pattern inventory done; deviation log started

**Experiment #1 (pattern inventory) is done**, about 70 minutes after the
answer. From pinned sources it extracted 5,870 distinct VS Code grammar
patterns, 44 jq and 73 PHP. Findings: 97.3% of patterns fall in the linear
ReDoS tier (hosts weighted equally); lookahead appears in 41% of VS Code
patterns and lookbehind in 24%; callouts never appear; the absent operator
appears twice; subexpression calls are rare (2%) but spread across 18 of 82
grammars. Proposed first subset: UTF-8, Oniguruma/Perl_NG/Ruby syntaxes,
linear-tier features plus backreferences, covering 97.9% of compiling
patterns. Five VS Code patterns that the older Oniguruma bundled in VS Code
accepts are rejected by `f95747b`. One incident: an uncapped capture log
filled the work disk for under a minute; the shim now caps it.

**Experiment #2 follow-up.** The review's fixes were applied and three
upstream behaviours became the first entries of `spec/deviations.md`
(DEV-001 to DEV-003): lookbehind acceptance that depends on optimiser order,
captures forbidden in negative lookbehind, and an empty-loop rule narrower
than the documentation.

Experiment #11 (performance baselines) now runs on the bench host with
experiment #1's workloads; experiments #3 and #7 run there too.

## 2026-11-19: experiment #13, Part C done

Experiment #13 (upgrade cost) was led from a separate interactive session,
outside the pipeline. It was then handed over to a background workflow,
from a handoff note.

**Part C (history mining) is done.** The mining tool ran on 8 projects over
one year, then Claude agents classified 66 rows by reading their diffs (all
48 that the plan requires). Observed adaptation per release: Rocq 12 to 103
lines per 9.x release after a 380 to 1,630-line 9.0 migration; Lean a median
of about 70, with a 9,220-line String API overhaul over three releases; F\*
a median of 0; Why3 about 470 to 513 forced lines in the gallery for 1.8.2
to 1.9.0; Verus about 147; Isabelle about 7. Results were posted on issue #3.

The Part A driver (`upgrade_builds`) was reviewed and committed, but not run
yet: it waits for the CPU set it may use on the bench host.

## 2026-11-20: eliminators report, first speed figures

- **Experiment #13 (upgrade cost)** and **experiment #4 (ABI
  feasibility)** were squash-merged; their branches are kept so the
  commit IDs cited in the results still resolve. Experiment #4 ended
  with no mechanism eliminated: all four routes (F\* via KaRaMeL or
  Custard, C proven with VST or Why3, Rust, Isabelle-LLVM) give a
  libonig drop-in, differing in the size of the hand-written C shell.
  Isabelle-LLVM's run used its own copy of the toolchain, reproduced
  from experiment #5's pins, rather than opening another account's
  directory.
- **Experiment #5 (calls to unverified code)**, led by Vincent Balat,
  finished its first two milestones: all six of the report's tools can
  call client C function pointers and be called back. F\*+Pulse and VST
  need no trusted shim (25 and 44 trusted lines); Why3, Verus, Aeneas
  and Isabelle-LLVM need one (100-128 lines). No stack is eliminated.
- With no stack eliminated, the maintainer lifted the wait on
  **experiment #6 (executable spec speed)**. Its milestone 1 ran in
  about 70 minutes: an OCaml reference interpreter and six provers
  (Rocq, Lean 4, Why3, F\*, Verus, Isabelle) agree with the C library on
  all 152 cases of experiment #9's subset, and every one of them can run
  10^6 cases in under 8 hours on one core; the interpreted modes of Why3
  and F\* only by a factor of 1.8.
- The results reviews keep catching real slips: an overstated
  function-pointer limit in Isabelle-LLVM (it can call named C
  functions), and in experiment #8 a peak-memory rule the reviewer
  misread, which a recomputation of all 16 cells settled.

## 2026-11-24: experiment #5 closed

- **Experiment #5 (calls to unverified code)** is done and merged
  (PR #21). Taken back into the pipeline on 2026-11-21, it ran four more
  milestones on the bench host: every one of the 14 tool rows now has a
  verdict, and no stack is eliminated. Only hax's Rocq backend fails;
  hax's Lean backend was not run, by decision. The trusted code ranges
  from 22 lines (CN) to 152 (RefinedRust). Pulse, VST and RefinedC can
  lend the subject read-only; the others lend it whole or through
  trusted glue.
- Two follow-ups remain: the upstream report of the F\* eta-reduction
  miscompilation (issue #29, drafted, awaiting the maintainer's
  approval) and an Isabelle-LLVM model of the C client (issue #30).
  Experiment #9's tool choice and experiment #6's milestone 2 (issue
  #28) no longer wait on anything.

## 2026-11-25: experiment #6, milestone 2 merged

- **Experiment #6, milestone 2 (issue #28)** is merged (PR #31). Stack G
  and six provers (Rocq, Lean 4, Why3, F\*, Verus, Isabelle) now run the
  semantics of experiment #1's first subset S2. Across 1,243 cases they
  agree with the C library, apart from five logged deviations (DEV-008
  once, DEV-004 four times). Every execution mode can run 10^6 cases in
  under 8 hours except Why3's interpreter (75 h) and the F\* normaliser
  (30 h).
- The larger spec raised the spec check times, which shrank experiment
  #7's ratios of table cost to spec cost from 27-101 to 5.1-30. None of
  its open verdicts is settled.
- The run produced DEV-008: an empty-loop rule that checks only the
  groups a backreference names, in every loop. It supersedes DEV-003,
  whose literal form was exponential on one upstream test.
- The run also found a type-mismatch bug in `why3 execute`. The
  maintainer handles the upstream report (issue #36).

## 2026-11-25: experiment #9 proves the VM in Rocq and F\*

- **Experiment #9 (representative proof), runs 1-3.** Before run 1, a
  Fable review of the plan's switch to DEV-008 found that no upstream
  case of the fragment exercises the empty-loop check. The plan now
  always adds experiment #2's loop probes. Run 1 wrote `FRAGMENT.md`,
  the design every tool copies, and selected the 66 upstream cases of
  the fragment, plus the 4 probes. Runs 1-3 wrote the AST, semantics,
  compiler and VM in Rocq, F\* and Verus. All three agree with C on every
  case and start position, and their outputs are byte-identical. Each
  run took under 30 minutes, with no human intervention.
- **Run 4: the Rocq theorem is closed** in one run instead of the three
  planned: 48 lemmas, `Print Assumptions` clean, 872 lines of proof,
  6.5 s to check. The run found that the statement is false unless the
  pattern's group numbers are distinct; a pattern parsed from text
  always satisfies this. The maintainer accepted that hypothesis for
  all three tools.
- **Run 7: the F\* theorem is closed**, also in one run: 43 lemmas and
  17 proof functions, all 503 SMT queries succeed at the first attempt,
  31.8 s to check (most of it in the simulation proof). Verus is next.
- **DEV-009.** Experiment #7 had left open 13 code points below U+0100,
  where the ISO-8859-1 ctype table and the Unicode data disagree. A
  probe of the C library showed that upstream contradicts itself:
  `\w` matches `²` but `[\w]` does not. The maintainer chose the Unicode
  data everywhere (PR #37).
- **Smaller decisions.** Issue #34 picks its SMT tool after experiment
  #9's F\* proofs. The maintainer reported the `why3 execute` bug on the
  why3-club mailing list (issue #36). Issue #25 (Verus and Isabelle
  builds for experiment #13) entered the pipeline and runs alongside
  experiment #9, on separate cores.

## 2026-11-25: experiment #9 done, Verus closes the third proof

- **Run 10: the Verus theorem is closed**, again in one run: 62 lemmas,
  1,556 lines of proof, 5.3 s to check on 7 threads. As first written,
  the statement could never be used by Verus's solver: its trigger only
  occurred under inner quantifiers. The maintainer accepted moving the
  body unchanged into a named spec function, which carries the trigger.
- **Runs 13-14: SMT brittleness.** The two SMT-based proofs were
  rechecked with three Z3 versions and 11 seeds each. Verus passes all
  33 checks, with wide margins; it refuses any Z3 but its own unless
  an opt-out flag is given. F\* passes 32 of 33: with Z3 4.15.3 and
  seed 4, one goal of the loop case runs out of solver budget, every
  time. The maintainer kept the proof as written, so the comparison
  reports the failure instead of hiding it.
- **Run 15: the comparison** of the three tools is posted on issue #4.
  Each tool needed one proof run of the three planned, about 25
  minutes, with no human intervention. Rocq automates least but checks
  fast and trusts no solver; F\* has the smallest proof but the slowest
  check and the only brittleness failure; Verus has the largest proof
  but the fastest check and an executable Rust VM for experiment #10.
  The comparison does not choose a stack.
- **Housekeeping.** Run 13's log archive recorded a local account name
  in its tar headers; the maintainer had it repacked, as a documented
  exception to the append-only rule. PR #32 is ready for review.

## 2026-11-26: upgrade cost for Verus and Isabelle, housekeeping

- **Issue #25 (experiment #13 follow-up)** measured what one upgrade
  costs on the two stacks experiment #13 could not build. Anvil, a
  Verus project pinned to a July release, fails on the release 16
  versions later, mostly on solver resource limits; porting it took 26
  changed lines and about two hours, and the ported proof checks 17%
  slower. The AFP regex entries fail on the next Isabelle release, half
  of the breakage in their AFP dependencies; porting took 34 minutes,
  and the AFP's own release made the same changes. One run on the bench
  host covered both. A fix agent answered two review questions on its
  own; the maintainer confirmed both answers afterwards, and the
  workflows now say that an answer covers only its own question.
- **Smaller items.** Issue #34 (discriminating lemmas) uses Rocq and
  Verus: experiment #9 found where F\* automation breaks, not where
  Verus's does. Issue #29 is closed, the F\* bug being filed upstream.
  Archives whose tar headers named local accounts were repacked
  (experiment #9's run 13, experiment #11's r2-r4, PR #38).

## 2026-11-26: Verus's automation strains, Isabelle-LLVM client

- **Issue #34 (experiment #8 follow-up)** proved two lemmas over
  symbolic subjects in Rocq and in Verus: lemma F (a literal prefix
  check) and lemma 2 (two desugarings of the absent operator agree).
  Both tools closed both, once lemma 2 gained the hypothesis
  `i <= rr <= length s` after Rocq found a counterexample without it.
  Lemma F costs Verus about 1% of its solver budget, so it does not
  tell the tools apart; lemma 2 does. Rocq took a 71-minute session and
  1,222 lines with no automation; Verus took 34 minutes and 2,142
  lines, but one function needs 64% of its solver budget (11% at most
  in experiment #9), and another fails at 2 of 11 seeds under a newer
  Z3. The comparison is on issue #34; PR #40 is ready for review.
- **Issue #30 (experiment #5 follow-up)** modelled caller.c's two
  clients in Isabelle-LLVM and proved they meet `respects_i_apply`
  (PR #41, merged); the trusted line count is 109.

## 2026-11-27: issue #34 closed, termination proved

- **Issue #34 (experiment #8 follow-up)** is merged (PR #40). The PR
  review found the posted comparison's limits incomplete: lemma 2 was
  conditional on termination, covers only experiment #8's constructs,
  and models only `onig_match` and a forward search of the whole
  subject. A bytecode dump confirmed the simple/general path split.
  The maintainer chose to prove termination (decision 8); run 5 did so
  in both tools, making lemma 2 unconditional. The extra Verus lemma
  made the crate fail under Verus's own Z3 at 2 of 11 seeds (25 of 33
  checks pass, against 31), and unchanged functions moved up to 90.5%
  of the solver budget. The maintainer kept that as the outcome
  (decision 9); splitting the lemma is later work.

## 2026-11-27: issue #22 retargeted and closed, upstream reports listed

- **Issue #22 (experiment #12 follow-up)** asked for OCaml generated by
  Why3 and Pulse, neither of which experiment #9 produced. The
  maintainer retargeted it to the OCaml that experiment #9 extracted
  from Rocq and from F\*, measured in experiment #12's table on the
  patterns inside experiment #9's fragment (about 18% of VS Code's
  searches, fewer for jq and PHP). Two runs on the bench host: every
  engine agrees with C on all 77,231 fragment calls. On large subjects
  Rocq runs at about 27 MB/s and F\* at about 20 MB/s, against 61 for
  the hand-written VM and 449-664 for C; alternations widen the gap to
  36-97 times C for Rocq and 90-235 times for F\*. Flambda speeds Rocq
  up by 19-31% but changes no ranking. On cost, the evidence points to
  bindings, more strongly than in experiment #12. PR #42 merged.
- **`docs/UPSTREAM.md`** lists the upstream reports: F\* issue and fix
  PR (FStarLang/FStar#4932, #4933), the Why3 mailing-list post, and two
  bugs found but not reported (a Why3 `-a compute` anomaly, a Verus
  double panic on an unsupported Z3), described in a separate doc.
