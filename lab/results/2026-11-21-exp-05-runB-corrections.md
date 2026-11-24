# exp-05 runB-corrections: fixes after the review of run B

## What

Corrections to the [run B entry](2026-11-21-exp-05-runB.md) of
experiment #5, after the independent review of run B on issue #13
([comment](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7061615007)).
The run B entry and its index row are kept as they are; the passages
named below are superseded by this entry. Seven decision-free problems
are fixed: two wrong trusted-line counts, three pieces of missing
evidence (one of them from a new probe run, the only run of this
entry), a missing plan section, two missing callee assumptions, two
undescribed control failures and one citation. No prototype was re-run
and no toolchain was installed; the verdicts do not change. Raw outputs
are in
[`2026-11-21-exp-05-runB-corrections-raw/`](2026-11-21-exp-05-runB-corrections-raw/).

## Why

The review found that every conclusion of run B follows from the
committed raw data except the Verus and Aeneas trusted counts in the
prose, and that two conclusions (Verus `libvu.a` reproducibility, the
Aeneas false positive) and the Miri finding rested on files that were
only on the bench host. Run C builds on run B's prototypes and table,
so these are closed first.

## Provenance

- Repository: `exp/05-unverified-calls`; the probe of fix 3 ran from
  the bench host's clone at `a8a85fc` (which adds `aeneas/probes/`, on
  top of `bf07ea3`); the other fixes are in the commit that adds this
  entry.
- Bench host: AMD EPYC 7502P (64 CPUs online), Ubuntu 24.04.5 LTS,
  Linux 6.8.0-100. Load average 0.24 at 11:01 UTC, no other heavy
  process; 26 GB free on the disk, unchanged.
- Probe run: `aeneas/probes/warn.sh <exp>/out/runB-corr/warn-work` on
  CPUs 20-23,52-55, `nice -n 10`, at 11:03:36 UTC, under the run B
  toolchains (Charon 0.1.321 `61c67516`, Aeneas
  `nightly-2026.11.19-8f4466d`, Rust `nightly-2026-09-17`), exit 0,
  under 3 s.
- Files copied from run B's development output directory on the bench
  host (run ids `v2`, `v3`, `v1`, `a1`), unchanged apart from the
  redaction `lib.sh` had already applied.

## Fixes

1. **Trusted counts for Verus and Aeneas** (review problem 1). The
   committed `trusted.tsv` of run B, which hashes the same `ffi.rs` as
   the recorded `build.log` and `miri.log`, gives:

   | Tool | Run B prose | `trusted.tsv` | Breakdown | Change from run A |
   |---|---|---|---|---|
   | Verus | 118 | **117** | `shim.rs` 25, `ffi.rs` 92 | +15 (not +16) |
   | Charon + Aeneas | 125 | **122** | `ffi.rs` 30 (shims) + 31 + 57 (C glue 88), `Proofs.lean` 4 | +13 (not +16) |

   The prose numbers were taken before the Miri fix of the glue (fix
   4). This supersedes, in the run B entry, the "Trusted lines" column
   of the results table, "Verus (+16) and Charon + Aeneas (+16)" and
   "Verus 118, Aeneas 125" in the verdict; and in the index row of
   `runB`, "Trusted lines 140, 28, 118, 125, 54, 108", which should read
   140, 28, 117, 122, 54, 108. `table.md` is corrected. Verdicts
   unchanged.
2. **Verus `libvu.a` with `--remap-path-prefix`** (problem 2a).
   `verus-remap/v2-build.log` and `v3-build.log` are the two
   development builds the run B entry cites. Their harness hashes equal
   the recorded `runB` build's (`ffi.rs` `cc59cd40...`, `lib.rs`
   `adfa0881...`, `build.sh` `8a128b85...`), they ran under build
   directories `<exp>/build/v2` and `<exp>/build/v3`, and both end with
   `libvu.a: 24484576 bytes, sha256 c33e4afe...`, the recorded build's
   hash. Three builds under three paths, one hash.
3. **Aeneas false positive** (problem 2b). The probe crates were only on
   the bench host and the warning only on the console. They are now
   `experiments/05-unverified-calls/aeneas/probes/` (`imax/`: `pub fn
   f(x: i32) -> bool { x < i32::MAX }`; `plain/`: `pub fn f(x: i32) ->
   i32 { x }`; `warn.sh`), run once for this entry
   (`aeneas-warn/warn.log`): `imax` gets "The crate contains extracted
   external, unknown definitions", `plain` does not; with
   `-split-files` neither writes a file of external definitions (only
   `Types.lean` and `Funs.lean`); neither model has an axiom, opaque
   definition or sorry. `aeneas-warn/imax-X.lean` is `imax`'s model: it
   uses `core.num.I32.MAX` from Aeneas's library. The other nine
   development probes (constants, raw pointers, slices, traits,
   `--exclude`) are not committed; the conclusion rests on `imax` and
   the source citation below.
4. **The glue Miri rejected** (problem 3). `miri-prefix/verus-ffi.rs`
   and `miri-prefix/aeneas-ffi.rs` are the pre-fix files, with the
   sha256 that `miri-first.log` prints (`3c262356...`, `207a5b6f...`);
   `miri-prefix/fix.diff` is their diff with run B's. The bug is the
   line `let p = some(unsafe { args.subject.as_ref() });` before
   `from_raw_parts(p, args.subject_len as usize)`: a slice of
   `subject_len` bytes made from a reference to one byte. The fix makes
   the slice from `args.subject` itself, after a NULL check (the rest of
   the diff is the comment).
5. **Plan** (problem 4). `plans/05-unverified-calls.md` has a section
   "Deviations found during run B": the read accessor, the second
   control, Pulse's `SZ.fits_u32`, the Verus and Aeneas trusted slice,
   Isabelle-LLVM's full ownership and composition, Why3's model
   invariant, the Why3 classifier fix; it says that the prototype
   section describes the state before run B.
6. **Callee assumptions** (problem 5). `table.md` now lists Pulse's
   `SZ.fits_u32` (a platform fact the C caller is assumed to meet) and
   Why3's `const_args` invariant (`subject_len >= 0`, every byte in
   0-255, assumed of the C caller) in their callee-assumptions cells.
7. **How two read controls fail** (problem 6). From run B's raw logs.
   Aeneas (`aeneas-control-read/build.log`): the index step of
   `get_subject_byte_spec` leaves the slice bound open, and the next
   tactics fail on it: `Proofs.lean:288:11` "Invalid `⟨...⟩` notation:
   The expected type `(↑j).succ.le subject.length` has more than one
   constructor" and `:291:10` "Tactic `introN` failed". The expected
   type is `j < subject.length`, so the failure is at the read, but it
   is a proof-script failure, not an unprovable goal reported as such.
   Isabelle-LLVM (`isabelle-llvm-control-read/build.log`): "Failed to
   finish proof" at the `done` of line 526 of the control's `VU.thy`,
   three subgoals: (1) and (2), that the address read is in the
   subject's range, `(s +ₐ sint i) -ₐ s ∈ {0..<sint l}`; (3), that when
   `sint i ≥ sint l` the byte read equals `err_invalid_argument`. This
   supersedes "the index step of `get_subject_byte_spec` cannot be
   proved" and "'Failed to finish proof' on `vu_get_subject_byte_correct`"
   in the run B results table; `table.md`'s note on the second control
   says the same, and gives Why3's two prover failures (Alt-Ergo 10 s
   timeout, Z3 out of memory at 6 s).
8. **Citation** (problem 7). Checked against `AeneasVerif/aeneas` at
   `8f4466d`: `export_global` sets `ctx.extracted_opaque` at
   `src/Translate.ml:1007`, before the builtin check at `:1009-1012`;
   the warning is printed by `src/Main.ml:777-782` when that flag is set
   and `-split-files` is off. This supersedes `src/Translate.ml:1005-1006`
   in the run B entry; `table.md` and `warn.sh` cite the corrected
   lines.

## Deviations

- Fixes 2 and 4 commit files from development runs that the run B
  entry said were not recorded; they are recorded here as evidence, not
  as runs of this entry.

## Verdict

Run B's conclusions stand with the corrected counts: trusted lines Why3
140, Pulse 28, Verus 117, Aeneas 122, VST 54, Isabelle-LLVM 108; all
verdicts unchanged. The `--remap-path-prefix` reproducibility, the
Aeneas false positive and the Stacked Borrows rejection are now
reproducible from the branch.
