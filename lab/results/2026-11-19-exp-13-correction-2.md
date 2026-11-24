# Experiment #13: second correction, after the results review

Issue: https://github.com/tarides/maquizcoatl/issues/3. Review:
https://github.com/tarides/maquizcoatl/issues/3#issuecomment-7022484214
(problems 2 to 5 and 7; problems 1 and 6 are in
[`2026-11-19-exp-13-correction.md`](2026-11-19-exp-13-correction.md)).
Nothing was run again. One figure changes (section 1); the rest is
wording, and per-project notebook rows are added (section 4).

## 1. Why3 full gallery: off by one

`multiprecision/set_str` finished on the pinned side (exit 1, 77.0 s) but
was interrupted on the latest side (30.9 s, at the end of the budget).
The builds entry counted it among the sessions "replayed on both sides"
and among those that "fail on both". Recomputed from the two
`steps.csv` of the counted runs
(`2026-11-19-exp-13-builds-files/runs/why3-gallery-{pinned,latest}-build-20261119T192137Z/`),
counting only sessions that ended with `ok` or an exit code on both
sides, `prover/Prover` excluded (stopped on both sides):

| Figure | Recorded | Corrected |
| --- | --- | --- |
| Sessions finished on both sides | 317 | 316 |
| Replay on 1.8.2 / on 1.9.0 / on both | 155 / 157 / 151 | unchanged |
| Fail on both | 156 | 155 |
| Wall-clock, pinned / latest (s) | 4,901 / 6,462 | 4,824 / 6,431 |
| Latest / pinned | 1.32 | 1.33 |

The ratio stays indicative only (both sides ran at the same time on two
complexes). The sessions after it (from `multiprecision/sqrt` on the
pinned side) were never reached on the latest side and were not counted
before either.

## 2. lean-regex hands-on time

The builds entry gave "about 45 minutes wall-clock, three rebuild
cycles". `run-times.txt` does not support a single 45-minute span: the
three failing latest runs went from 18:17:49 to 18:25:34 UTC (8 minutes),
then the successful latest run started at 19:06:39, after a 41-minute gap
during which the Warblre and Why3 problems were also handled. The time is
now given as: 8 minutes of rebuild cycles plus an unrecorded share of a
41-minute gap, by Claude Code.

## 3. Wording

- **Load.** The builds entry said the load average was 0.00 at the start
  (18:07 UTC), which reads as if the host were idle during the timings.
  During the counted runs, the one-minute load average was between 1.4
  and 9.1 (recorded before and after each row in `builds.csv`), from this
  experiment's own concurrent projects on the other complexes; no timed
  run of another experiment was active.
- **Linden.** "Linden unchanged" in the Results comment becomes
  "unchanged once its Warblre pin moves (2 lines)", as in the summary's
  one-line table: the dependency move is a cost.

## 4. One notebook row per project

The issue's done-criteria ask for "a lab-notebook entry" for each of the
five projects; the notebook had one row for all five. Five rows, one per
project, are appended to [`../notebook.md`](../notebook.md), each pointing
to the builds entry. The original row stays.

## Where the corrections were applied

- [`2026-11-19-exp-13-builds.md`](2026-11-19-exp-13-builds.md): erratum
  pointer; the load sentence and the lean-regex time are reworded in
  place; the Why3 table cells keep the recorded figures, the pointer
  gives the corrected ones.
- [`2026-11-19-exp-13-summary.md`](2026-11-19-exp-13-summary.md): the
  corrected Why3 counts and the lean-regex time.
- [`../../plans/13-upgrade-cost.md`](../../plans/13-upgrade-cost.md):
  the builds as run and their deviations (review problem 2).
- The Results comment on the issue
  (https://github.com/tarides/maquizcoatl/issues/3#issuecomment-7022338970).

## Provenance

- Branch `exp/13-upgrade-cost`, on top of `5702fd8`. Recount with a short
  Python script over the two `steps.csv` files (outcome `ok` or
  `exit N` on both sides). Text changes made by Claude Code (Opus 5.5)
  on the maintainer's instruction.
