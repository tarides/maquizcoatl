# exp-05 runG-corrections: fixes after the review of run G

## What

Corrections to the [run G entry](2026-11-24-exp-05-runG.md) of
experiment #5, after the independent review of run G on issue #13
([comment](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7127301939)).
The run G entry and its index row are kept as they are; the passage
named below is superseded by this entry. The two decision-free problems
of the review are fixed. No verdict, trusted count or rank changes.

No new raw data: the fixes are read from the run G raw data
([`2026-11-24-exp-05-runG-raw/`](2026-11-24-exp-05-runG-raw/)) and the
committed `bedrock2/VU.v`.

## Why

The run G entry gave the read control's failing line in the control's
own file but called it a line of `VU.v`, and `table.md` left Bedrock2
out of the tools whose callout postcondition names the callee's result.

## Provenance

- Repository: `exp/05-unverified-calls`, fixes on top of `b8e34ab`.
- Local worktree only, 2026-11-24 UTC: `sed` on
  `experiments/05-unverified-calls/bedrock2/VU.v` with the deletions
  that `bedrock2/build.sh` makes for each control (`build.sh:54-55`). No
  run on the bench host, no install, no recorded run.

## Corrections

1. **Read control: line 465 of `VU.v`** (supersedes "line 463 of
   `VU.v`" in the `runG/bedrock2-control-read` row of the run G entry's
   Results table). The read control's `build.log` reports line 459 of
   the file the control checks, which is `VU.v` without its two
   `READ-BEGIN`/`READ-END` blocks (`VU.v:80-82` and `VU.v:84-86`, six
   lines, all above). Line 459 of that file is line 465 of `VU.v`, the
   first line of the `all: first [...]` block at `VU.v:465-467` (the
   last step of `b2_vu_get_subject_byte_ok`), not line 463 (the end of
   the `all: try (...)` block that applies the read lemma). The clamp
   control's "line 371 of `VU.v`" is right: its log reports line 368
   of `VU.v` without the three `CLAMP` lines (`VU.v:13-15`), which is
   `VU.v:371` (`all: wsolve.`).
2. **Callout postcondition: Bedrock2 names the callee's result**
   (`table.md`, notes). `spec_of_callout_step` (`bedrock2/VU.v:471-483`)
   puts the event `((mG, "vu_call_callout", [f; a; ud]), (mR, [r]))` on
   the trace and states `signed res = callout_rule (signed dir)
   (signed r)` for that `r`. The note now lists Why3, Verus, Aeneas,
   Isabelle-LLVM and Bedrock2; Pulse and VST are still the two that do
   not name the value.
3. **Results comment on issue #13**
   ([comment](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7083775717)):
   the duplicated heading "**Run F.**" after "**Run F** (kept for the
   record)." is removed. Nothing else in the comment changes.

## Analysis

Both are wording fixes; no proof, build or count depends on them.
