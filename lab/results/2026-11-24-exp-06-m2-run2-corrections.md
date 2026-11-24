# Experiment #6, milestone 2: corrections after the run 2 review

**What.** Decision-free fixes from the independent review of run 2
(https://github.com/tarides/maquizcoatl/issues/28#issuecomment-7138484053,
problems 2 and 3 and the `reps-m2.env` follow-up). The results entries
themselves are not edited (the notebook is append only). No new run; no
figure, verdict or count changes.

**Why.** Each point makes a reader cross-reference the wrong decision,
miss an opcode or land on the wrong line. One point (the nested fixed
interval rule, problem 1 of the review) needs the maintainer and is
not applied here.

## Provenance

Reading of run 2's committed files at `7ed388c` (branch
`exp/06-spec-speed-m2`) and of `upstream/src/regexec.c` at `f95747b`
(read only). The fixes are in the commit that adds this entry.

## Corrections

1. **Decision numbering.** The five decisions after run 1 are numbered
   7-11 in issue #28's body, 1-5 in the decisions comment
   (https://github.com/tarides/maquizcoatl/issues/28#issuecomment-7136902494)
   and were 3-7 in `plans/06-spec-speed-m2.md` ("Maintainer decisions
   after run 1", `cbf298c`). The plan section is renumbered 7-11 and
   says so. In the [run 2 throughput
   entry](2026-11-24-exp-06-m2-run2-throughput.md), "decision 3 after
   run 1" (the plan's old number for the code point lists) reads as
   decision 9.
2. **DEV-008's Origin** (`spec/deviations.md`) now says "decisions 7
   and 8 of the issue body (1 and 2 of the comment)".
3. **DEV-008's upstream paragraph.** "`OP_REPEAT_INC`, the only place
   where the count is compared with `lower` and `upper`" overlooked
   `OP_REPEAT_INC_NG` (`upstream/src/regexec.c:4405-4421`), which does
   the same for non-greedy bounded loops, such as test_utf8:797's inner
   `{0,7}?`. It now reads "`OP_REPEAT_INC` / `OP_REPEAT_INC_NG`
   (greedy / non-greedy), the only places ..." with both line ranges.
   The rule and its verdicts are unchanged.
4. **DEV-008's example lines.** `why3/spec2.mlw:325` and
   `fstar/Spec2.fst:253` point at the comment above the empty check;
   the test is at `why3/spec2.mlw:326` and `fstar/Spec2.fst:254`. Fixed
   in the entry.
5. **`lab/06-spec-speed/reps-m2.env`.** Its header said run 1's passes
   were calibrated on CPUs 0-3, while the run 1 throughput entry and
   the run 1 provenance entry say untimed milestone 2 work, calibration
   included, ran on CPUs 0-15. The header now says 0-15, as the
   entries do. The pass counts are unchanged.

## Not applied (maintainer decision needed)

Nested fixed intervals: (a) keep upstream's C `int`-overflow rejection
(what run 2 does); (b) bound the reduced count by
`ONIG_MAX_REPEAT_NUM` (100,000), making test_utf8:1461 a logged
deviation; or (c) no limit on the product, making test_utf8:1770-1772
logged deviations. Options (b) and (c) need a DEV-009 entry, and the
plan's and issue body's "removed" sentence must state the rule that
stands. It does not block run 3.

The dashboard row's `stage` field ("done" while milestone 2 runs) is
left for run 3's update of the row, as the review suggests.
