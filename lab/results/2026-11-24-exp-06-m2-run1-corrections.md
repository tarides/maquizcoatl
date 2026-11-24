# Experiment #6, milestone 2: corrections to run 1's entries (review follow-ups)

**What.** Corrections to three of run 1's entries, from the small
follow-ups of the run 1 review
(https://github.com/tarides/maquizcoatl/issues/28#issuecomment-7135797879).
The entries themselves are not edited (the notebook is append only). No
new run.

**Why.** Each point would make a reader recompute or misread a figure.
The maintainer's decisions after run 1 put them in run 2 without a
decision
(https://github.com/tarides/maquizcoatl/issues/28#issuecomment-7136902494).

## Provenance

Reading of run 1's committed raw files at `0978ba8` (branch
`exp/06-spec-speed-m2`); the `provenance.sh` change is in `e293368`.

## Corrections

1. **[Cases entry](2026-11-24-exp-06-m2-cases.md), table row "ctypes
   used by the 1,160 emitted cases (plus 12, word, for `\b`)".** The
   list of 24 is right, but its wording is not. `g2 classify` prints 22
   ctypes (`classify.log`: 1 3 6 8 10 11 12 13 14 37 56 75 81 103 131
   149 173 209 231 285 290 406). `cases/gen2.py` adds the two that it
   also finds in the emitted ASTs, **4 (digit) and 9 (space)**, to give
   the 24 of `used-ctypes.txt`. Ctype 12 (word) is already in the
   classifier's list; `gen2.py` adds it in any case, for `\b`. Read the
   row as "24: the classifier's 22 plus 4 and 9".
2. **[Throughput entry](2026-11-24-exp-06-m2-throughput.md), the "Eval
   s" columns** (in-prover table and spot-check table). "Eval s" is the
   wall-clock of the whole evaluation command (`QX`, `QN`, `QXF`, ...),
   which includes the import-only baseline Q0. The cases/s columns
   subtract Q0: `why3 execute` is 1,160 / (316.04 - 1.93) = 3.69, not
   1,160 / 316.04. Read the column as "command wall-clock s (Q0
   included)". The figures and verdicts are unchanged.
3. **[Raw provenance](2026-11-24-exp-06-m2-raw/provenance.txt)
   (`provenance.sh`).** Its line "untimed work on CPUs 4-7 under nice
   -n 10" and "branch exp/06-spec-speed" are milestone 1's text. The
   [provenance entry](2026-11-24-exp-06-m2-provenance.md) already
   explains this. `provenance.sh` now prints milestone 2's lines when
   run with `M=2`: "untimed work at most 4 jobs on CPUs 0-15 under nice
   -n 10 (milestone 2)" and the branch `exp/06-spec-speed-m2`. Run 2's
   [provenance](2026-11-24-exp-06-m2-run2-raw/provenance.txt) uses it.

## Analysis

None of the three changes a figure, a verdict or an agreement count of
run 1. The review's other follow-up (PR #31's `stage:plan` label) was
fixed on the PR; it is not a notebook matter.
