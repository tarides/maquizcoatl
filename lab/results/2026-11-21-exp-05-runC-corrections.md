# exp-05 runC-corrections: fixes after the review of run C

## What

Corrections to the [run C entry](2026-11-21-exp-05-runC.md) of
experiment #5, after the independent review of run C on issue #13
([comment](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7062137886)).
The run C entry and its index row are kept as they are; the passages
named below are superseded by this entry. The six decision-free
problems of the review are fixed: a disk check placed after the 1.4 GB
it should guard, three installs described as refused when they are not
written, two upstream facts missing from the hax Rocq verdict, the hax
Lean backend not identified as the Charon + Aeneas pipeline, one claim
with no trace in the raw data, and a disk log that measured nothing.
One short check run (hax F\* backend, run id `runC-corr`) gives the
trace of fix 5; no toolchain was installed and no verdict changes. Raw
outputs are in
[`2026-11-21-exp-05-runC-corrections-raw/`](2026-11-21-exp-05-runC-corrections-raw/).

## Why

The review confirmed every number of run C, but found that the record
leaves out facts the maintainer's pending decisions depend on (what the
three refused installs really need, what a hax Lean verdict would
measure, why the Rocq verdict is final) and that the disk accounting
the floor relies on was wrong in two places.

## Provenance

- Repository: `exp/05-unverified-calls`; the code fixes are commit
  `74e92b0` (on top of `1e78df4`), the record is the commit that adds
  this entry.
- Check run: from the bench host's clone at `74e92b0`,
  `dev/final-c-corr.sh` (copied as `final-c-corr.sh`), 11:51:51 to
  11:52:03 UTC, CPUs 20-23,52-55, `nice -n 10`, 4 jobs. Load 0.08 at
  the start; other accounts had no heavy process running. F\* 2026.11.15 (`b92b0f87`), cargo-hax
  v0.5.0 (`a045d15a`), the toolchains of run C (`provenance.txt`).
- Bench host: AMD EPYC 7502P (64 CPUs online), Ubuntu 24.04.5 LTS,
  Linux 6.8.0-100. Disk: 18,964 MB free before the check run, 18,851 MB
  after (the build directory `<exp>/build/runC-corr`). Nothing deleted.
- Upstream facts of fixes 3 and 4: read with the GitHub API on
  2026-11-21 from `pereq-dev/hax` (tag `cargo-hax-v0.5.0`, `a045d15a`,
  and `main`).

## Fixes

1. **Disk check of the hax install** (review problem 1). In `step_hax`
   the check `need_disk hax 3` ran after `rustup toolchain install`
   (1.4 GB), and the Lean tools that `smoke-hax` downloads (604 MB) had
   no check. Measured footprint: switch `hax` 2.2 GB, binaries 83 MB,
   Rust nightly 1.4 GB, Lean tools 604 MB, about 4.3 GB against the
   3 GB estimate, which is why 24 GB free became 19. Now (`74e92b0`):
   `need_disk` runs before `rustup` whenever the nightly, the binaries
   or the switch is missing; `pins.json` has `disk_gb.hax` 4 (2.2 +
   0.08 + 1.4, the transient cargo build directory not counted) and a
   new `disk_gb["smoke-hax"]` 1, checked by `smoke_hax` when the Lean
   tools are not yet downloaded. The downloads are now recorded in
   `setup.sh` and in `pins.json` (`.hax.lean_tools`): Charon
   `nightly-2026.10.31` (43 MB) and the Aeneas build `build-2b9e3ea`
   (562 MB), in `<shared-cache>/xdg/hax/tools`. This supersedes, in the
   run C entry, "Charon `nightly-2026.10.31` into `XDG_CACHE_HOME`
   (`<cache>/xdg/hax/tools/charon`, 604 MB)" and "Charon download
   604 MB": the 604 MB are Charon (43 MB) and Aeneas (562 MB), and the
   directory is the shared cache's `xdg`, not the view's.
2. **Three installs are not written** (review problem 2).
   `step_hax_lean`, `step_creusot` and `step_refinedrust` are a disk
   check followed by `vu_die "... install not written"`; in run C none
   of them ran, because `setup-pipeline.sh` refused each one on its own
   check (floor 20 + `VU_NEED_GB`) before any step started
   (`install-refusals.txt`). `pins.json` still has an empty commit for
   RefinedRust. So writing the three installs, and pinning RefinedRust's
   commit, is work for the next run, before any disk is spent on them;
   the disk floor is not the only thing they wait for. This supersedes
   "Their installs (estimates 10, 7 and 6 GB) were refused by the disk
   floor" (What), the "refused" cells of the Installs table for
   hax-lean, creusot and refinedrust, and "hax Lean, Creusot,
   RefinedRust: pending (installs refused by the floor)" in the index
   row. `setup.sh`'s comment, `pins.json` (`refinedrust.commit_note`)
   and `table.md` now say so.
3. **Upstream facts behind the hax Rocq verdict** (review problem 3).
   (a) hax's README at the tag rates the Rocq/Coq backend
   "Experimental" (its backend table: Lean via Aeneas "Recommended",
   F\* "Stable", Rocq/Coq "Experimental"). None of the 29 CI workflows
   at the tag mentions Coq or Rocq (checked: no file under
   `.github/workflows` contains either word), and the Coq snapshots are
   compared as text, never compiled (review). (b) `main` is 2 commits
   past the tag (`99bb636e`, a Lean fix, and its merge `0d2f66ed`,
   2026-11-16); no commit since the tag touches `engine/backends/coq`
   or `hax-lib/proof-libs/coq`, whose last functional commits are
   `98c4c639` (2026-02-17, chars as strings) and `5a331fd2`
   (2025-07-21). So a re-check on `main` cannot change the verdict, and
   the backend actually used is one its maintainers call experimental,
   which matters to the plan's "maintained tools only" rule. Added to
   the hax Rocq row of `table.md`. The verdict stays "does not work (at
   v0.5.0)"; whether it is final is decision 3 on issue #13.
4. **The hax Lean backend is the Charon + Aeneas pipeline** (review
   problem 4). `smoke-hax.log` of run C shows `Running charon` and
   `Running aeneas on <exp>/build/smoke-hax/proofs/lean/llbc/smoke.llbc`,
   and the output has Aeneas's layout (`Funs.lean`, `Types.lean`,
   `FunsExternal_Template.lean`); the README at the tag says "Lean (via
   Aeneas) ... Uses Charon + Aeneas" (`cargo hax into lean`; the hax
   engine's own Lean output is `legacy-lean`). A hax Lean verdict would
   therefore be Aeneas's model with hax-lib's `requires`/`ensures` in
   front, not a third hax model. Stated in the hax Lean row of
   `table.md`, in `pins.json` (`hax.lean_note`) and in the plan's tools
   table and run C deviations. Whether it is worth its 10 GB is
   decision 4 on issue #13.
5. **Trace of the dropped `--cmi` flag** (review problem 5). The run C
   entry ("F\* 2026.11.15 also refuses hax's `--cmi` flag as
   unrecognised") and the plan relied on a fact `build.log` did not
   show: `hax/build.sh` dropped the flag silently when `--help` does
   not list it. Step 3 now prints `flag --cmi dropped: not listed by
   this F*'s --help` (or keeps the flag) and each F\* command line. The
   check run's `hax-fstar/build.log` shows both lines and the same
   failure as run C (error 134 at `Vu.fst(3,11-3,14)`, `FStar.Mul`);
   apart from the run id and the two new lines, step 3 is identical to
   run C's. The wording is corrected: this F\* does not list the flag
   (it was not run with it), so "refuses ... as unrecognised"
   (run C entry, Results and Analysis; plan, run C deviations) is
   superseded by "does not list `--cmi` in `--help`; the flag is
   dropped".
6. **`setup-m3/disk.txt` measured nothing** (review problem 6). The
   cache is a view of links, and `du -sh` on it gives 32K for every
   step. `step` now records `vu_du_links` (`du -sLh`) and the free space
   (`vu_free`) in the log and in `disk.txt`. Measured by the check run
   on the view: old measure 32K, new 47G, free 19G (`final.console`).
   The run C `disk.txt` is kept as it was; its cache column is void,
   and the per-step disk use of run C is the one in fix 1.

## Found on the way (not fixed)

- `hax/build.sh` names its F\* cache directory after the line
  `F* version: ...` of `fstar --version`, but F\* 2026.11.15 prints
  `F* 2026.11.15`, so the name is empty and the cache is
  `<exp>/build/hax-fstar-cache/` for every F\* (the new command line
  shows it). Harmless with one F\*; it must be fixed before F\*
  v2025.10.06 is run beside it, or the two would share checked files.
  Listed as a follow-up on issue #13.

## Results

| Check | Run C | After the fixes |
|---|---|---|
| hax disk estimate | 3 GB, after the Rust install | 4 GB (hax) + 1 GB (smoke-hax), checked before anything is written |
| `--cmi` in `build.log` | absent | `flag --cmi dropped: not listed by this F*'s --help` and the command line |
| `disk.txt` cache column | 32K for every step | 47G (through the links), plus free space |
| hax F\* backend (check run) | error 134, `FStar.Mul` | same |

## Analysis

No verdict changes: hax F\* pending, hax Rocq "does not work (at
v0.5.0)", hax Lean, Creusot and RefinedRust pending. What changes is
what "pending" means for the last three: hax Lean needs disk and a
decision on whether it is worth it (fix 4); Creusot and RefinedRust
need their installs written, then disk. The decisions listed in the
review are left to the maintainer; this entry acts on none of them.
