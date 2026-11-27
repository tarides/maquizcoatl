# Experiment #8 follow-up (issue #34), entry 9: comparison with experiment #9 (run 4)

**What.** Run 4 of plan `plans/08-discriminating-lemmas.md`, second
part: one table in experiment #9's columns, with experiment #9's Rocq
and Verus rows beside this follow-up's, a short verdict per tool and per
lemma, and the stretch outcome (done-criterion 5, planned entry 6). No
prover was run for this entry. Every figure is copied from, or
recomputed from, the entries named in the "Source" column. Where a
correction entry supersedes a figure, the correction's figure is used.
The draft of the comparison comment for issue #34 is written from this
entry. It is posted only after the maintainer's review (plan, run 4).

**Why.** Plan, run 4: "comparison against experiment #9's table".
Experiment #9's table is the comparison comment on issue #4
(https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7175142784)
and its M4 entry ([2026-11-25-exp-09-m4-comparison.md](2026-11-25-exp-09-m4-comparison.md),
with [correction 10](2026-11-25-exp-09-correction-10.md)).

**Caveat.** One sample per tool, not independent. The same model wrote
both proofs from one shared design (`LEMMAS.md`), Rocq first (run 2),
then Verus (run 3). Verus transcribed the lemma structure Rocq had
found, so its effort figures are not from a fresh design. The same holds
for experiment #9, which ran in the order Rocq, F\*, Verus. No
person-days were spent.

## Table

"#9" is experiment #9 (VM against semantics, issue #4); "#34" is this
follow-up (lemma F and lemma 2). F\* is left out: issue #34 did not use
it (decision of 2026-11-25).

| | Rocq #9 | Verus #9 | Rocq #34 | Verus #34 | Source (#34) |
|---|---:|---:|---:|---:|---|
| **Effort** | | | | | |
| proof session (wall clock) | 25 min 51 s | 25 min 16 s | 70 min 39 s | 33 min 55 s | `effort.tsv` runs 2, 3 |
| proof compile window | under 9 min (not recorded) | 12 min 11 s | 54 min 34 s | 20 min 05 s | entries 4, 6 |
| proof runs used | 1 of 3 | 1 of 3 | 1 of 2 | 1 of 2 | stop rule (plan) |
| human interventions | 0 | 0 | 0 | 0 | entries 4, 6 |
| failing invocations | 19 | 6 | 29 | 13 | entries 5, 6 |
| failed checks | 19 | 6 | 27 | 9 | entries 5, 6 |
| **Size** (non-blank, non-comment lines, `loc.py`) | | | | | |
| definitions reused (#9: spec; #34: experiment #8's files with C1-C6) | 137 | 183 | 149 | 229 | entries 4, 6 |
| new definitions (#9: compiler + VM; #34: `desugar`, `md`) | 153 | 207 | 112 | 125 | entries 4, 6 |
| auxiliary spec in the proof files | - | - | 84 | 166 | entries 4, 6 |
| proof | 872 | 1,556 | 1,222 | 2,142 | entries 4, 6 |
| of which lemma F and the stretch | - | - | 90 | 201 | entries 4, 6 |
| of which lemma 2 | - | - | 1,132 | 1,941 | entries 4, 6 |
| exec mirrors | - | 812 | - | - | |
| **Full check** (median of 3, pinned) | | | | | |
| wall clock, like for like (no cases file) | 6.50 s | 5.27 s | 11.19 s | 13.72 s | entries 5, 7 |
| CPU (user + system), threads | 6.44 s, 1 | 9.49 s, 7 | 11.15 s, 1 | 15.08 s, 7 | entries 5, 7 |
| whole Verus crate with the 29 `compute_only` cases | - | - | - | 33.01 s | entry 6 |
| **Lemmas** | | | | | |
| lemmas | 48 | 62 (16 return witnesses) | 105 | 99 (24 return witnesses) | entries 4, 7 |
| automatic (empty body / one automation call) | 0 (0%) | 3 (4.8%) | 0 (0%) | 4 (4.0%), body rule corrected by hand | entries 4, 7 |
| **Done-criterion 1** | closed under the global context | 135 verified, 0 errors, plain and `--no-cheating` | `sharp_s_sym`, `absent_desugar_eq` closed under the global context; scan empty | 179 verified, 0 errors, plain and `--no-cheating`; scan empty | entries 4, 6 |
| **Done-criterion 2** (agreement) | 66/66 searches, 273/273 starts, probes | same | 29/29 cases: C Debug = ASan = `m` = `md`; equal lists of ends at every start | same, by `compute_only` | entries 2, 6 |
| **Done-criterion 4** (brittleness) | not applicable | 33 of 33 | not applicable | **31 of 33** | entry 8 |
| failure | - | none | - | Z3 5.3.0, default seed and seed 10: `sim_a` (direction (2a)) exceeds the rlimit (100%); both replicated | entry 8 |
| highest share, supported Z3 4.16.0 | - | 11.3% (`case_star_nn`) | - | 63.9% (`term_core`, seed 10); 11 of 11 pass | entry 8 |
| highest share, Z3 5.3.0 / 4.15.3 (unsupported) | - | 34% / 14.1% | - | 100% (fails) / 43.4% | entry 8 |
| function checks above 10% (4.16.0 / 5.3.0 / 4.15.3) | - | 2 / 9 / 1 of 1,364 | - | 15 / 37 / 17 of 1,969 | entry 8 |
| other solver versions | - | refused without `-V no-solver-version-check` (panic, exit 134) | - | same | entry 8 |
| **Stretch** (decision 6) | | | closed (`fold_lit`) | closed (`fold_lit`), first attempt | entries 4, 6 |
| **Range clear** (decision 2) | | | proved, about 47 lines | proved, about 90 lines | entries 4, 6 |

Notes on the table:

- **Session times.** The proof session of #34 is run 2 (Rocq) and run 3
  (Verus). Run 3 included the Verus definitions, the agreement and the
  measurements; run 2 included the mutation rerun and the measurements.
  Run 1 (shared design, cases, Rocq definitions, 12 min 41 s) is in
  neither. The Verus session is shorter partly because the lemma
  structure was already known.
- **Failed checks.** Rocq #34: 29 failing invocations less the two `Show`
  reads; the two interrupted runs are in neither figure (entry 5).
  Verus #34: 13 failing invocations less the 4 rejected before
  verification (entry 6).
- **Definitions.** The "reused" row of #34 is experiment #8's `Fold` and
  `Absent` files as changed by C1-C6 (Rocq 64 + 85, Verus 96 + 133); the
  experiment #8 proofs left in them (Rocq 33, Verus 38 lines) are not in
  the proof row. #9's rows are its spec and compiler + VM, which are not
  the same kind of definition.
- **Check time.** The like-for-like figure is the one without a cases
  file, as the run-3 review recommended: Rocq's 11.19 s excludes
  `Cases.v` (`timed.sh`'s default), and experiment #9's 5.27 s was timed
  on a crate without one. The Verus 13.72 s series was run by hand under
  `timed.sh`'s conditions (entry 7 has the record; its thread listing
  before the series was not written).
- **Automatic share.** `lemmas.py` gives 3 for Verus #34; it misreads the
  body of seven lemmas whose `ensures` has a brace block, and the hand
  correction gives 4 (entry 7). Experiment #9's 3 of 62 are unaffected.
- **Margins.** As in experiment #9, Verus's margin is a function's total
  rlimit count against the per-function limit of 30,000,000 (default
  `--rlimit 10`, unit rechecked in entry 8). It is an upper bound for any
  one query, and it holds at the default limit only.
- **Matrix wall clock.** The #34 cells take about 33 s, of which about
  19 s is the 29 `compute_only` cases; experiment #9's matrix cells had
  no cases (5.30 s median). CPU medians per version are in entry 8.

## Verdicts

**Per lemma.**

- **Lemma F (scoped, F1 and F2).** Not discriminating, as the issue
  review predicted (question 6). Rocq: 90 proof lines with the stretch,
  1 failed check. Verus: 201 lines with the stretch, 1 failed check, and
  no function of `fold_proof` above 1.0% of the rlimit in any of the 33
  cells. Both state it for every fuel above the tight bound 7, without
  the constant fuel.
- **Stretch (decision 6): closed in both tools.** `fold_lit`, the
  one-level fold statement for every literal, at fuel equal to the number
  of alternatives plus 2. Verus closed it at the first check.
- **Lemma 2 (absent desugaring equivalence).** This is where the tools
  differ. It closed in one proof run in each tool, for `AbsRep`, `AbsExp`
  on both paths, the stopper and the range clear, under `i <= rr <=
  length s` (a hypothesis run 1's statement lacked; registers above the
  subject length are excluded). Rocq: 1,132 proof lines, 27 failed
  checks, all of them tactic-script errors. Verus: 1,941 lines, 9 failed
  checks, one of them an rlimit failure during development, fixed by
  splitting `sim_b`. Its brittleness matrix has the first failing cells
  recorded for Verus (experiment #9's had none):
  - under the supported Z3 4.16.0, every cell passes, but `term_core`
    reaches 63.9% of the limit, and its share moves from 5.9% to 63.9%
    across seeds;
  - under the unsupported Z3 5.3.0, `sim_a` fails at 2 of 11 seeds,
    deterministically.

**Per tool.**

- **Rocq.** Both lemmas closed under the global context in one run, with
  no SMT solver in the trusted base, so done-criterion 4 does not apply.
  Measured against experiment #9, it took more effort: a 71-minute
  session, 27 failed checks and 1,222 proof lines, against 26 minutes,
  19 failed checks and 872 lines. No lemma is automatic (0 of 105). The
  full check is 11.19 s on one thread.
- **Verus.** Both lemmas closed in one run, plain and with
  `--no-cheating`, in a 34-minute session with 9 failed checks. It has
  the largest proof (2,142 lines, 1.75 times Rocq's). Most of the extra
  lines are explicit unfoldings, because Z3 does not unfold the
  desugared matcher beyond one level. The full check without cases is
  13.72 s on 7 threads (15.08 s CPU). Automation breaks on the large
  case analyses of lemma 2:
  - once in development, on size (the unsplit `sim_b`);
  - in the matrix, at 2 of 33 cells, both under an unsupported solver;
  - its margin under the supported solver is 63.9%, against experiment
    #9's 11.3%.

  This answers the question for which issue #34 picked Verus (the
  maintainer's rule of 2026-11-25): on a proof of this size, Verus's
  default limit is no longer wide. The margin is now comparable to F\*'s
  74% in experiment #9 (that figure is per query, against a per-query
  rlimit).

**Across the two experiments.** Done-criteria 1-3 are met for both tools.
Done-criterion 4 is met for Verus: 33 cells recorded, 2 failures with
their function and share. Done-criterion 5 is this entry. Each tool used
one proof run of the two the stop rule allows, so run 5 is not needed.
This comparison does not choose a stack.

## Limits

These apply to both tools and are carried from entries 4 and 6:

- Lemma 2 rests on the state-threaded model `md` of the C desugaring.
  Its faithfulness to `match_at` is checked only on the 29 cases of the
  corpus, as first matches (decision 4).
- Fuel adequacy is not covered: both directions are existential in the
  other side's fuel (decision 3).
- Nested absent constructs are out of scope, and registers above the
  subject length are excluded.
- On the simple path, `AbsExp a (Star (Chr c))`, the dispatch rests on
  the reading of `upstream/src/regparse.c:3194-3236`, not on a C case.
  No corpus case distinguishes the two paths (mutant M6, entry 4).
- `fold_lit`'s bound is the proved one: alternatives plus 2.
- The Verus margins are per function, an upper bound for any one query,
  and hold at the default limit only. Every query-level comparison with
  F\* inherits that difference.

## Effort

This entry: no prover run; the figures are from entries 2-8 and from
experiment #9's comment on issue #4. The draft comment is
`<workdir>/tmp/i34-comparison-comment.md` (outside the repository),
posted after the maintainer's review.

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._
