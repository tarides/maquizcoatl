# Experiment #12 follow-up (issue #22), entry 14: corrections after the run 2 review

**What.** Corrections to entries 10, 11 and 13 of run `x2` after the
independent review of run 2 (issue #22 comment of 2026-11-27, 15:50
UTC, problems 1 and 2). No series was rerun and no raw file changed.
Two comparison figures were recomputed from files already recorded.
Entries 9-13 are left as recorded; this entry supersedes the sentences
named below.

**Why.** Entry 11 compared run 2's hand-written VM with experiment #12
per pattern and wrote "within 1.2% on the four alternations", which
holds at 16 MiB only, and "4.6-5.0% slower on `/\*`", which does not
recompute and has the direction reversed in the context paragraph.
Entries 11 and 13 and the notebook row use the first statement to say
that run 1's VM speed-up is confined to literals; at 1 MiB the
alternations show about a third of it. Entry 10 gave the F\* column's
minor-word reduction under flambda as 1-12%; the smallest is 0.4%.

Provenance: entries [10](2026-11-27-exp-12-followup-run2-short.md),
[11](2026-11-27-exp-12-followup-run2-large.md) and
[13](2026-11-27-exp-12-followup-run2-conclusion.md) at `e2a0618`.
Recomputation on the workstation from
`2026-11-27-exp-12-followup-run2-raw/summary/large-patterns.csv` (rows
`run` = `x2`), `2026-11-19-exp-12-raw/summary/large-patterns.csv` and
`2026-11-27-exp-12-followup-run2-raw/summary/short-x2-summary.csv`,
matching rows on (engine, source, size, pattern id). Effort: about 20
minutes, Claude Code.

## 1. The VM against experiment #12 on the run 2 patterns (supersedes entry 11's context paragraph and its "run 1 VM speed-up" bullet, and entry 13's large-shape limit)

Median MB/s of `vm`, run 2 against experiment #12, and run 2's
difference:

| Pattern | Source | 1 MiB | 16 MiB |
|---|---|---|---|
| `/\*` | log | 60.85 / 58.13, +4.7% | 60.90 / 58.16, +4.7% |
| `/\*` | src | 60.76 / 58.02, +4.7% | 60.64 / 57.89, +4.7% |
| `<<\|>>>\|>>` | log | 24.39 / 24.28, +0.4% | 24.44 / 24.36, +0.3% |
| `<<\|>>>\|>>` | src | 24.33 / 24.24, +0.4% | 24.36 / 24.29, +0.3% |
| `\&\|~\|\^\|\|` | log | 21.90 / 21.43, +2.2% | 21.65 / 21.70, -0.2% |
| `\&\|~\|\^\|\|` | src | 21.44 / 21.05, +1.9% | 21.73 / 21.48, +1.2% |
| `%\|\*\|/\|-\|\+` | log | 17.79 / 17.51, +1.6% | 17.73 / 17.54, +1.1% |
| `%\|\*\|/\|-\|\+` | src | 17.25 / 17.26, -0.1% | 17.27 / 17.37, -0.6% |
| `<=\|>=\|<>\|<\|>` | src | 15.91 / 15.79, +0.8% | 15.91 / 16.04, -0.8% |

Corrected statements:

- On the four alternations run 2's `vm` is within 1.2% of experiment
  #12's at 16 MiB (-0.8..+1.2%) and within 2.2% at 1 MiB
  (-0.1..+2.2%).
- On `/\*` run 2's `vm` is 4.7% faster than experiment #12's on all
  four cells (experiment #12's is 4.5% below run 2's), not "4.6-5.0%
  slower" (entry 11's context paragraph) nor "4.6-5.0% faster" (its
  analysis bullet).
- Run 2's `c` is within 1% of experiment #12's on every cell, as entry
  11 states; entry 13's limit "run 2's `c` and `vm` are within 1.2%"
  reads: `c` within 1%, `vm` within 1.2% at 16 MiB and 2.2% at 1 MiB.

The conclusion is unchanged: the run 1 VM speed-up over experiment #12
(6-7% on ranks 1-10, [entry 8](2026-11-27-exp-12-followup-correction.md))
shows mainly on the literal patterns, with 4.7% on `/\*` and at most
2.2% on the alternations. Its cause is still not investigated.

## 2. Entry 10: the F\* column's minor words under flambda (supersedes "with 1-12% fewer minor words")

Minor words per call, `fstar` against `fstar-flambda`:

| Family | `fstar` | `fstar-flambda` | reduction |
|---|---:|---:|---:|
| jq | 97.65 | 95.65 | 2.0% |
| PHP | 79.35 | 77.38 | 2.5% |
| VS Code | 530.58 | 528.58 | 0.4% |
| long PHP | 48.30 | 42.30 | 12.4% |

The sentence reads "with 0.4-12% fewer minor words". The analysis is
unchanged.

## Not covered here

The review's problem 5 (whether the `vm-flambda` column is accepted
under decision 8) awaits the maintainer's decision on issue #22. Its
problems 3 and 4 concern the unposted results draft only and are
applied there.
