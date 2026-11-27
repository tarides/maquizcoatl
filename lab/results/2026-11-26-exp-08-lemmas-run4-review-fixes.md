# Experiment #8 follow-up (issue #34), entry 10: corrections after the run-4 review

**What.** Corrections to entry 8
([2026-11-26-exp-08-lemmas-brittle.md](2026-11-26-exp-08-lemmas-brittle.md))
and entry 9
([2026-11-26-exp-08-lemmas-comparison.md](2026-11-26-exp-08-lemmas-comparison.md))
required by the independent review of run 4 on issue #34
([comment](https://github.com/tarides/maquizcoatl/issues/34#issuecomment-7198185397)),
problems 1-3. No new run: every figure below is read from entry 8's raw
files. Entries 8 and 9 are left as recorded. This entry supersedes the
passages it names.

**Why.** The review confirmed run 4 (33 cells recorded, the refusal
once, both failures replicated and kept, every figure of entries 8 and 9
recomputed from the raw files, sources unchanged since `2242606`). It
found two wording slips and one sentence that sets two different units
side by side more closely than they allow. None of the three changes a
verdict.

## Provenance

Text corrections only, on the data of entry 8 (branch commit `c8a5141`,
raw files in
[`2026-11-26-exp-08-lemmas-brittle-raw/verus/`](2026-11-26-exp-08-lemmas-brittle-raw/verus/)).
The figures were read from
[`functions.tsv`](2026-11-26-exp-08-lemmas-brittle-raw/verus/functions.tsv)
(columns: version, seed, label, module, function, mode, time_ms, rlimit,
success) with `awk` and `sort` on the workstation. Nothing was run on
the bench host.

## Corrections

### 1. Lemma F's largest share is 1.03%, not "at or under 1.0%"

Entry 8, "Margins" ("Lemma F's module stays at or under 1.0% in every
cell"), the notebook index row of entry 8 ("lemma F at most 1.0%"),
entry 9's verdict on lemma F ("no function of `fold_proof` above 1.0%")
and the draft comparison comment state a rounded value as a bound
(`shares.py` prints three decimals, so 0.0103 shows as `.010`). From
`functions.tsv`, the largest `fold_proof` counts are:

| Z3 | seed | function | rlimit count | share of 30,000,000 |
|---|---|---|---:|---:|
| 5.3.0 | 2 | `fold_proof::sharp_s_sym` | 309,793 | 1.03% |
| 4.15.3 | 3 | `fold_proof::sharp_s_sym` | 309,529 | 1.03% |

27 matrix cells have `sharp_s_sym` above 300,000 (1.0%). Read
"lemma F's functions stay at about 1% of the rlimit (largest 1.03%,
`sharp_s_sym`, Z3 5.3.0 seed 2)" wherever entries 8 and 9 say "at or
under 1.0%" or "above 1.0%". The conclusion stands: lemma F does not
discriminate. The notebook index row of entry 8 is corrected in place to
point here.

### 2. `sim_a` under Z3 5.3.0: eight other seeds, not seven

Entry 8, "The two failures": besides the two failing cells (default seed
and seed 10) and seed 7 (61.6%), the remaining seeds are 1-6, 8 and 9,
that is **eight** cells, at 10.1% (seed 2, 3,022,890) to 15.7% (seed 6,
4,697,887). The range was right. Read "at the other eight seeds".

### 3. Verus's 63.9% and F\*'s 74% are not in the same unit

Entry 9, verdict per tool for Verus, says "The margin is now comparable
to F\*'s 74% in experiment #9"; the draft comment says the same. The two
figures are measured differently (entry 9's own note on margins, and
experiment #9's comparison, which kept them apart):

- **Verus, 63.9%**: `term_core`'s total resource count over all its
  queries, against the per-function default limit of 30,000,000. It is an
  upper bound on what any one query used, and it holds at the default
  limit only.
- **F\*, 74%**: one query, against its own rlimit.

Read instead: "Its per-function margin (63.9%) is of the same order as
F\*'s per-query 74% in experiment #9, in units that are not comparable."
The verdict that Verus's default limit is no longer wide on lemma 2
stands on its own unit: the two 100% cells under Z3 5.3.0 and the 63.9%
under the supported Z3 4.16.0.

## Draft comment

The unposted draft of the comparison comment was edited for problems 1
and 3 (problem 2 is not in the draft). It is still posted only after the
maintainer's review.

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._
