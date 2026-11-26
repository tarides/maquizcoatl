# Experiment #13: upgrade cost, summary with the Verus and Isabelle builds

Issue: https://github.com/tarides/maquizcoatl/issues/25 (follow-up of
issue #3). Plan: [`plans/13-upgrade-builds-df.md`](../../plans/13-upgrade-builds-df.md).
Source: maintainer's state-of-the-art report,
https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc (row 13 of "Experiments
before deciding").

This file completes [`2026-11-19-exp-13-summary.md`](2026-11-19-exp-13-summary.md),
whose Verus and Isabelle rows had their builds cell marked "not built
(follow-up issue)". The table below is that table with those two cells
filled from [`2026-11-26-exp-13-builds-df.md`](2026-11-26-exp-13-builds-df.md);
every other cell is copied unchanged (the 2026-11-19 file is not
rewritten; it carries a pointer to this one). The notes of the 2026-11-19
summary (agent-estimated shares, errata) still apply to the copied cells.

## One line per tool

| Tool (stack) | Builds: one release step on the latest code | Mining: hand-written adaptation per release crossed (median / mean) | Mining: per year, hand-written (per kLOC) | Upgrade cost observed |
| --- | --- | --- | --- | --- |
| Rocq (A, G) | Warblre unchanged; Linden unchanged once its Warblre pin moves (2 lines); latest / pinned 0.96 and 1.01 | Warblre 227 / 173, Linden 127 / 93 (mostly the 9.0 migration of releases before the window); after it, 12 to 103 per release | Warblre 863 (97), Linden 468 (19) | Low per release once on 9.x; the Coq to Rocq 9.0 rename was a one-off of a few hundred lines |
| Lean 4 (B) | lean-regex fails over 3 releases (4.34 to 4.36): 4 files, 24 lines, 8 min of rebuild cycles plus an unrecorded share of a 41-min gap; then 16% faster | 70.5 / 973 | 9,733 (710) | Highest: frequent releases (11 a year), tactic behaviour changes (`grind`, `simp`) at every step, and one large API overhaul (String, 4.25 to 4.27, 95% of the year) |
| F\* + Pulse (C) | Pulse examples fail over 1 release: 1 file, 2 lines (rlimit); latest / pinned 0.98 | EverParse 0 / 155 | 4,419 (35), of which 1,932 tracking unreleased F\* | Small but constant: 28 releases a year, proof repairs at many of them; paid by the F\* team for EverParse |
| Why3 (E, G) | Gallery 1.8.2 sessions with the same provers: reduced list 9 of 11 on both sides; full gallery (316 sessions finished on both sides before the budget ran out) 155 on 1.8.2, 157 on 1.9.0, 155 fail on both, 2 broken by 1.9.0 (`compute_specified` rename, a moved stdlib symbol), not ported | Gallery 157 for the one release | Gallery 157 (1.5); Creusot 23 (0.2), all tracking unreleased Why3 | Low for Why3 itself; the cost is in prover upgrades and regenerated sessions (515 lines with them in the gallery, 992 in Creusot) |
| Verus (D) | Anvil `3c95bbb` fails over 16 releases (0.2026.07.12 to 0.2026.11.22, Z3 4.12.5 to 4.16.0, Rust 1.96.0 to 1.100.0): 17 errors in 9 files, plus 1 in its dependency verus-tla; 16 of the 18 are solver-resource limits. Port: 9 files, 25 lines (17 per-function `rlimit(100)`, 2 `spinoff_prover`, one 6-line frame assertion), verus-tla 1 line, plus 3 scripted dependency lines; about 1 h 15 min hands-on (2 h 4 min elapsed); latest / pinned 1.17 | Anvil: 86 per release over the 49 releases of its active window | 4,194 (49); 3,578 more for an optional migration | Moderate per release, but 52 releases a year; Anvil tracks Verus HEAD; a solver upgrade inside Verus breaks proofs that were within their resource limits |
| Isabelle (F) | AFP 2025-2 regex entries fail over 1 release (Isabelle2025-2 to Isabelle2026): the entries need 8 lines in 7 files (`[code del]` discontinued, `cut` constant gone, veriT fact renamed to Alethe) and their AFP dependencies 8 lines in 7 files (Isabelle/ML API changes in Deriving and Show, `[code del]`); 34 min; the same 14 files are changed in AFP 2026; latest / pinned 0.98 | AFP regex entries 4 / 6.7 | 20 (0.9) | Very low for entry authors: the Isabelle developers adapt the AFP; an entry kept outside the AFP pays these few lines per release itself, mostly in its dependencies |

## Done-criteria of issue #25

| Criterion | Status | Where |
| --- | --- | --- |
| A notebook entry per sample project with criteria 1 to 4 of issue #3 | met for Anvil and the AFP regex entries | [`2026-11-26-exp-13-builds-df.md`](2026-11-26-exp-13-builds-df.md), notebook rows of 2026-11-26 |
| 1. Versions, dates, cadence | met: Verus 16 stable releases (rows appended to `releases/verus.tsv`), Isabelle 1 | builds-df entry |
| 2. Builds and checks unchanged, pinned and latest, with prover versions | met: both pinned sides ok, both latest sides fail unchanged; Z3 4.12.5 / 4.16.0 (Verus); z3, cvc5, veriT components of each Isabelle release | builds-df entry |
| 3. Failing files, error categories, patch, hands-on time within the half-day time box | met, both ports finished in the first run | builds-df entry, patches in `2026-11-26-exp-13-builds-df-files/` |
| 4. Wall-clock latest / pinned | met: Anvil 1.17, AFP regex entries 0.98 (final pairs, ported latest side) | builds-df entry, `2026-11-26-exp-13-builds-df.csv` |
| Fill the Verus and Isabelle cells through a new results file plus an erratum pointer | met | this file; pointer appended to `2026-11-19-exp-13-summary.md` |

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._
