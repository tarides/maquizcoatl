# Experiment #13, Part C: observed adaptation cost per release

Plan: [`plans/13-upgrade-cost.md`](../../plans/13-upgrade-cost.md).
Issue: https://github.com/tarides/maquizcoatl/issues/3.

**Part A (builds of a pinned project against the next release) is still
to come.** It waits for the CPU set it may use on the bench host. The
figures below come from project history only (Part C): lines changed
(added plus removed) in commits that adapt a project to a new release of
its tool, after manual classification of every large row. Window:
2025-11-19 to 2026-11-19.

| Tool | Projects | Observed adaptation cost per release | Main caveat |
| --- | --- | --- | --- |
| Rocq | Warblre, Linden | The 9.0 migration (spread over 3 releases) cost 380 lines (Linden) and about 1,630 (Warblre; about 790 if file renames are counted as renames). Each later 9.x release cost 12 to 103 lines. | Linden has no 9.3 bump in the window. |
| Lean | lean-regex | Median about 70 lines per release over 10 series (4.25 to 4.34). The String API overhaul of 4.25 to 4.27 alone cost about 9,220 lines, 95% of the 9,750 adaptation lines. | The 4.26 figure is an upper bound: the project's CI rejects deprecation warnings. |
| F\* | EverParse (CBOR, LowParse) | Median 0 lines per release: 19 of 21 bumps change nothing. 33 lines in v2026.11.15, plus 174 lines for an F\* fix not yet in a release. | Lower bound: EverParse is maintained by the F\* team. |
| Why3 | Why3 gallery, Creusot | One release step (1.8.2 to 1.9.0). Gallery: about 470 to 513 forced lines, 0.6% of an 82,849-line diff. Creusot: about 990 lines over 5 bumps, of which about 27 were written by hand. | Mostly regenerated proof sessions; Part A's replay is the real Why3 datum. |
| Verus | Anvil | About 147 lines per release over the 53 releases of the window (about 79 without the optional `cargo verus` migration): 7,806 of 61,860 lines. | Pins name Verus commits, not releases, so the per-release figure is a plain division. |
| Isabelle | AFP regex entries | About 7 lines per release: 20 lines over 3 releases. | All done by Isabelle developers in AFP-wide sweeps. |

Details, decisions and limits:
[`2026-11-19-exp-13-classification.md`](2026-11-19-exp-13-classification.md).
Raw tables and provenance:
[`2026-11-19-exp-13-mining.md`](2026-11-19-exp-13-mining.md).
