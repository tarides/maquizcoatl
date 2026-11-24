# exp-11 re-runs r2-r4: agreement with Oniguruma

## What

The check phase of runs r2, r3 and r4 (every column on every workload,
untimed), compared with r1. Files:

- `2026-11-19-exp-11-rerun-agreement.csv`: the counts per column and
  workload, identical in r2, r3 and r4, with the one-pass duration of
  each run (`one_pass_seconds_r2`, `_r3`, `_r4`);
- `2026-11-19-exp-11-rerun-disagreements.csv`: the disagreeing
  patterns, identical in r2, r3 and r4 (a copy of
  `2026-11-19-exp-11-r2-disagreements.csv`);
- the raw check outputs and `only/` pattern lists are in
  `2026-11-19-exp-11-rN-outputs.tar.xz`.

## Why

The review of the partial fix on issue #2 asked to show that the RE2
and Rust harnesses, which now extract every capture group, keep the
same agreement and the same timing subsets as r1.

## Provenance

- Runs, repository and machine: as in
  `2026-11-19-exp-11-rerun-throughput.md` (bench clone at `11c2545`,
  check phase of `run.sh rN all`, on `BUILD_CPUS` with 4 jobs).
- r1 reference: `2026-11-19-exp-11-agreement.csv`,
  `2026-11-19-exp-11-r1-reclassified-disagreements.csv` and
  `2026-11-19-exp-11-r1-check-outputs.tar.xz`.
- Comparisons made on the workstation with `cut`, `cmp` and `diff`.

## Parameters

`agree.py` as fixed in `dd041de` (classifier order), run by `run.sh`
on each run's check outputs.

## Raw data (summary)

- Counts: in each of r2, r3 and r4, the first 12 columns of
  `agreement.csv` (patterns, accepted, rejected, unsupported, resource
  limited, disagreeing, timed patterns, pairs compared) are identical to
  r1's. Only `one_pass_seconds` changes.
- Disagreements: `disagreements.csv` of r2, r3 and r4 are byte-identical
  to each other and to r1's re-classified file: the same 103 (column,
  pattern) rows with the same classes.
- Pattern lists: the `only/` lists of r2, r3 and r4 are byte-identical
  to r1's, so every run times the same subsets.
- Check outputs: for each of the 35 (column, workload) cells, the check
  output of r2, r3 and r4 equals r1's once the `PASS` duration line is
  removed: same compile statuses and reasons, same match bounds for every
  pair.

## Analysis and open questions

- Capture extraction does not change what RE2 and Rust `regex` match:
  their overall match bounds are the same as in r1, where they asked for
  the overall match only. Criterion 3 of issue #2 holds unchanged for
  r2-r4.
- The check listing reports the overall match only. The contents of the
  capture groups are computed but not compared between engines; such a
  comparison would need a new check mode.
