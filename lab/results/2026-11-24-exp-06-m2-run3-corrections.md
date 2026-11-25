# Experiment #6, milestone 2: corrections after the run 3 review

**What.** Decision-free fixes from the independent review of run 3
(https://github.com/tarides/maquizcoatl/issues/28#issuecomment-7141270511,
problems 1-3). The run 3 results entries are not edited (the notebook
is append only); this entry supersedes the figures and sentences
named below. No new run; no figure in the raw data, verdict or count
changes.

**Why.** The nested-interval rule was worded as a plain overflow test,
which is not the test that upstream and stack G compute; and two
sentences of the run 3 entries quote a run 1 figure or a rounded
difference.

## Provenance

Reading of run 2's and run 3's committed files at `f6f30b2` (branch
`exp/06-spec-speed-m2`) and of `upstream/src/regcomp.c:345-353` and
`upstream/src/regparse.c:4449-4455` at `f95747b` (read only). The
wording fixes in the plan and in `g/g2.ml` are in the commit that adds
this entry; issue #28's body (decision 12) was edited at the same time.

## Corrections

1. **Nested fixed intervals: the rule as computed.**
   `onig_positive_int_multiply(x, y)` accepts iff `x < INT_MAX / y`
   (integer division; `x` is the outer count, `y` the inner one), and
   `lab/06-spec-speed/g/g2.ml` applies the same test
   (`not (mn < 2147483647 / a)`). A fixed interval on a fixed interval
   is therefore rejected with -201 iff `outer >= (2^31-1) div inner`,
   equivalently `(outer+1) x inner > 2^31-1`, not "only when the
   product overflows a C `int`". Example: `x{100000}{21474}` has
   product 2,147,400,000 < 2^31-1 and is rejected (21474 is not
   below 2147483647 div 100000 = 21474). The issue body (decision 12),
   `plans/06-spec-speed-m2.md` and the comment in `g/g2.ml` now state
   the test as computed. The code is unchanged since run 2, and no S2
   case lies in the gap (test_utf8:1461 has 65,521 < 65,523;
   1770-1772 are far above), so no verdict changes.
2. **Run 3 throughput entry, slowdown band.** "within the band of the
   other extracted rows (3.1x-7.2x)" mixed run 1 figures. On run 2's
   search rates (those of the final table) the band of the other
   extracted rows is 3.0x (Why3, 456,509 / 150,744) to 6.4x (Lean,
   881,968 / 137,720), with F\* at 6.3x (1,567,045 / 249,474; the 7.2x
   was against run 1's 219,094) and Rocq at 5.5x. Verus's 6.5x
   (3,533,001 / 539,560) is just above that band, not within it;
   Isabelle extracted (9.4x) is further above it.
3. **Run 3 `T_spec` entry, two figures.**
   - `isabelle-check` peak RSS (max of three) is 2,572 MB
     (2,633,728 kB, rerun run 3 in `tspec-rerun/isabelle/times.tsv`),
     not 2,552 MB (that is run 1's 2,613,248 kB).
   - The 3a medians are within about 0.4 s of the rerun's: the
     difference is 0.41 s for `isabelle-export-code` (24.34 against
     23.93 s), 0.19 s for `isabelle-check` and 0.01 s for `-ocamlopt`.

No conclusion of run 3 changes: criteria 1-4 hold for Verus and
Isabelle/HOL, and the `T_spec` totals (3.12 s, 41.67 s) stand.
