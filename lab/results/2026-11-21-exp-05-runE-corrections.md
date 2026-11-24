# exp-05 runE-corrections: fixes after the review of run E

## What

Corrections to the [run E entry](2026-11-21-exp-05-runE.md) of
experiment #5, after the independent review of run E on issue #13
([comment](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7077543004)).
The run E entry and its index row are kept as they are; the passages
named below are superseded by this entry. The six decision-free
problems of the review are fixed. Nothing was installed, built or run
on the bench host: two logs it held were copied back, and three
directory sizes were measured again (`du -sL`, read only). No verdict,
done-criterion or proved trusted-line count changes; the hax Rocq
row's count goes from 126 to 134.

Raw data (redacted: `<shared-cache>`, `<cache>`, `<exp>`, `<harness>`;
checked for the host name, user names, home paths and addresses before
commit) in
[`2026-11-21-exp-05-runE-corrections-raw/`](2026-11-21-exp-05-runE-corrections-raw/).

## Why

The record gave the wrong reason for the two pending rows, left out two
logs that claims rest on, printed sizes that the raw data did not
support, and counted the shared hax prototype two ways.

## Provenance

- Repository: `exp/05-unverified-calls`, fixes on top of `8fbdb6d`.
- Bench host (read only, 2026-11-22 10:04 UTC, load 0.05, no heavy
  process of another account): files copied from `<exp>/out`, sizes by
  `du -sLm` through the cache view. No CPU set, no job, no disk used.
- `count-trusted.sh` run in the local worktree after the `TRUSTED`
  edits (`trusted.tsv`).

## Corrections

1. **Why RefinedRust and Bedrock2 are pending** (supersedes, in the run
   E entry, "draft prototype not checked within the 3-hour cap",
   "prototype not written within the cap", "still building the stdlib
   at the end of the run" in Commands, "RefinedRust 3.3 GB at the end of
   the recorded runs, still building", and the index row's "not checked
   within the 3-hour cap"). The run did not reach its cap: the
   maintainer's decision was posted at 17:01 UTC, installs started at
   17:06, the last recorded batch ended at 18:08 and the results were
   posted at 18:09, so the run stopped after 1h08 of its 3 hours.
   RefinedRust's install (switch `refinedrust` with
   `refinedrust-stdlib`) then finished with status 0 after 3869 s, at
   18:11:40 UTC (`setup-m3/disk.txt`), about two minutes after the
   record. What is left for RefinedRust is the draft's two fixes (the
   `&mut` struct specifications, a raw-pointer read for the accessor),
   not the install; Bedrock2's prototype was not started. Updated:
   `table.md` (last-update paragraph, RefinedRust and Bedrock2 rows),
   the plan's Bedrock2 bullet, the header comment of
   `refinedrust/src/lib.rs`, the issue table (new comment), PR #21's
   body and the dashboard note.
2. **Logs only on the bench host, now committed.** The full RefinedRust
   install console (`setup-m3/console-refinedrust-20261121T170703Z.txt`:
   `refinedrust: status=0 time=3869s cache=60G free=54G`; the run E
   copy stopped at `== refinedrust`), its step log
   (`setup-m3/refinedrust.log`, ending `refinedrust: switch 3.3G src 31M
   rust: 1.4G`) and `setup-m3/disk.txt` with its 18:11:40 line. The
   first hax F\* try, on which the `f_enc_len_pre` explanation rests:
   `dev-runE-1/hax-fstar/build.log` (F\* error 19 "Assertion failed" at
   `Vu.fst(89,61-93,64)`, related location `Vu.fst(63,22-63,43)`,
   `build_status=3`, 104 s, CPUs 26-27,58-59).
3. **Three sizes and `vu_du`** (supersedes the run E entry's sizes as
   untraced). `vu_du` used `du -sh`, which on the cache view (a
   directory of links) measures the link: `creusot.log` ends `creusot: 0`,
   `bedrock2.log.tail` `bedrock2: 0`, and each console prints
   `disk use: cache=32K`. The entry's numbers are right; where they come
   from:
   - `<cache>/creusot` 956 MB and Bedrock2 63 MB: `du -sLm` through the
     view on 2026-11-22 (`du-sizes.txt`, with the 0 that `du -s`
     gives); neither tree changed since run E.
   - RefinedRust switch 3.3 GB: the last line of `refinedrust.log`
     (that switch is a real directory of the opam root, not a link),
     written at 18:11 when the install had finished, and 3325 MB by
     `du -sLm` on 2026-11-22. So it is the finished switch, not a size
     "still building".

   `vu_du` in `lib.sh` now uses `du -sLh`, as `vu_du_links` and
   `disk.txt` already did.
4. **hax trusted lines** (supersedes the hax Rocq row's "126 (same
   glue)" in `table.md`). `hax-rocq/TRUSTED` now lists the two
   `requires(true)` client contracts of the shared `hax/src/lib.rs`
   (lines 85-89, 93-97): the Rocq classes drop the trait contracts, but
   the Rust source that both backends start from carries them, and they
   are assumed of the C client either way. hax Rocq: **134** (shims 30,
   C glue 91, client contracts 13), equal to hax F\*. The header of
   `hax-fstar/TRUSTED` no longer says the trait declarations "carry no
   assumption, except the contract of ApplyAll": it names the three
   contracts. Ranking unchanged (hax Rocq has no proof and is not in it).
5. **Provenance details** (supersedes the run E entry's "installs on
   disjoint sets"). `rr-frontend-early.sh` ran on 24-27,56-59, the
   Bedrock2 (24-25,56-57) and hax F\* (26-27,58-59) sets, so the sets
   were not disjoint; no step used a reserved CPU (4-7, 36-39, 28-31,
   60-63). The recorded batches ran while the RefinedRust install was
   still building; load averages from each `provenance.txt` (start, end):
   `runE` 5.5 / 8.3, `runE-b` 13.2 / 15.6, `runE-c` 12.3 / 8.1. The
   timings of the entry (hax F\* 99 s, Creusot 46 s, CN 1 s, RefinedC
   78 s) are under that load; no verdict depends on them. In
   `creusot.log`, `cargo-creusot --version` failed ("could not find
   `Cargo.toml`"), hidden by `|| true`: `setup.sh` now runs `cargo
   creusot version` from the Creusot source directory, without `|| true`.
6. **Creusot's rejection pattern.** `creusot/build.sh` counted a proof
   as rejected when `prove.log` matched `fail|unproved|not proved|timeout`,
   so a prover timeout would have passed as a rejection. The pattern is
   now `proof failed|unproved`. The recorded controls fail outright
   ("proof failed", `vc_char_len` 1/2 and `vc_get_subject_byte` 3/4), so
   no verdict changes. Not checked here: whether why3find's summary line
   "N unproved file" is also printed when a goal only times out.

## Open (for the maintainer, on issue #13)

- RefinedRust and Bedrock2: one more run limited to those two rows, or
  close with them pending (neither can remove a stack).
- Where hax F\* sits in the stack list: under stack C as now, in a
  note, or as a route of its own (it is Rust to F\* with a Rust
  `cdylib`, while the report puts hax under stack A and stack C is "C
  generated by KaRaMeL"); "no stack eliminated" does not depend on it.
- Still open: the F\* eta-reduction report (issue #29) and the
  Isabelle-LLVM model client.
