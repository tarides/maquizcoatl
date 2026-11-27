# Experiment #8 follow-up (issue #34), entry 7: corrections after the run-3 review

**What.** Corrections to entry 6
([2026-11-26-exp-08-lemmas-verus.md](2026-11-26-exp-08-lemmas-verus.md))
required by the independent review of run 3 on issue #34
([comment](https://github.com/tarides/maquizcoatl/issues/34#issuecomment-7197349158)),
problems 1 and 2. No new run: the lemma figures are recomputed by hand
from the sources at `2242606`, and the no-cases timing record is
recovered from the run-3 work directory on the bench host. Entry 6 is
left as recorded. This entry supersedes the passages it names.

**Why.** The review confirmed run 3 (both lemmas and the stretch closed,
`179 verified, 0 errors` with and without `--no-cheating`, scan clean,
figures recomputed from the raw files). It found two defects. First,
`lemmas.py` misreads the body of seven Verus lemmas, so the automatic
count and six line counts are wrong. Second, the supplementary no-cases
timing that run 4 will quote has a thinner record than a `timed.sh`
series.

## Provenance

Branch commit `2242606` (Verus sources unchanged since; `sha256.txt` of
entry 6 holds). The hand check is
[`realbody.py`](2026-11-26-exp-08-lemmas-verus-review-fixes-raw/realbody.py),
run locally:

    cd lab && python3 -I <raw>/realbody.py 08-discriminating-lemmas \
        08-discriminating-lemmas/verus/{fold_proof,absent_mono,absent_proof}.rs

Output: [`realbody.txt`](2026-11-26-exp-08-lemmas-verus-review-fixes-raw/realbody.txt).
The no-cases record is in
[`nocases-provenance.txt`](2026-11-26-exp-08-lemmas-verus-review-fixes-raw/nocases-provenance.txt),
read from the file times and files of `<bench-workdir>/exp/08-discriminating-lemmas`
(`build/verus/r3-nocases-t{1,2,3}`, `out/r3/verus-nocases`). Nothing was
timed or verified for this entry.

## Corrections

### 1. Automatic share 4 of 99 (4.0%), and six line counts (entry 6, "Size and lemmas")

`lemmas.py` takes the first brace block at bracket depth 0 after a
`proof fn` name as its body. Its docstring assumes that the
specification clauses have no brace block at depth 0. Seven lemmas of
`absent_proof.rs` have one:
- `core_k` and `step_eq`: `if ... { ... } else { ... }` in `ensures`;
- `simple_unfold`: `match ... { ... }`;
- `scan_a`, `scan_b`, `simple_finish`, `simple_ends_b`:
  `forall ... ==> { &&& ... }`.

`realbody.py` uses the same comment stripping and the same line count
as `lemmas.py`, but skips a brace block that is followed by `,`, `else`,
a clause keyword or another block. It agrees with the review on every
figure:

| Lemma | `lemmas.py` (entry 6) | real body |
|-------|----------------------:|----------:|
| `core_k` | 5 | 57 |
| `step_eq` | 4, manual | 5, **automatic** (body `{ }`, `absent_proof.rs:416-420`) |
| `scan_a` | 11 | 54 |
| `scan_b` | 16 | 74 |
| `simple_unfold` | 7 | 19 |
| `simple_finish` | 12 | 38 |
| `simple_ends_b` | 7 | 37 |

The plan defines an automatic lemma as a `proof fn` with an empty body.
Under that definition, the automatic lemmas are `rsz_pos`, `at_lt`,
`step_eq` and `downs_hd`: **4 of 99 (4.0%)**, not 3 (3.0%). The other
figures are unaffected:
- the lemma total (99: 12 + 8 + 79);
- the admitted count (0);
- the witness count (24);
- the `loc.py` figures (2142 proof lines).

The largest bodies are `sim_a` 101, `sim_b` 80, `scan_b` 74,
`term_core` 74, `sharp_s_sym` 65, `core_k` 57 and `sim_b_xs` 56.
`term_core` (74 lines, counted correctly by the script) was missing
from entry 6's list and from the review's.

Experiment #9's Verus figures stand. `realbody.py` on its four proof files
(`proof_a.rs`, `proof_sem.rs`, `proof_sim.rs`, `proof.rs`) differs from
`lemmas.py` on no lemma: 62 lemmas, 3 automatic (4.8%).

`lemmas.py` is unchanged, since the plan reuses it unchanged. Run 4's
comparison table uses **4 (4.0%)** for Verus. It states that the
script's body rule was corrected by hand for this crate (this entry).
The index row of entry 6 and the dashboard note said 3; read 4.

### 2. Supplementary no-cases timing: full record (entry 6, "Check time")

From the bench host's run-3 files
([`nocases-provenance.txt`](2026-11-26-exp-08-lemmas-verus-review-fixes-raw/nocases-provenance.txt)):

- **Command**, in each fresh build copy, under `flock <exp>/timed.lock`,
  `/usr/bin/time -v` and timed.sh's 16 GB cgroup (from `time.log`):
  `taskset -c 24-27,56-59 verus --crate-type=lib --num-threads 7 lib.rs`.
- **Edit**: `pub mod cases;` removed from `lib.rs` (line 12), and
  `cases.rs` not copied. The other six sources are identical to entry 6's
  `sha256.txt`. `lib.rs` changed from `c2ed696c9ef62512f734d714796cb70c8826d91349249a5d2b112350fce35e0f` (at `2242606`) to
  `ecf6017dd14fda1f195a0a1dc6755559fc7ca58042e1ec55178e4dd1e353a653`,
  identical in the three build copies.
- **Time window**: 2026-11-26T16:01:25Z to 16:02:06Z (41 s). The
  main `timed.sh` series ran from 15:59:32Z (precheck) to 16:01:15Z, so
  this series started 10 s after it ended.
- **Toolchain**: the Verus binary and its Z3 in the shared cache are dated
  2026-11-02T04:35:38Z and have not changed since. The main series'
  `version.txt` (Verus 0.2026.11.02.8bf68ee, Z3 4.16.0) applies.
- **Precheck**: only the busy-thread count (0) was written. The thread
  listing that a `timed.sh` series writes to `precheck.txt` was not
  written and cannot be recovered. The load averages are in `time.load`
  (1.15-1.20 at 1 minute).
- **Figures**: 13.72 / 13.74 / 13.65 s, median **13.72 s** (unchanged).
  Median peak RSS is **519,376 KB**, not 519,380 KB (that was run 1's
  value). Median user time is 14.25 s and median system time 0.83 s.
  Each run reports `147 verified`.

The time window was recovered, so the review's fallback (rerunning the
three no-cases checks in run 4) is not required. As the review's
follow-up notes, 13.72 s is the like-for-like figure beside Rocq's
11.19 s and experiment #9's 5.27 s. Those two were also measured
without a cases file.

_Drafted by Claude Code (Opus 5.5) as part of the experiment pipeline._
