# exp-05 runF-corrections: fixes after the review of run F

## What

Corrections to the [run F entry](2026-11-22-exp-05-runF.md) of
experiment #5, after the independent review of run F on issue #13
([comment](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7083875219)).
The run F entry and its index row are kept as they are; the passages
named below are superseded by this entry. The five decision-free
problems of the review are fixed. No verdict and no rank changes;
RefinedRust's trusted count goes from 156 to 152.

Raw data (redacted: `<exp>`, `<cache>`, `<home>`; checked for the host
name, user names, home paths and addresses before commit) in
[`2026-11-22-exp-05-runF-corrections-raw/`](2026-11-22-exp-05-runF-corrections-raw/).

## Why

The record counted RefinedRust's trusted lines under a rule the other
tools do not follow, read as if run F had reached its cap, called a
Creusot subcommand that no longer exists, overstated what an `Unknown`
prover answer shows, and had three wording slips.

## Provenance

- Repository: `exp/05-unverified-calls`, fixes on top of `184256b`.
- Bench host (AMD EPYC 7502P, Ubuntu 24.04.5 LTS, Linux
  6.8.0-100-generic), 2026-11-22 18:48-18:51 UTC, load 0.04-0.5, no
  heavy process of another account, 53 GB free: the two
  `prove-target.log` of the `runF-b` controls copied from
  `<exp>/build/runF-b/*/crate` (read only); one check of the fixed
  Creusot command (below) on a copy of the clamp control's crate in
  `<exp>/dev-runF-corr`, CPUs 14-15,46-47, `nice -n 10`, 53 s. No
  install, no recorded run.
- Tools as in run F: Creusot v0.14.0 (toolchain `nightly-2026-08-03`),
  why3find `0f054b93`; `count-trusted.sh` run in the local worktree
  after the `TRUSTED` edit (`trusted.tsv`).

## Corrections

1. **RefinedRust trusted lines: 152** (supersedes "156" and "the
   subject precondition of `get_subject_byte` 4" in the run F entry's
   summary, Trusted lines and Conclusion, and in its index row).
   `refinedrust/TRUSTED` counted `src/lib.rs:366-369`, the precondition
   of the verified accessor on the subject. CN's accessor precondition
   (`cn/vu.c:235-238`) is not counted, under CN's rule that the
   specifications of verified functions are not, and the C tools count
   the subject assertion only where a callout contract lends it. The
   range is now under "Not counted". RefinedRust: shims 37, C glue 99,
   client contracts 16; every other row of `trusted.tsv` is unchanged.
   Ranking: CN 22, RefinedC 25, Pulse 28, VST 54, Isabelle-LLVM 108,
   Verus 117, Aeneas 122, Creusot 123, hax F\* 134, Why3 140,
   RefinedRust 152 (RefinedRust still last, no rank changes). The
   C caller still meets the precondition; it stays in the callee
   assumptions column.
2. **Time left when Bedrock2 was dropped** (supersedes, in the run F
   entry, "Not started in this run: the RefinedRust prototype took the
   time" and the first sentence of "Why Bedrock2 is pending", and
   `table.md`'s "run F spent its time on RefinedRust"). The run did not
   reach its cap: the maintainer's decision was posted at 16:38 UTC,
   the recorded run ended at 18:34:13 and the results were posted at
   18:39, so run F used 2h01 of its 3 hours and left about 59 minutes
   unused. Bedrock2 was not started because a prototype with both
   negative controls (a trusted C shim with `ext_spec` contracts, the
   seven functions, `ToCString` output and an ABI wrapper) was judged
   not to fit in that hour after RefinedRust's 1h40; that is a
   judgement, not the cap.
3. **`cargo creusot prove` does not exist in Creusot 0.14.** The
   control check of `creusot/build.sh` ran `cargo creusot prove
   --no-cache ... TARGET`; both `runF-b` controls' `prove-target.log`
   start with "Warning: found 'prove' pattern; it is no longer a 'cargo
   creusot' command. Just run 'cargo creusot'"
   (`runF-b-prove-target/`), as do the probe's
   `prove-timeout-char_len.log` and `prove-timeout-get_subject_byte.log`:
   `prove` was taken as a target pattern
   matching nothing, and the check worked through `TARGET`. The word is
   dropped. Check: on a copy of the `runF-b` clamp control's crate,
   `cargo creusot --no-cache --why3find-arg=--log-prover-results ...
   char_len` prints no warning, fails `vc_char_len_F` (1/2) and gives
   `Timeout=12 Unknown=15 Valid=6`, the answers of the recorded control
   (`check-without-prove.log`). `build.sh` now also copies
   `prove-target.log` into `build.log` (the recorded `build.log` shows
   only the counted answers; the two logs are committed here instead).
4. **What makes a Creusot control's rejection genuine** (supersedes
   the run F entry's "counts a rejection only if a prover answered
   `Invalid` or `Unknown`" as a full account). `Unknown` is not a
   refutation: an SMT solver also answers it on a valid goal it cannot
   decide. The two rejections are genuine because the normal crate
   proves the same targets at the same limits in the same run
   (`normal_run=passed`, which `run.sh` requires before a control;
   probe `answers.txt` item 3: `Valid` only). `build.sh`'s comment and
   rejection message now say so.
5. **Wording.**
   - "All eleven RefinedRust proofs check (seven functions of
     `proto.h`, two helpers, ...)": twelve proof files, with three
     helpers (`action`, `can_record`, `record_at`), as the table and the
     index row say.
   - `refinedrust/src/lib.rs` line 17 said the structs are refined "by
     tuples of their fields (`#[rr::refined_by]`)", which run F
     dropped; it now says they are plain structs (comment only, same
     line count, so the `TRUSTED` ranges hold).
   - The read control leaves five open goals, not three
     (`refinedrust-dev/control-read-open-goals.log` of run F): the
     three of the entry (`i` in `isize`, `loc_a s + i ≤ loc_a s +
     length bs`, `i < length bs`) and two postcondition goals (the byte
     read is `bs !! i`, and its value).

## Open (for the maintainer, on issue #13)

- Bedrock2: one more short run for it alone, or close with it pending
  (installed, no prototype; about an hour of run F unused; it cannot
  remove stack A).
- Only if every tool's accessor precondition should be counted instead
  of dropping RefinedRust's: CN would become 26 (behind RefinedC's 25)
  and Isabelle-LLVM would gain its accessor's subject hypothesis.
- Still open: issue #29 (F\* eta-reduction report), issue #30
  (Isabelle-LLVM client model).
