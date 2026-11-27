# Experiment #8 follow-up (issue #34), entry 13: run-5 review fixes, corrections to entry 12

Date: 2026-11-27. Kind: correction entry; no prover run, nothing run on
the bench host. The lab notebook is append-only, so entry 12
([`2026-11-26-exp-08-lemmas-termination.md`](2026-11-26-exp-08-lemmas-termination.md))
stands as written and is corrected here.

**Why.** An independent review of run 5
([comment on issue #34](https://github.com/tarides/maquizcoatl/issues/34#issuecomment-7213374737))
recomputed every figure of entry 12 from its raw files and found them
right. It found four decision-free defects: one wrong word in entry 12,
and three documents that run 5 left stale (the plan, PR #40's
description and the unposted follow-up draft). This entry corrects the
word and records the other three fixes.

## Provenance

- Branch `exp/08-discriminating-lemmas`, commit `9b84bec` (entry 12's
  notebook commit). No source file under `lab/08-discriminating-lemmas/`
  changed; the hashes recorded in entries 4, 6 and 12 hold.
- No raw data: the corrections are read from entry 12's raw files
  (`2026-11-26-exp-08-lemmas-termination-raw/brittle/`), which the review
  recomputed.

## Corrections

### 1. Three passes of the matrix, not seven (entry 12, "Verus brittleness, rerun")

Entry 12 says "Seven passes of experiment #9's run-14 matrix". The
matrix ran **three passes, one per Z3 version** (4.16.0, 5.3.0, 4.15.3),
11 seeds each (default seed and `smt.random_seed` 1-10), 33 cells;
"seven" is the thread count. Read: "Three passes (one per Z3 version) of
experiment #9's run-14 matrix, on 7 threads". A reader of the original
sentence would take the matrix for 77 cells. The figures (25 of 33, 41
rows in `checks.tsv`) were already counted on 33 cells and stand.

## Documents brought up to date

### 2. The plan lists decision 8

`plans/08-discriminating-lemmas.md` listed decisions 1-7, and its run
table and stop rule still described run 5 as a reserve that continues
open proofs, or does not exist if both tools close in runs 2 and 3.
Run 5 was used for decision 8 instead. Added: decision 8
("Termination of the direct matcher: (a)") to the Decisions list, and,
after the stop rule, the sentence "Run 5 was used for decision 8
(termination), under the stop rule's second proof run for each tool."

### 3. PR #40's description

It still said "Termination is not proved, so lemma 2 is conditional",
listed four runs, and gave 31 of 33 with a 63.9% largest share. Updated
to: eight decisions; five runs, run 5 proving termination in both tools
(`m_term`, `absent_desugar_total`) and rerunning the matrix at 25 of 33
(`m_term_stack` failing at Z3 4.16.0 seeds 9 and 10 and at 5 unsupported
cells, `sim_a` at 5.3.0 seed 3); the termination limit dropped, the
other limits kept.

### 4. The unposted follow-up draft

The draft for issue #34 gave run 5's increments only. Added a bullet
"Table rows that change" under its Decision 8 section, from entry 12's
"Comparison update": proof lines 1,361 / 2,336; lemmas 114 / 108,
automatic 0 / 5; failed checks 31 / 9, failing invocations 34 / 13;
proof runs used 2 of 2; brittleness 25 of 33, highest share under
4.16.0 100% (fails), function checks above 10% 35 / 67 / 32 of 2,101;
the termination limit withdrawn. The draft is still unposted.

## Decision raised

The review's one decision-needed item (split `m_term_stack` and rerun
the matrix as a sixth run, or keep 25 of 33 as the outcome) is raised on
issue #34 and not acted on here.

## Effort

`effort.tsv`: one row for this correction (writing, one attempt).

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._
