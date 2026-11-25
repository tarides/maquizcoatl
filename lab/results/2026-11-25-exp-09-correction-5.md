# Experiment #9, entry 12: run-4 review fixes (correction 5)

**What.** Three decision-free fixes from the independent review of run 4
([issue #4 comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7164595874)).
Entries 10 and 11 ([Rocq M2](2026-11-25-exp-09-rocq-m2.md),
[measurements](2026-11-25-exp-09-rocq-measure.md)) are not edited; their
figures all hold (the review recomputed them). Nothing was rerun, timed
or run on the bench host: the changes are comments, prose in
`FRAGMENT.md` and recording rules in the plan.

**Why.** Section 8 of `FRAGMENT.md` and the two SMT statement files are
what the F\* and Verus M2 runs transcribe; the attempt figures feed the
M4 comparison table.

## Fix 1: lemma (d) no longer promises a VM step bound

`FRAGMENT.md` section 8 (d) said that "the VM finishes within a number of
steps bounded by the tree's size times the code length". Rocq proved no
such bound and the theorem does not need one (section 8, "How Rocq
closed it"). (d) now reads as the two existence claims: some fuel makes
the semantics finish (bound from `mu`, result stable under more fuel),
and some fuel makes the VM finish.

## Fix 2: the SMT statements are flagged as not yet section 7

`fstar/Statement.fst` and `verus/statement.rs` lack the hypothesis
`NoDup (groups r)` that run 4 added to section 7, so they state a false
theorem while their headers cite section 7. Each header now says so and
points at section 7's paragraph "Distinct group numbers (run 4)". The
hypothesis and `groups` are transcribed once the maintainer accepts the
hypothesis (a decision, listed on issue #4); this is statement-only,
neither file is extracted, so nothing is to rerun. The edits are
comments only; the files were not rechecked.

## Fix 3: attempt units and proof-time timestamps

Two attempt units coexist in the records:

| Figure | Unit | Rocq M2 (run 4) |
|---|---|---:|
| failed checks | a compile that fails and leads to an edit | 19 |
| compile invocations | one `rocq compile` call of the edit loop (19 failed + 4 clean) | 23 |
| `effort.tsv` attempts | per lemma: a clean compile counts once per lemma it contains | 67 |

Run 3's Verus rows count attempts per module (definition file), not per
lemma. Failed checks and invocations are the figures comparable across
tools. The plan's M4 step now requires each attempt figure in the table
to name its unit.

Entry 10's "under 9 minutes of wall clock" for the proof is bounded by
two timestamps of other checks (13:38:46Z and 13:47:43Z), not by
recorded first and last proof compiles, so it cannot be checked from the
repository beyond that bound. The plan's effort-recording section now
asks each M2 run to record in `effort.tsv` the UTC timestamps of the
first and the last compile of the proof (applies from the F\* M2 run
on; run 4's are not recoverable).

## Provenance

Branch `exp/09-representative-proof` at `617116e` plus this commit.
Files changed: `lab/09-representative-proof/FRAGMENT.md` (section 8 (d)),
`lab/09-representative-proof/fstar/Statement.fst` and
`lab/09-representative-proof/verus/statement.rs` (header comments),
`plans/09-representative-proof.md` (M4 step and effort recording),
`lab/09-representative-proof/effort.tsv` (rows `4-fix`).

## Effort

[effort.tsv](../09-representative-proof/effort.tsv), rows `4-fix`. Human
interventions: 0.

## Open

- Decision needed (issue #4): accept `NoDup (groups r)` in the
  statement for the three tools.
