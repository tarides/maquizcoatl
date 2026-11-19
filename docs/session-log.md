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
   grown to 13 (#13, upgrade cost, was added later). Claude listed them from
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
   artifact tracks the 13 experiments. #13 had no place in the order, so it
   joins the first wave with #7, as the report suggests ("#7 and #13
   (cheap)"). #11 uses the #1 workloads, so it runs after #1 like #12.
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
- **Tool choice.** Which provers #5, #8 and #9 cover, and who picks them
  after the eliminators.
- **Benchmark hygiene.** Where timing runs happen (shared workstation versus
  a dedicated machine) and how they avoid noise from fuzzing.
- **Scope edges.** Corpus sources and licences (#1), legacy-encoding probes
  (#2), sanitizer and fuzzer configurations (#3), splitting #12's dependency
  on #10.

Issue numbers on GitHub do not match experiment numbers, since the issues
were opened in parallel.
