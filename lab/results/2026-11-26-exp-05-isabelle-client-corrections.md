# exp-05 isabelle-client-corrections: fixes after the review of run i30-run1

## What

Corrections to the [isabelle-client entry](2026-11-26-exp-05-isabelle-client.md)
of experiment #5 (follow-up of issue #30, run `i30-run1`), after the
independent review of that run on issue #30
([comment](https://github.com/tarides/maquizcoatl/issues/30#issuecomment-7194226758)).
The isabelle-client entry and its index row are kept as they are; the
passages named below are superseded by this entry. The three
decision-free problems of the review are fixed. No verdict, trusted
count or table row changes.

No new raw data: the fixes are read from the run's raw data
([`2026-11-26-exp-05-isabelle-client-raw/`](2026-11-26-exp-05-isabelle-client-raw/))
and the committed `isabelle-llvm/VU.thy`.

## Why

The entry's run table wrote the peak RSS in a unit that matches neither
GB nor GiB, gave the clamp control's failing line only in the control's
own copy of `VU.thy`, and the Goal section of issue #30's body still gave
the counts from before decision 4.

## Provenance

- Repository: branch `exp/05-isabelle-llvm-client`, fixes on top of
  `b02d4f7`.
- Local worktree only, 2026-11-26 UTC: arithmetic on the `build.time`
  files and a reading of `VU.thy`. No run on the bench host, no install,
  no recorded run.

## Corrections

1. **Peak RSS in GiB** (supersedes the "max RSS" column of the run
   `i30-run1` table). `build.time` (GNU `time -v`) gives "Maximum
   resident set size (kbytes)", in units of 1024 bytes:

   | Build | `build.time` (kbytes) | GiB | GB (10^9 bytes) |
   |---|---|---|---|
   | normal | 3775236 | 3.60 | 3.87 |
   | `-n` (clamp removed) | 4029856 | 3.84 | 4.13 |
   | `-r` (read bound removed) | 4046276 | 3.86 | 4.14 |

   The entry's 3.78, 4.03 and 4.05 "GB" were kbytes / 10^6. The unit of
   record is GiB: 3.60, 3.84 and 3.86 GiB.
2. **Clamp control: `VU.thy:135` of the committed file** (supersedes
   "`VU.thy:127`" in the `-n` row of the same table and in the index
   row). The log's line 127 is in the control's copy of `VU.thy`, where
   the CLAMP block (`VU.thy:105-114`, 10 lines, all above) becomes 2
   lines. Line 127 of the copy is `VU.thy:135` of the committed file, the
   `by vcg'` of `vu_char_len_correct`, as in run B.
3. **Issue #30 body, section Goal**: "the count is 100 if it is removed
   and 108 if it is kept" now says that, with decisions 2 (keep and
   reword) and 4 (count the one-line definition), the count is 109, as
   the Decisions section and the isabelle-client entry say.

## Analysis

All three are wording fixes; no proof, build, count or table row depends
on them.
