# Experiment #13 follow-up: correction after the results review

Issue: https://github.com/tarides/maquizcoatl/issues/25. Review:
https://github.com/tarides/maquizcoatl/issues/25#issuecomment-7190029835
(decision-free fixes 1 to 6; decisions 1 and 2 taken by the maintainer,
option A for both). Nothing was run again and no ratio changes. This
entry corrects and completes
[`2026-11-26-exp-13-builds-df.md`](2026-11-26-exp-13-builds-df.md) and
[`2026-11-26-exp-13-summary-df.md`](2026-11-26-exp-13-summary-df.md),
which are not rewritten (each carries a pointer to this file).

## 1. Unported Anvil latest run: one wall-clock source

The run table and the "Criterion 4 before the port" paragraph give the
unported Anvil latest run (pair 1, 08:39:14 UTC) as 1,294.3 s, which is
Verus's own `total-time` (1,294,294 ms). Every other figure in that
column is the driver's wall clock. The driver's figure for this run, in
the CSV row and in
`2026-11-26-exp-13-builds-df-files/runs/anvil-latest-build-20261126T083914Z/steps.csv`,
is **1,295.1 s**. Read 1,295.1 s in both places, and "1,295 s" in the
Anvil notebook row (was "1,294 s"). The ratio against 823.5 s stays 1.57,
and it is still not a build-time ratio (the run stopped on 17 errors).

## 2. Load figures: the table's source

The "Load before / after" column of the run table is taken from
`2026-11-26-exp-13-builds-df-files/timed.times` (the 1-minute load
average written by the wrapper at the start and end of each timed run).
The CSV's `load_before` / `load_after` columns are the driver's own
samples, taken a few seconds apart from the wrapper's, so the two can
differ. The one visible gap: after the final Anvil latest run the table
says 3.38 (`timed.times`, 10:46:23 UTC) and the CSV says 3.59 (the
driver's sample).

## 3. Port timeline: not in the raw files

The port times in the builds entry (Anvil: start 07:58, verus-tla
repaired by 08:02, errors read from 08:27, unattended wait 08:57 to
09:47, full verification at 10:02; AFP: 08:27 to 09:01, reduction check
09:47) are Claude Code's own record of the session. Only two of them are
in the raw files: `logs/port-anvil-start` (2026-11-26T07:58:01Z) and
`logs/port-afp-start` (2026-11-26T08:27:40Z). The port logs carry no
timestamps, so the other times cannot be rebuilt from
`2026-11-26-exp-13-builds-df-files/logs/`. The elapsed 2 h 4 min for
Anvil is bounded by `port-anvil-start` and the end of the final untimed
verification; the 34 minutes for the AFP entries starts at
`port-afp-start`.

For future runs, the port wrapper should write a UTC timestamp before
and after each step (each focused re-run, full verification and rebuild
cycle) into the port log.

## 4. Hands-on time: agent-estimated, unchecked (decision 2, option A)

The Anvil port's "about 1 h 15 min" hands-on figure is an estimate by
Claude Code. It was not timed and cannot be checked from the logs
(section 3). It is accepted as stated, marked agent-estimated and
unchecked, as issue #3's spot-check waiver did for the agent-estimated
shares. The AFP port's 34 minutes is elapsed time from `port-afp-start`,
with the same caveat on its end time. Both ports are inside the half-day
time box whichever figure is used.

## 5. Criterion 1: the command behind the `verus.tsv` rows

The rows appended to `experiments/13-upgrade-cost/releases/verus.tsv`
were taken from

    gh api 'repos/verus-lang/verus/releases?per_page=15'

(as in [`plans/13-upgrade-builds-df.md`](../../plans/13-upgrade-builds-df.md)),
keeping stable releases only (`release/rolling/*` excluded).

## 6. "8 sessions"

The AFP regex target is the seven sessions of issue #25 plus
`Coinductive_Languages`, a dependant of `Regular-Sets` built with them and
reported apart in the builds entry. Read "8 sessions (the seven plus
`Coinductive_Languages`, reported apart)" in the AFP notebook row and in
the results comment on issue #25.

## 7. Summary table: the last column was extended too (decision 1, option A)

[`2026-11-26-exp-13-summary-df.md`](2026-11-26-exp-13-summary-df.md) says
that every cell other than the two builds cells is copied unchanged from
the 2026-11-19 summary. That is not exact: the "Upgrade cost observed"
cell of two rows was extended with what the builds add to the mining's
conclusion, and the extensions are kept:

- Verus (D): "a solver upgrade inside Verus breaks proofs that were
  within their resource limits";
- Isabelle (F): "an entry kept outside the AFP pays these few lines per
  release itself, mostly in its dependencies".

All other cells (the Rocq, Lean, F\* and Why3 rows, and the mining
columns of the Verus and Isabelle rows) are copied unchanged.

## 8. Outside the results files

`docs/experiments.md`: the "13 (follow-up)" row now links PR #39 and no
longer reads "after experiments #4 and #5".

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._
