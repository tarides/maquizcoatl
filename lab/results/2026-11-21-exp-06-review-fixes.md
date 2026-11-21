# Experiment #6: corrections after the results review

**What.** Corrections to entries 1 (provenance), 4 (throughput) and 5
(`T_spec`) of milestone 1 and to experiment #7's settling entry, required by the automated results
review on issue #1
([comment](https://github.com/tarides/maquizcoatl/issues/1#issuecomment-7043875712),
problems 3-5). No new run: every fact below is already in the raw data
([2026-11-20-exp-06-raw/](2026-11-20-exp-06-raw/)) or in the branch's
history. Those entries are left as recorded; the passages named
below are superseded by this entry.

**Why.** The review confirmed every figure and done-criteria 1-5, but
found that a script change made during the first timed series is not
recorded, that three departures from the plan are not stated, and that
the size of the milestone 1 fragment is given three different ways.
Its problems 1 and 2 (the notebook conflict with `main`, and a
`summarise.py` that could not be rerun from the committed data) are
code and merge fixes, listed under "Not changed" for completeness.

## Provenance

Text corrections only, on the data of entries 1-5 and the settling entry (results commit
`3cee43b`, harness commit `57bd9bc`). The script-state facts below come
from `git diff 57bd9bc 3cee43b -- lab/06-spec-speed/`, from the commit
date of `57bd9bc`, and from `series.log` and `fstar/times.tsv` in the
raw directory.

## Corrections

### Throughput entry: F\*'s normaliser fix landed during the first series

The throughput entry says that F\*'s first normaliser series (labels
`fstar-Q0`, `fstar-QN`) measured nothing, and that "the figures above
are from the rerun". That is right, but incomplete. The change to
`fstar/fstar.sh` that removes the checked files and adds the `c`
suffix to the labels was made while `series.sh` was running, between
its second `inp` run (15:05:43 UTC in `series.log`) and its third
(15:06:57 UTC). As a result:

- `fstar/times.tsv` has `fstar-Q0` and `fstar-QN` for runs 1 and 2
  only (both about 0.1 s, nothing measured), then a `fstar-Q0c` /
  `fstar-QNc` pair labelled run 3, taken by `series.sh`'s third `inp`
  run (QNc 11.91 s), then `series3.sh`'s own runs 1-3 (QNc 11.87,
  11.87, 11.97 s).
- `summarise.py` keys each label by run number, so `series3.sh`'s run 3
  replaces the stray run 3 in the published table, which uses
  `series3.sh`'s three runs only.

The stray row is harmless: all four `QNc` runs lie in 11.87-11.97 s,
so taking it instead of `series3.sh`'s run 3 would not move the median
(11.87 s) nor the median of the per-run QNc - Q0c differences
(11.76 s) from which the cases/s figure is computed. It stays in `times.tsv` as
recorded.

### Provenance entry: departures from the plan, now stated

1. **No `pins.json` at run time.** The plan
   (`plans/06-spec-speed.md`, "Where things live" and "Tools and
   versions") asks for `pins.json`, with Verus and Isabelle/HOL pinned
   there if they stand. The run used no such file: the versions were
   recorded only in the provenance entry's prose and in
   `provenance.txt` / `<tool>/version.txt`. A
   `lab/06-spec-speed/pins.json` has been added after the run as a
   pure transcription of those recorded versions (no version was
   looked up anew); no script reads it.
2. **`.gitignore` not extended.** The plan says build output is
   gitignored (`_build`, `.lake`, `target`, caches). The repository's
   `.gitignore` was not extended. No build output reached the tree,
   since every build lives under `<exp>/build/` on the bench host,
   outside the repository; the file is left as it is.
3. **Exact script state at run time.** `provenance.txt` records
   "48d5254 + uncommitted milestone-1 scripts", and the provenance entry
   says the harness is `57bd9bc`. `57bd9bc` was committed at 14:49:46
   UTC, about a minute after `series.sh` started (14:48:31 UTC), so the
   run's working tree is not separately verifiable against it. What
   the history does show is that, between `57bd9bc` and `3cee43b`,
   `series.sh`, `common.sh`, `tm.sh`, `provenance.sh`,
   `cases/extract.py`, `g/`, `oracle/`, `rocq/`, `lean/` and `why3/`
   are unchanged; `fstar/fstar.sh` differs only by the cache-clearing
   change above (its `inp` mode; `thr` and `tspec` unchanged);
   `cases/gen.py` and `reps.env` differ only by additions for the
   Verus and Isabelle/HOL rows; and the remaining changes are new
   files (`series2-4.sh`, `verus/`, `isabelle/`) and `summarise.py`.
   So the four planned tool scripts and `series.sh` that the committed
   `57bd9bc` holds are the ones in `3cee43b`, except for the one F\*
   change recorded above.

### `T_spec` and settling entries: size of the fragment

The `T_spec` entry calls milestone 1 "a 120-300 line fragment" and the
settling entry (`2026-11-20-exp-07-verdicts-settled.md`) "a 120-220
line fragment". Both are superseded by the measured figure of the
agreement entry's line-count table: **117-306 code lines (156-356
physical lines) per prover semantics**, from Isabelle/HOL's
`isabelle/Spec.thy` (156 physical, 117 code) to Verus's
`verus/spec.rs` (356 physical, 306 code). Stack G's `g/g.ml` is 494
physical lines, of which about 125 are the semantics. Neither
conclusion changes: `T_spec` of milestone 1 is still a lower bound on
the full spec's, not an estimate of it.

### Cosmetic: stray prefix in `g/throughput-lines.txt`

The C oracle's three lines in `g/throughput-lines.txt` begin with
`test_utf8:1791` before `cases=152` (stdout and stderr interleaved in
the run log). The figures on those lines are unaffected, and
`summarise.py` ignores the prefix (it reads only the `*_cps` and
`reps` fields). The file is left as recorded.

## Not changed

- Every figure of entries 1-5, of the settling entry and of the summary comment on issue #1.
- The raw data in `2026-11-20-exp-06-raw/`, including the stray
  `fstar-Q0c` / `fstar-QNc` run 3 row and the `test_utf8:1791` prefix.
- The text of entries 1-5 and of the settling entry; the passages named above are superseded
  here, not rewritten.
- Review problem 1: `main` was merged into the branch (not rebased,
  since entries cite the branch's commits), keeping both sides'
  notebook sections.
- Review problem 2: `summarise.py` now reads the committed
  `<tool>/throughput-lines.txt` instead of the per-run logs (not
  committed), and its docstring says to regenerate `all.tsv` first
  with `cases/extract.py`. Rerun from the committed raw directory with
  a regenerated `all.tsv` (sha256 `d0386ccf…ecc88f`, 4,565 cases), its
  output is byte-identical to the committed `summary.md`, so every
  published table reproduces.
