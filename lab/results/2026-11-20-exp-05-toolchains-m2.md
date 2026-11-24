# exp-05 toolchains-m2: Aeneas, VST and Isabelle-LLVM on the bench host

## What

Approach step 3 of `plans/05-unverified-calls.md` for milestone 2
(issue #13), on the bench host: `setup.sh 2`, which installs into
`<cache>` the toolchains of Charon + Aeneas (with Aeneas's Lean and its
Mathlib), VST with CompCert's `clightgen`, and Isabelle2026 with the AFP
and Isabelle-LLVM, plus the LLVM binaries that compile Isabelle-LLVM's
output, then smoke-tests each tool on a one-function example. Raw logs,
all redacted by the scripts, are in
[`2026-11-20-exp-05-toolchains-m2-raw/`](2026-11-20-exp-05-toolchains-m2-raw/):
the recorded run at the top level, the first installs in
`first-install/`.

## Why

The milestone 2 prototypes (step 5 for Aeneas, VST and Isabelle-LLVM)
need three working toolchains. The slow installs (the VST switch and the
Isabelle-LLVM session) start first, as the plan asks. This entry fixes
the versions and shows that each tool can prove a trivial function and
produce code before any prototype work.

## Setup

- Repository at `exp/05-unverified-calls` `8f0561d` for the recorded
  run (`repo_commit` in `provenance.txt`); `upstream/` at `f95747b`
  (`pinned=yes`).
- Bench host: AMD EPYC 7502P (64 CPUs online), Ubuntu 24.04.5 LTS,
  Linux 6.8.0-100, GCC 13.3.0. Load average 0.23 at the start of the
  recorded run, 1.02 at the start of the first installs.
- Coordination with experiment #4: issue #7's latest comment
  (2026-11-19) says mechanism 4 runs after this install and reuses it.
  No Isabelle or Poly/ML process was running on the host before the
  Isabelle steps (`setup.sh` checks it, `VU_ISABELLE_LLVM_OK=1`), and
  experiment #4 had not installed Isabelle-LLVM on the host.
- CPUs: at the first installs, another experiment had pinned
  CPUs 16-23 and 48-55; in the morning no process had a restricted
  affinity. Every step ran under `nice -n 10`, pinned with `taskset`:
  first installs of VST on 8-13,40-45 (12 jobs), Isabelle-LLVM on
  24-29,56-61 (12 jobs: `-j 3 -o threads=4`), Aeneas on 30-31,62-63 and
  LLVM on 14-15,46-47 (4 jobs each); the recorded run on 8-13,40-45 with
  `VU_JOBS=12` (12 for VST and Isabelle-LLVM, 4 for the rest). CPUs 4-7
  and 36-39 were never used.

## Runs

1. **First installs** (2026-11-19, from 22:31 UTC), the three slow
   components in parallel, each in its own `setup.sh 2 <component>` run.
   VST ran from `<exp>/repo` at `6834db6`; the other components ran
   from a copy of the harness under `<exp>/build/m2/harness` while
   `setup.sh` was being fixed (Isabelle mirror, Charon, LLVM, smoke
   tests; see the deviations). The `vst` step is the same in both
   versions.
2. **Smoke tests** (2026-11-20, from 08:57 UTC), from the same copy.
3. **Recorded run** (2026-11-20, 09:10 UTC): `setup.sh 2` with every
   component, from `<exp>/repo` at the committed `8f0561d`. Every step
   is idempotent and finds its tool installed: 77 s in all,
   `SETUP-END m2 status=0`. A first recorded attempt, a few minutes
   earlier and without the fix below, failed only `smoke-isabelle-llvm`: Isabelle skipped the unchanged
   smoke session, so `export_llvm` did not write `smoke.ll` again; the
   smoke test now cleans its session (`isabelle build -c`).

## Toolchains

| Tool | Version | Source | Install time | Disk (in `<cache>`) |
|---|---|---|---|---|
| Aeneas | `nightly-2026.11.19-8f4466d` (commit `8f4466db`) | release tarball, sha256 as pinned | 54 s with Charon's Rust and Lean | 582 MB (release) + 435 MB (prebuilt Lean build) |
| Charon | 0.1.321, commit `61c67516`, bundled in the Aeneas release | same tarball | (in Aeneas) | (in Aeneas) |
| Rust for Charon | `nightly-2026-09-17` (rustc 1.100.0-nightly `923c95cdf`), components rustc-dev, llvm-tools, rust-src, miri | rustup in `<cache>` | (in Aeneas) | 1.6 GB |
| Lean | v4.36.0-rc2 (commit `b35cb10c`), from Aeneas's `lean-toolchain` | elan v4.4.0 in `<cache>/elan`, sha256 as pinned | (in Aeneas) | 3.1 GB (`elan/`) |
| Aeneas Lean library | the release's `backends/lean`, Mathlib `9d581dff` (tag v4.36.0-rc2) with its 9,081 prebuilt files from Mathlib's cache | Lake | 71 s | 7.8 GB |
| VST | opam `coq-vst.2.17` | own opam root in `<cache>`, switch `vst`, `rocq-released` repository | 1386 s (23 min) | 1.3 GB (opam root) |
| CompCert (`clightgen`) | opam `coq-compcert.3.18`; the binaries print 3.17 | same switch | (in VST) | (in VST) |
| Rocq, OCaml | Rocq 9.2.0 (`coq` 9.2.0), OCaml 5.4.1 | same switch | (in VST) | (in VST) |
| Isabelle | Isabelle2026 | Cambridge mirror tarball, sha256 recorded at first fetch and now pinned | 457 s with the AFP and the session build | 2.7 GB (distribution) + 286 MB (heaps) |
| AFP | `afp-2026-11-19` | release tarball, sha256 as pinned | (in Isabelle) | 438 MB |
| Isabelle-LLVM | branch `2026`, commit `e42f4781`, session `Isabelle_LLVM` | git clone | session build 6 min 2 s wall, 1296 s user CPU, peak RSS 4.7 GB | 502 MB |
| LLVM | 23.1.5 (commit `392dfff9`) | release tarball, sha256 from the GitHub asset digest | 172 s | 12 GB |

The `Isabelle_LLVM` build compiled three sessions beyond the
distribution's HOL heap: `Automatic_Refinement` (34 s),
`Refine_Monadic` (51 s) and `Isabelle_LLVM` (4 min 10 s).

Disk: `<cache>` grew from 2.6 GB to 37 GB. Per tool: Aeneas 8.8 GB in
`aeneas/` plus 3.1 GB of Lean in `elan/` and 1.6 GB of Rust nightly in
`rustup/` (13.5 GB); VST 1.3 GB; Isabelle-LLVM 3.9 GB in `isabelle/`
plus 12 GB of LLVM (15.9 GB); downloads kept in `dl/` 3.6 GB more
(Isabelle 1.4 GB, LLVM 2.0 GB, AFP, Aeneas and its Lean build). `<exp>`
is 123 MB. About 67 GB remain free on the disk (101 GB before
milestone 2). LLVM is the largest item; only `clang` and `llc` are
needed, so its tree could be trimmed if disk runs short.

## Smoke tests

Each smoke test passed in the first installs and again in the recorded
run.

| Tool | Smoke test | Time |
|---|---|---|
| Charon + Aeneas | `add1` on `u32` (with a bound check) translated by `charon rustc --preset=aeneas` and `aeneas -backend lean`; the spec `add1 x ⦃ y => y.val = x.val + 1 ⦄` (for `x.val < 100`) proved with `step` and `scalar_tac`, checked by `lake env lean` in the Aeneas Lean project | 3 s |
| VST | `int add1(int x)` translated by `clightgen -normalize`; `semax_body` against a funspec with `PROP (Int.min_signed <= x < Int.max_signed)` proved by `start_function. forward.` | 3 s |
| Isabelle-LLVM | `add1 :: 32 word ⇒ 32 word llM` with an `llvm_htriple` proved by `vcg_monadify` and `vcg'`, exported by `export_llvm` to `smoke.ll`, compiled by `clang -c`, linked with a C `main` and run: prints 42 | 21 s |

Warnings, all harmless for the smoke tests: Aeneas's newer
`progress`→`step` naming (the smoke test uses `step`); Rocq 9.2's
deprecation of `From Coq` in `clightgen`'s output and a hint-database
warning from VST; clang overriding the target triple of Isabelle-LLVM's
output (`x86_64-pc-linux-gnu` to `x86_64-unknown-linux-gnu`).

## Usable per tool

- **Charon + Aeneas**: ready. Translation to Lean and proofs with
  Aeneas's library (on Mathlib) work.
- **VST**: ready. `clightgen` and VST's Floyd proofs work.
- **Isabelle-LLVM**: ready. VCG proofs, `export_llvm` and compilation of
  the exported LLVM IR work. Its code generator has a function-pointer
  type (`TFptr` in `thys/basic/kernel/LLVM_Builder.ml`), to be checked
  by the prototype.

## Deviations found on the bench host

These add to the deviations of milestone 1 (plan, "Deviations found
during milestone 1").

- **Isabelle mirror.** The TUM URL redirects to a plain-HTTP host that
  does not answer from the bench host; the download hung with no data.
  The tarball comes from the University of Cambridge mirror instead. Its
  sha256 was recorded on the first fetch and is now pinned.
- **Charon comes from the Aeneas release.** The Aeneas tarball bundles
  Charon 0.1.321 at `61c67516`, the build Aeneas is tested with; the
  standalone Charon nightly of the same day (`9b0ee438`, same version
  number) was installed by the first run but is not used, and was
  removed. `miri` is added to Charon's Rust components (its bundled
  `rust-toolchain` lists it; without it Charon falls back to rustc's
  default sysroot with a warning).
- **Aeneas's Lean library needs Mathlib.** The plan named Aeneas's Lean
  toolchain only. A new component `aeneas-lean` copies the release's
  `backends/lean` into `<cache>`, fetches Mathlib's prebuilt files with
  `lake exe cache get` and installs the release's prebuilt Aeneas build,
  so nothing is compiled. This is 7.8 GB.
- **LLVM is installed.** The bench host has no `clang` or `llc`, and
  Isabelle-LLVM emits textual LLVM IR that must be compiled to link with
  the C caller. LLVM 23.1.5 release binaries are in `<cache>/llvm`
  (23.1.6 is newer but was two days old).
- **CompCert's version string.** `coq-compcert.3.18` builds from
  CompCert's tag `v3.18`, whose `VERSION` file still says 3.17, so
  `clightgen -version` prints 3.17.
- **SIGPIPE in `setup.sh`.** The first `aeneas` step ended with status
  141: `head` closed a pipe under `pipefail` after everything was
  installed. The listing was removed and the step now uses `sed`.
- **Isabelle-LLVM is not readable from experiment #4's account.** It is
  installed in this account's `<cache>`, but the home directory that
  holds it is not traversable by other accounts. Issue #7 expects
  mechanism 4 to reuse this install: that needs either read access to
  `<cache>/isabelle` (and `<cache>/llvm`) or a copy into the shared
  cache. This is left for the maintainer to decide; nothing was changed.

## Verdicts

None yet: Aeneas, VST and Isabelle-LLVM stay "pending" until their
prototypes run. Their toolchains are ready.
