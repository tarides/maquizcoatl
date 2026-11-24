# exp-05 runA-corrections: fixes after the review of run A

## What

Corrections to the [run A entry](2026-11-21-exp-05-runA.md) of
experiment #5, after the independent review of run A on issue #13
([comment](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7060988550)).
The run A entry is kept as it is; the passages named below are
superseded by this entry. Six decision-free problems are fixed: one
side effect on the shared cache is undone, two scripts are changed,
missing evidence is committed, and one explanation is completed. No
toolchain was installed and no prototype was re-run; the milestone 1-2
verdicts are not affected. Raw outputs are in
[`2026-11-21-exp-05-runA-corrections-raw/`](2026-11-21-exp-05-runA-corrections-raw/).

## Why

The review found that every conclusion of run A follows from the
committed raw data, but that the record left out a change to the shared
cache and some evidence the entry relied on. Runs B to D build on run
A's toolchains and scripts, so these gaps are closed first.

## Provenance

- Repository: `exp/05-unverified-calls`, the commit that adds this
  entry (on top of `734670a`). The script test below ran the changed
  `setup.sh` and `setup-pipeline.sh` of that commit, copied to the bench
  host before the commit; the provenance file was taken from the bench
  host's clone at `0439675` (`provenance.sh` is unchanged since).
- Bench host: AMD EPYC 7502P (64 CPUs online), Ubuntu 24.04.5 LTS,
  Linux 6.8.0-100, GCC 13.3.0, opam 2.6.1. Load average 0.02 at
  10:05 UTC, no other heavy process. Commands on CPUs 20-23,52-55,
  `nice -n 10`, 4 jobs. 31 GB free on the disk before and after.

## Fixes

1. **The shared opam root's default switch** (review problem 1).
   `opam switch create vst --empty` (the `vst` step of `setup.sh`, run
   A) rewrote `<shared-cache>/opam/config` at 09:32:36 UTC and made
   `vst` the root's default switch. This supersedes the run A entry's
   sentence "the switches `provers`, `compcert`, `ffi` and `ffi-flambda`
   are untouched": true of their contents, but the default changed.
   Experiment #5's scripts always pass `--switch`; any other script on
   that root without `--switch` got `vst` between 09:32 and 10:06 UTC.
   - Restored at 10:06 UTC with `opam switch set provers`
     (`opam-default.txt`: config `switch: "vst"` before,
     `switch: "provers"` after). The previous default is not recorded
     anywhere: `provers` (experiment #7, the root's first switch,
     created without `--no-switch`) is the most likely one; `compcert`
     (experiment #4, 11-19) was created by a command not kept, so it
     may have been the default instead. Experiment #12's `ffi` switches
     used `--no-switch`.
   - `setup.sh`'s `vst` step now creates the switch with `--no-switch`.
2. **VST versions missing from `provenance-runA-m2.txt`** (problem 2).
   That file was taken at 09:35, before the `vst` switch was complete
   (09:55), so its `coqc_vst` and `clightgen_vst` lines read "Command
   not found". This is a deviation the run A entry did not list; the
   versions were recorded only in `runA-m2/vst/build.log` (Rocq 9.2,
   CompCert 3.17 printed by `clightgen`, VST 2.17). Provenance re-taken
   at 10:06 UTC with the same toolchains (`provenance-runA-corr.txt`):
   `coqc_vst: The Rocq Prover, version 9.2`, `clightgen_vst: ... version
   3.17`, all other lines as in run A; `lean` fails as recorded.
3. **Evidence for the `base` status 1** (problem 3). The run A entry
   said one of the two parallel milestone 2 runs ended with `base`
   status 1; the failing run's `base.log` was overwritten and its
   console output was not committed. It was kept on the bench host and
   is now committed: `runA-console/setup-vst.txt` (`base: status=1`,
   `vst: status=0 time=1361s`, `failed components: base`, `SETUP-END m2
   status=1`) and `runA-console/setup-aeneas.txt` (all steps status 0,
   `SETUP-END m2 status=0`), with `m2-start.txt` (09:32:33 UTC, load
   0.34) and `cache-before.txt` (30 GB). So the VST run is the one that
   lost the `env.sh.new` race.
   - `setup-pipeline.sh` now holds an `flock` on `<cache>/.setup.lock`
     for a milestone run and refuses a second concurrent run on the same
     view, and it keeps `setup.sh`'s console output in
     `<exp>/out/setup-m<N>/console-<UTC time>.txt`.
4. **CPU sets and job counts of the installs** (problem 4). The run A
   entry's CPU sets for the installs (VST on 8-13,40-45 at 12 jobs,
   Aeneas on 14-19,46-51 at 4, milestone 1 setup on 8-19,40-51,
   Isabelle-LLVM setup on 20-27,52-55) are the operator's record only;
   no committed log shows them. `setup.sh` now starts each step log with
   `step`, `start_utc`, `cpu_set` (from `taskset`), `nice` and `VU_JOBS`
   with the job count the step uses.
5. **Verus `libvu.a` hash** (problem 5). The scratch run `runA-det` is
   now committed (`runA-det/verus/`): same harness sources as `runA-m1`
   (the sha256 list at the head of `build.log` is equal), proofs and
   output the same, `libvu.a` 24,479,232 bytes with sha256 `ab707ba1...`
   against `bd8b9c67...` for `runA-m1`. This supersedes the run A
   entry's "two of our own builds from the same commit also differ" as
   a proof of non-determinism: the two builds ran under different build
   paths (`<exp>/build/runA-det/verus` and `<exp>/build/runA-m1/verus`),
   so the difference may come from the path embedded in the archive and
   not from the build itself. All three recorded Verus builds
   (`prototypes-m1`, `review-fixes`, `runA-m1`) have the same size and
   different hashes, while Aeneas's rustc build is byte-identical. Run B
   will rebuild Verus with `--remap-path-prefix` (or two builds under
   the same path) to settle it. Nothing in the proofs or the outputs
   depends on it.
6. **Why the `fstar` and `verus` steps are not run** (problem 6). The
   run A entry and `setup-pipeline.sh`'s header gave one reason ("their
   `find` does not descend into a linked start directory"), which only
   explains why `fstar/<version>` cannot be a link to the shared copy.
   The other reason: `fstar/<version>` (and `verus/<version>`) does not
   exist in the view, so these steps would unpack a second copy of the
   release into the view and re-point `fstar/current` (`verus/current`)
   to it. The header now states both; this entry supersedes the run A
   entry's sentence.

## Test of the changed scripts

`setup-pipeline.sh 1 smoke-why3` with a separate experiment directory
(`<exp>/corr`), and a second identical run started one second later on
the same view (`setup-test/`):

- First run: `base` and `smoke-why3` status 0, `why3 smoke: ok`,
  `SETUP-END m1 status=0`, console output kept as
  `console-20261121T100717Z.txt`. Each step log starts with
  `cpu_set: 20-23,52-55`, `nice: 10`, `VU_JOBS: 4 (jobs for this step:
  4)`.
- Second run: refused, "another setup-pipeline.sh run holds the view:
  refused", exit status 1 (`concurrent-refused.txt`). It refreshes the
  view's links before taking the lock; that is idempotent.
- The shared opam root's default stayed `provers`.

`--no-switch` was not exercised (the `vst` switch exists); `opam
switch create --help` of opam 2.6.1 documents it ("Don't automatically
select newly installed switches"), and experiment #12 used it on the
same root.

## Open

- Disk floor for runs C and D (review follow-up): a decision for the
  maintainer, listed on issue #13; nothing done here.
