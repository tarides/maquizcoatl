# Plan: experiment #5, calls to unverified code

Issue: [#13](https://github.com/tarides/maquizcoatl/issues/13) (the
issue body is the reference for scope, inputs and done-criteria; this
plan says how).
Source: maintainer's state-of-the-art report, "Experiments before
deciding", row of experiment #5, and the stacks of "Option matrix and open questions"
(https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

## Objective

For every implementation tool on a stack A-F route, find out whether
verified code can call a C function pointer supplied by the client,
with a usable specification of that call, and what the proof can still
say around it. One minimal prototype per tool covers the three call
shapes the libonig API needs at `f95747b`: a client encoding function
(`mbc_enc_len`-like), a callout (`OnigCalloutFunc`-like, which also
covers `OnigCallbackEachMatchFunc`), and the two re-entrancy shapes
(verified function handed out as a pointer, as in `apply_all_case_fold`
-> `i_apply_case_fold`; verified symbol called by name, as the callout
accessors). The outcome is a verdict per tool (works / works with
trusted shim / does not work), which can eliminate routes before the
comparison wave.

## Decisions folded in

1. **Tools in scope: (c)**, decided by @balat, to whom the maintainer
   delegated the question
   ([delegation](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7012981833),
   [choice](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7011783314)):
   every implementation tool on a stack A-F route. The report's six
   first (Why3 C fragment, F\* + Pulse with KaRaMeL, Verus, Aeneas, VST,
   Isabelle-LLVM), then hax, Creusot, RefinedRust, Bedrock2, CN and
   RefinedC (CN and RefinedC are one route in the report but two tools,
   so each gets its own row).
2. **Toolchain that does not fit: (a)**
   ([comment](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7008513330)):
   the interim verdict is "deferred", and the tool is re-run when it
   can be installed; a toolchain problem never eliminates or keeps a
   stack by itself. A tool whose milestone has not run yet is
   "pending", which is not a verdict.
3. **Execution host**
   ([comment](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7007356187)):
   the bench host, not the workstation. The toolchains that
   experiment #7 installed there (Rocq, Lean, Why3, F\* with KaRaMeL)
   are reused, not reinstalled.

## Deviations decided on issue #13 before the run

These override the rest of the plan where they disagree.

- **Two caches.** Experiment #7's cache (in another account's home on the
  bench host) is readable but not writable from
  the account that runs this experiment. Its tools are used read only
  where they work (F\* with `krml` and Z3, elan and Lean, the opam switch
  `provers` with Why3 and Alt-Ergo); the scripts call it
  `VU_SHARED_CACHE` (`<shared-cache>`). Everything that must be installed
  or written goes into this account's own cache, which is what `<cache>`
  means below (`VU_CACHE`, same layout and `env.sh`), and into `<exp>`
  (`VU_EXP`). The VST switch is in an opam root of `<cache>`, not in
  `provers`'s root; the Why3 configuration (with its Z3 registration) is
  in `<cache>/why3`.
- **Jobs and CPUs.** Up to 12 jobs for the VST, Isabelle-LLVM and
  RefinedRust installs, 4 otherwise. Every heavy job runs under `nice`,
  pinned with `taskset` to free CPUs: never 4-7 and 36-39
  (experiment #11), nor a CPU another experiment pins (checked before
  each heavy job). This replaces "no CPU pinning is needed" below.
- **Isabelle-LLVM** is shared with experiment #4's mechanism 4, which
  must run alone on the bench host: it is not installed or built while
  that mechanism runs; coordination goes through issue #7.
- **Verdicts.** A toolchain that cannot be installed gives the interim
  verdict "deferred"; an install that does not finish in time gives
  "pending".
- **hax backends:** F\*, Rocq and Lean (milestone 3).
- **Disk:** about 100 GB free, not 142 GB; use is recorded per tool.

## Deviations found during milestone 1

Recorded in the `toolchains-m1` notebook entry.

- **F\* comes from `<cache>`, not from `<shared-cache>`.** The shared
  F\*'s `.checked` library files are readable only by their owner, so
  F\* cannot extract from this account. The same release (pinned
  sha256) is installed into `<cache>/fstar`, with its `krml` and Z3;
  Why3's Z3 is taken from it. `<shared-cache>` is used only for the
  switch `provers` (Why3, Alt-Ergo).
- **jq** is missing on the bench host: `setup.sh` installs the jq
  release binary into `<cache>/bin`.
- **F\* commands.** F\* v2026.11.15 extracts with `--codegen KrmlC
  --custard_entry M.f` after a check pass, then `krml
  -skip-compilation`; krmllib compiles with `-std=gnu11`.
- **Prototype runs** (recorded in the `prototypes-m1` entry). Each tool
  ran from its own copy of the harness in `<exp>/build/<tool>/harness`,
  not from `<exp>/repo`, so that the three prototypes could be worked
  on in parallel; the committed files have the same sha256 as the
  copies that ran. Builds are in `<exp>/build/<run-id>/<tool>` (the
  `run.sh` layout). `provenance.sh` was run with the Pulse run only, and
  its tool versions cover the three tools.

## Deviations found during milestone 2

Recorded in the `toolchains-m2` notebook entry.

- **Isabelle mirror.** The TUM download URL redirects to a host that
  does not answer from the bench host; Isabelle2026 comes from the
  University of Cambridge mirror, with its sha256 pinned after the first
  fetch.
- **Charon** is the one bundled in the Aeneas release (`61c67516`), not
  the standalone nightly, so that Charon's output matches what Aeneas
  reads; `miri` is added to its Rust components.
- **Aeneas's Lean library** needs Mathlib: a component `aeneas-lean`
  sets up a copy of the release's `backends/lean` in `<cache>` with
  Mathlib's prebuilt files and the release's prebuilt Aeneas build
  (7.8 GB).
- **LLVM 23.1.5** release binaries are installed in `<cache>/llvm`
  (12 GB): the bench host has no `clang` or `llc`, which Isabelle-LLVM's
  output needs.
- **Isabelle-LLVM is in this account's `<cache>`**, which experiment
  #4's account cannot read (the home directory is not traversable).
  Mechanism 4's reuse of it (issue #7) needs a decision: read access or
  a copy.
- **Prototype runs** (recorded in the `prototypes-m2` entry). As in
  milestone 1, each tool ran from its own harness copy. `provenance.sh`
  was run with the VST and Isabelle-LLVM runs only; its versions cover
  Charon and Aeneas, and Lean's version is taken from the Aeneas build
  log (Lean comes from the Aeneas library's `lean-toolchain`, not an
  elan default).
- **Aeneas** emits only the Lean model; the library is rustc's build of
  the same `src/lib.rs`, with overflow checks on. Aeneas has no
  function-pointer type, so the client functions are traits whose one
  implementation, in unverified Rust, does the indirect call.
- **VST** proves `vu.c` itself, which stays in VST's Clight subset (no
  `switch`); `clightgen` stays in the trusted toolchain.
- **Isabelle-LLVM** has no function-pointer type: an 8-line C shim does
  the indirect calls. Its arrays become nested pair structs, its
  exported symbols are renamed with `objcopy`, and clang 23 reads its
  typed-pointer IR.

## Deviations found during the review fixes

Recorded in the `review-fixes` notebook entry.

- **Runs from the clone.** The re-run of the six prototypes used
  `<exp>/repo` at the pushed commit instead of harness copies, so
  provenance records the commit; `run.sh` also writes the sha256 of
  every harness source at the head of each `build.log`.
- **Why3 `(void)to`.** The trusted no-op is a val that returns the 0 of
  `vu_i_apply` (`((void)to, 0)`), not a unit statement, which Why3's
  extraction erases; 4 trusted lines instead of the 2 expected.
- **Struct mirrors of Verus and Aeneas** are checked by member offset in
  their trusted glue, against `proto.h`'s LP64 layout written as
  numbers (15 counted lines each), rather than compared with `proto.h`
  by compiling C as Pulse and Isabelle-LLVM do.
- **Not applied:** the review's point on the `oniguruma.h:738`
  citation; the line is correct at `f95747b`.

## Taken back by the pipeline (2026-11-21)

Milestones 1 and 2 and the review fixes were run by @balat (branch head
`1dcc3dc`; [results](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7039631438),
[review](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7038827493)).
On 2026-11-21 the maintainer took the experiment back into the
experiment pipeline ([comment](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7060575635)).
The pipeline continues on this branch and keeps the earlier commits and
notebook entries as they are; corrections go in new entries.

Decisions folded in:

- **Isabelle-LLVM, shape (a):** compose the client hypothesis of
  `vu_fold_all` with `vu_i_apply_correct` in a proof; the verdict is
  unchanged, the table says the composition is proved
  ([decision](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7059928154)).
- **Read-only access through accessors:** option (b), one read accessor
  (for example `vu_get_subject_byte`) added to `proto.h` and to the six
  prototypes before milestone 3, whose proofs and negative controls are
  then re-run; milestones 3 and 4 use the extended prototype (same
  decision).
- **Scheduled follow-ups**, with milestone 3 and before its new tools:
  a Miri test of shape (b) for Verus and Aeneas, and the Aeneas warning
  "extracted external, unknown definitions" (commit `Vu.lean`, add the
  pure-function assumption)
  ([decision](https://github.com/tarides/maquizcoatl/issues/13#issuecomment-7059943097);
  "Scheduled follow-ups" in the issue body).
- **F\* eta-reduction report:** tracked in issue #29, also taken back.

Runs, each at most 3 hours and followed by an independent review on
issue #13:

- **Run A:** toolchains for milestones 1 and 2, then a replay of the six
  milestone 1-2 prototypes with them, compared with the recorded raw
  outputs of the `review-fixes` entry.
- **Run B:** the two decisions above, the Miri test, the Aeneas warning,
  and the F\* master check for issue #29.
- **Run C:** milestone 3 (hax with its F\*, Rocq and Lean backends,
  Creusot, RefinedRust).
- **Run D:** milestone 4 (Bedrock2, CN, RefinedC), then the single
  summary table on the issue.

**Toolchains.** The earlier runs used a toolchain cache that the
pipeline's account cannot read. The pipeline installs its own copies,
with the same pins (`pins.json`, sha256 checked), into the project's
shared toolchain cache on the bench host. `setup-pipeline.sh` gives
`setup.sh` the cache layout it expects as a directory of links into the
shared cache, so `setup.sh`, `run.sh` and the `build.sh` scripts run
unchanged; every place where the shared cache differs is listed in that
script and in the Run A notebook entry. Run A's status is "pending"
for a tool only when its install did not finish; "deferred" keeps its
meaning from the Decisions (a toolchain that cannot be installed at
all).

## Deviations found during run B

Recorded in the `runB` notebook entry and its `runB-corrections`
entry. The prototype section below describes the state before run B:
since run B there are five verified functions (with the read accessor)
and two negative controls per tool.

- **Read accessor.** `proto.h` has `vu_get_subject_byte(args, i)`,
  returning byte `i` of the subject when `0 <= i < subject_len` and
  `VU_ERR_INVALID_ARGUMENT` otherwise; `caller.c` calls it from a
  callout and directly, and `expected.txt` has four new lines.
- **Second negative control** (`run.sh -r`): the upper bound test of
  `vu_get_subject_byte` is removed, and every proof must fail at the
  read, as the clamp control must fail at the clamp.
- **Pulse** needs a new precondition on the accessor, `SZ.fits_u32`
  (Pulse indexes arrays with `size_t`, whose width F\* leaves to the
  target): a platform fact the C caller is assumed to meet.
- **Verus and Aeneas** cannot read through the raw pointer `subject`;
  trusted glue turns it into a shared slice of `subject_len` bytes,
  whose length agreement is a precondition (Verus) or a theorem
  hypothesis (Aeneas). The verified side holds no permission on the
  subject across the callout. Trusted lines: Verus 102 to 117, Aeneas
  109 to 122.
- **Isabelle-LLVM** has no fractional permissions: the callout and the
  accessor get the subject whole (full ownership), and the contract
  says the same bytes come back. Shape (a) is composed with
  `vu_i_apply_correct` under a client contract, `respects_i_apply`.
- **Why3** models the subject as an immutable field of the read-only
  `const_args`, with an invariant (`subject_len >= 0`, bytes in
  0-255) assumed of the C caller.
- **Why3's `build.sh`** classified Z3's "Out of memory" as an error, not
  a rejection; the test is now case-insensitive.

## Deviations found during run C

Recorded in the `runC` notebook entry.

- **hax toolchain.** The release binary is a standalone `cargo-hax`
  that runs only the Lean backend. The full toolchain is built from the
  tag, as its `setup.sh` does: the Rust binaries with `cargo install
  --locked` into `<cache>/hax/<tag>`, and the OCaml engine in an opam
  switch `hax` on OCaml 5.4.1 (created with `--no-switch`). The cargo
  build directory is removed after the install.
- **hax's F\*.** The cache's F\* 2026.11.15 cannot check hax v0.5.0's
  output (no `FStar.Mul`; its `--help` does not list `--cmi`, which
  `hax/build.sh` drops and logs since the run C corrections), so the
  plan's first choice does not apply. The pinned F\* v2025.10.06 is needed.
- **hax's Rocq backend** needs hax's `Core` Rocq library and
  `coq-record-update` (v0.3.7). Both are built with `provers`'s Rocq 9.3
  into `<exp>/build/hax-rocq-libs`; neither is installed in `provers`.
- **hax's Lean extraction** is the Charon + Aeneas pipeline: on first
  use it downloads its own Charon (`nightly-2026.10.31`, 43 MB) and
  Aeneas build (`build-2b9e3ea`, 562 MB) into `XDG_CACHE_HOME`, and
  runs them (run C corrections, fix 4).
- **Three hax tools.** `hax-fstar/` and `hax-rocq/` are `run.sh` tools
  that share the prototype in `hax/`. `hax/link-check.sh` links and runs
  the library without any proof, to check the C ABI while no proof can
  run.
- **Disk floor.** Every milestone 3 install after hax's was refused:
  F\* v2025.10.06 (1 GB), the Lean backend (10 GB), Creusot (7 GB) and
  RefinedRust (6 GB). Those tools are pending, and the remaining runs
  wait for the maintainer's disk-floor decision. The hax Lean, Creusot
  and RefinedRust installs are moreover not written yet (each
  `setup.sh` step is a disk check followed by `vu_die`), nor is
  RefinedRust's commit pinned: that is work for the next run.
- **Disk accounting** (run C corrections). The hax install's disk check
  ran after the Rust nightly (1.4 GB) was installed, and the Lean tools
  (604 MB) had none: about 4.3 GB measured against a 3 GB estimate.
  The check now comes first and the estimates are 4 GB (hax) and 1 GB
  (smoke-hax). `disk.txt` measures the view through its links.

## Deviations found during run D

- **No milestone 4 install.** The bench host had 19 GB free when run D
  started, under the 20 GB floor, and the disk-floor decision asked
  since run A is still open; `setup-pipeline.sh 4` refused each of the
  three installs, and an install of 0 GB too. The installs were not
  written and no prototype was written: Bedrock2, CN and RefinedC stay
  "pending" (not "deferred": no install failed).
- **CN's repository.** The tools table says "opam pin of a Cerberus
  checkout at master". CN has since moved to its own repository,
  `rems-project/cn` (Cerberus master has `cerberus*.opam` files and no
  `cn` package). At the pinned CN commit `f2e8eeb4`, `cn.opam` has a
  `pin-depends` on `cerberus-lib` at Cerberus `a0f7071` (2026-11-13),
  the commit CN's own build uses; the install pins the CN checkout and
  lets that `pin-depends` bring `cerberus-lib`, with no separate pin.
  Run D first recorded Cerberus master `e29a8ec9` (28 commits ahead);
  corrected after the review of run D (`pins.json`).
- **Disk sizes** for the three tools are in `pins.json`
  (`disk_gb`: Bedrock2 3, CN 3, RefinedC 5). They are guesses, not
  measurements: each `disk_note` says what it adds up from (the hax
  switch, 2.2 GB, and the VST switch, 1.2-1.3 GB, are the only
  measured sizes it leans on). Each is replaced by the `du -sL` of the
  install once it runs.
- **RefinedRust's commit** is pinned at `main` `2862b1d8`
  (2026-11-16), retrieved with `git ls-remote` after the review of
  run D; its install is still not written.

## Deviations found during run E

Recorded in the `runE` notebook entry. Maintainer decisions of
2026-11-21 before the run: disk freed (69 GB free; the 20 GB floor
stays), hax's Rocq verdict final, hax's Lean backend not run ("same
pipeline as Charon + Aeneas, with hax-lib specifications in front; not
run"), the Isabelle-LLVM model client a recorded follow-up.

- **Parallel installs.** `setup-pipeline.sh` locks per component list,
  not per view, and `setup.sh` writes `env.sh` through a file of its own
  process: the five installs ran side by side, each on its own CPU set.
- **hax F\*.** The pinned F\* v2025.10.06 goes to
  `<cache>/hax/fstar-v2025.10.06` (`hax-fstar/build.sh` sets
  `VU_HAX_FSTAR` to it). With it, `Vu.fst` failed at the first call of a
  client method: hax gives a trait method without `requires` an
  abstract F\* precondition (`f_enc_len_pre`) that no caller can
  establish. `EncLen` and `Callout` now carry `requires(true)`, which
  assumes nothing of the callee; `ApplyAll`'s contract range in
  `TRUSTED` moves from `lib.rs:105-109` to `:113-117`.
- **Creusot.** The tag's `creusot-install`, with its data and
  configuration directories in `<cache>/creusot`. `why3-ide` is left out
  (opam variable `in-creusot-ci`): it needs GTK system libraries the
  bench host lacks, and the first try stopped at opam's depext prompt.
  `cargo-creusot` is in the cache's `CARGO_HOME/bin`. The build copies
  `why3find.json` from the data directory, as `cargo creusot init`
  does.
- **CN** cannot call a client pointer: "Function pointer must be
  provably equal to a defined function". The three indirect calls are
  in `trusted` C shims, as for Isabelle-LLVM. In this CN version, C
  integers are mathematical integers in specifications (no `i32`
  suffixes), and array reads need `focus` and `instantiate`.
  `count-trusted.sh` counts a `/*@ ... @*/` block as code (CN's
  specifications are in comments).
- **RefinedC** needs its struct annotations inside the struct
  definitions, hence `refinedc/vu_rc.h`, a copy of `proto.h` with
  `[[rc::...]]` attributes, which `build.sh` checks against `proto.h`.
  `refinedc` and `coq-lithium` are pinned by URL at the commit: a path
  pin has no `.git`, where `dune subst` fails. `count-trusted.sh`
  counts `//@` lines (RefinedC's Rocq prelude) as code. The C tests are
  written `y <= x` rather than `x >= y`, whose failed branch reaches
  Lithium as `(x ?= y) = Lt`, which `lia` does not read.
- **opam pins of the partial clones** (`--filter=blob:none`) cannot be
  git pins (git upload-pack fails), so CN's and RefinedRust's checkouts
  are pinned with `--kind=path`.
- **Bedrock2**: installed, prototype not written within the cap
  (pending).

## Where things live

- **Bench host.** Nothing is installed system-wide; the account's own
  opam root and rustup are not touched.
  - `~/maquizcoatl-work/cache/` (written `<cache>`): the shared
    toolchain cache of experiment #7, extended here. Already present:
    `<cache>/bin/opam` (opam 2.6.1), `<cache>/opam/` (`OPAMROOT`, switch
    `provers`), `<cache>/fstar/` (F\* binary release with `krml` and the
    bundled Z3 versions), `<cache>/elan/` (Lean), `<cache>/env.sh`.
    Added by this experiment: `<cache>/rustup/` and `<cache>/cargo/`
    (`RUSTUP_HOME`, `CARGO_HOME`; each Rust tool installs the toolchain
    it pins), `<cache>/verus/`, `<cache>/aeneas/` (Charon and Aeneas),
    `<cache>/isabelle/` (Isabelle2026 and Isabelle-LLVM, with
    `ISABELLE_HOME_USER` inside it), extra opam switches only when a
    tool's Rocq or Iris constraints conflict with `provers` (see Tools),
    and `env.sh` extended accordingly (still idempotent and sourced by
    every command).
  - `~/maquizcoatl-work/exp/05-unverified-calls/` (written `<exp>`): a
    clone of `tarides/maquizcoatl` at the branch's commit with
    `upstream/` at `f95747b` (`<exp>/repo/`, `upstream/` read only), the
    out-of-tree C build (`<exp>/build/onig/`), per-tool build
    directories (`<exp>/build/<tool>/`) and raw outputs
    (`<exp>/out/<run-id>/`).
- **Workstation.** `<workdir>` is the work directory outside the
  repository; this branch's worktree is under `<workdir>/wt/`. Raw
  outputs are copied back to `<workdir>/e05/out/` before selection.
- **Repository** (branch `exp/05-unverified-calls`):
  - `experiments/05-unverified-calls/`: `proto.h` (the C interface every
    prototype implements), `caller/` (the C caller and its expected
    output), one directory per tool (`why3/`, `pulse/`, `verus/`,
    `aeneas/`, `vst/`, `isabelle-llvm/`, `hax/`, `creusot/`,
    `refinedrust/`, `bedrock2/`, `cn/`, `refinedc/`) holding the
    prototype, its proof artefacts, a `build.sh` and a `TRUSTED` file
    listing the trusted files and line ranges; `setup.sh` (per
    milestone), `run.sh`, `count-trusted.sh`, `provenance.sh`,
    `pins.json` (versions, URLs, commits, sha256) and `table.md` (the
    summary table).
  - `lab/notebook.md` and `lab/results/`: the lab notebook.

Generated C, Rust or LLVM that a tool emits is not committed unless a
notebook entry needs it; its size and sha256 are recorded. Scripts take
`<cache>` and `<exp>` from environment variables and never print
absolute paths, hostnames or addresses, so raw files can be committed
after a redaction check.

## The prototype (same for every tool)

`proto.h` fixes the C interface, built from the upstream signatures
(`upstream/src/oniguruma.h:128-153`, `:738`, `:771`, `:774-777`):

- `typedef int (*vu_enc_len_fn)(const unsigned char *p);`, the shape of
  `mbc_enc_len`.
- `typedef int (*vu_callout_fn)(vu_args *args, void *user_data);`, the
  shape of `OnigCalloutFunc` (`vu_args` is an opaque struct standing for
  `OnigCalloutArgs`, holding a read-only view of a subject, a
  verified-side state and `ONIG_CALLOUT_DATA_SLOT_NUM` = 5 data slots).
- `typedef int (*vu_apply_fn)(unsigned int from, unsigned int *to,
  int to_len, void *arg);` and `typedef int (*vu_apply_all_fn)(vu_apply_fn
  f, void *arg);`, the shapes of `OnigApplyAllCaseFoldFunc` and
  `apply_all_case_fold` (flag argument dropped).

Verified functions each tool implements and exports with C linkage:

1. `vu_char_len(f, p, st)`: calls `f(p)` and clamps the result to
   `[min_enc_len, max_enc_len]` held in `st` (precondition
   `1 <= min <= max`). Proven postconditions: the result is in
   `[min, max]` for every callee result (the callee is trusted for
   nothing but returning an `int`), and `st` is unchanged across the
   call. This is the place where upstream trusts the encoding blindly
   (`enclen`, `upstream/src/regenc.h:83`); the record says what the
   caller demands of the callee.
2. `vu_callout_step(dir, f, args, ud)`: calls the callout and branches
   like `match_at`. Upstream's rules, read from `regexec.c` at
   `f95747b`:
   - progress direction (`upstream/src/regexec.c:4616-4631`):
     `ONIG_CALLOUT_FAIL` (1) backtracks (`goto fail`),
     `ONIG_CALLOUT_SUCCESS` (0) continues, any other positive value
     becomes the error `ONIGERR_INVALID_ARGUMENT`, a negative value is
     returned as an error;
   - retraction direction (`RETRACTION_CALLOUT`,
     `upstream/src/regexec.c:1218-1234`, invoked when the stack is
     popped through `POP_CALLOUT_CASE`, `:2287-2291`):
     `ONIG_CALLOUT_FAIL` and `ONIG_CALLOUT_SUCCESS` both continue (there
     is nothing left to backtrack), any other positive value becomes
     `ONIGERR_INVALID_ARGUMENT`, a negative value is returned as an
     error;
   - each-match callback (`upstream/src/regexec.c:3387-3400`): a
     negative value is returned as an error; any other value sets the
     result to `ONIG_MISMATCH` and fails, so the search goes on.

   `dir` selects the progress or retraction rules (the each-match rule
   is modelled the same way if the tool's prototype covers it; if a
   tool models only the progress direction, the record says so).
   Proven postconditions: the returned action is determined by `dir`
   and the callee's result as above; the verified-side state in `args`
   is unchanged except for the data slots.
3. `vu_i_apply(from, to, to_len, arg)`: a verified function with its
   own specification (for example, it increments a counter in `arg` and
   records `from` only when `to_len` is in range), and
   `vu_fold_all(client_apply_all, arg)`, which passes `vu_i_apply` to the
   client as a C pointer: re-entrancy shape (a), modelled on
   `i_apply_case_fold` (`upstream/src/regparse.c:8739`).
4. `vu_get_slot(args, k)` and `vu_set_slot(args, k, v)`: exported
   verified accessors, the analogue of
   `onig_get_callout_data_by_callout_args` and
   `onig_set_callout_data_by_callout_args`
   (`upstream/src/oniguruma.h:1021-1071`), with bounds checks on `k`,
   called by name by the client's callout during step 2: re-entrancy
   shape (b).

`caller/caller.c` supplies the pointers and checks the results against
`caller/expected.txt`: a well-behaved encoding (`mbc_enc_len` of UTF-8,
`upstream/src/utf8.c:70-74`, copied with its notice together with the
`EncLen_UTF8` table it reads, `:47-68`, keeping only the
`USE_RFC3629_RANGE` arm since `:33` defines that macro) and a
misbehaving one returning 0, -5 and 100 (clamping); callouts returning
0, 1, 2 (a positive value other than `ONIG_CALLOUT_FAIL`, which must
become `ONIGERR_INVALID_ARGUMENT`) and -2, in both directions, one of
which calls `vu_get_slot`/`vu_set_slot`; and an
`apply_all_case_fold` that calls back through the pointer it receives.
The same caller is linked against each tool's object. If experiment #4
has published `client_encoding.c` on its branch by then, the encoding
part is taken from it instead of being rewritten.

**Negative control, per tool:** removing the clamp from `vu_char_len`
must make the proof fail. This shows the proof depends on the callee's
contract and that the run is not "compiles but proves nothing"
(done-criterion 1). The control also checks that the external
declaration listed in `TRUSTED` gives the callee's result no range
(only "returns an `int`"), so an over-strong axiom cannot make the
clamp-free proof pass.

## Tools and versions

All are listed as active in the report's Maintenance status table.
Versions are the latest on the day this plan was written; `setup.sh`
pins each in `pins.json` (release tag, or commit for tools without
releases), and the notebook records the versions actually installed.

| Tool | Version | Source on the bench host | Stack | Milestone |
|------|---------|--------------------------|-------|-----------|
| Why3 (C extraction) | 1.9.0, Alt-Ergo 2.6.5; Z3 4.15.3 (or 4.13.3) from the F\* bundle in `<cache>/fstar` registered in `why3.conf` (Why3 1.9.0's `provers-detection-data.conf` accepts Z3 4.8.x-4.15.x only, so not Z3 5.3.0) | already in switch `provers` | E | 1 |
| F\* + Pulse, KaRaMeL | F\* v2026.11.15 with its bundled `krml` | already in `<cache>/fstar` | C | 1 |
| Verus | 0.2026.11.02.8bf68ee (latest non-rolling release), Rust 1.99.1 (the toolchain it names) | release binary, rustup in `<cache>` | D | 1 |
| Charon + Aeneas | nightly tags of 2026-11-19 (commits recorded); Charon's Rust `nightly-2026-09-17`; Lean v4.36.0-rc2 from Aeneas's `lean-toolchain` (elan fetches it into `<cache>/elan`) | linux-x86_64 release binaries (both nightlies ship them) | B | 2 |
| VST + CompCert | opam packages `coq-vst.2.17` and `coq-compcert.3.18` (`clightgen`) | opam, `rocq-released` repository, in a switch `vst`: `coq-compcert.3.18` requires `coq < 9.3~` and `coq-vst.2.17` requires it, while `provers` has Rocq 9.3.0 | A | 2 |
| Isabelle-LLVM | Isabelle2026, `lammich/isabelle_llvm` branch `2026` (last pushed 2026-10-19; commit recorded) | release tarball, git clone | F | 2 |
| hax | cargo-hax v0.5.0 (repository `pereq-dev/hax`, formerly `cryspen/hax`), which pins F\* v2025.10.06 (`flake.nix` at tag `cargo-hax-v0.5.0`): the F\* backend tries `<cache>/fstar` first, else uses the F\* v2025.10.06 binary installed beside it, and the record says which; the Rocq backend uses `provers`; backends in scope: see the open question on issue #13 | cargo install from the tag | A (and B via its Lean backend, which is the Charon + Aeneas pipeline: `cargo hax into lean` runs Charon and Aeneas, so its verdict is Aeneas's model with hax-lib's specifications in front) | 3 |
| Creusot | v0.14.0, Rust `nightly-2026-08-03`, with the Why3 and solvers its `cargo creusot setup` pins (run with `XDG_DATA_HOME` and `XDG_CONFIG_HOME` under `<cache>/creusot/`, so the account's home is untouched) | cargo install from the tag | E | 3 |
| RefinedRust | `lgaeher/refinedrust-dev` (MPI-SWS GitLab), commit recorded | its documented opam + rustup setup, in a switch `refinedrust` on OCaml 4.14.2 (as its README requires) | A | 3 |
| Bedrock2 | `mit-plv/bedrock2` master, commit recorded | source build against Rocq in `provers` (or the Rocq its submodules require, recorded) | A | 4 |
| CN (Cerberus) | `rems-project/cerberus` master, commit recorded (there is no `cn` package in opam-repository) | opam pin of a Cerberus checkout at master | A | 4 |
| RefinedC | `iris/refinedc` (MPI-SWS GitLab), commit recorded | opam, in a switch `refinedc` on Coq 9.1.0 with the `iris-dev` repository and `cerberus-lib` pinned at `f11e6b3` (a second Cerberus checkout, separate from CN's) | A | 4 |
| GCC | 13.3 (Ubuntu 24.04) | system (C caller, linking, Why3/KaRaMeL/CN output) | | all |
| CMake | system | out-of-tree build of `upstream/` | | all |

No tool is installed from an abandoned fork. Isabelle-LLVM's `master`
branch (last pushed 2022-09-29) is not used.

The versions above that are already known (Verus and its Rust 1.99.1,
Charon's `nightly-2026-09-17`, Creusot's `nightly-2026-08-03`, Aeneas's
Lean v4.36.0-rc2, `coq-vst.2.17` / `coq-compcert.3.18`, hax's F\*
v2025.10.06, RefinedC's `cerberus-lib` at `f11e6b3`, the
Isabelle-LLVM branch) go into `pins.json` from the start; `setup.sh`
adds commits and sha256 as it fetches. Opam package names in
`pins.json` are the real ones (`coq-vst`, `coq-compcert`; there is no
`rocq-vst.2.17`).

## Machine budget

Bench host, shared with other experiments: at most 4 parallel jobs
(`opam --jobs=4`, `make -j4`, `cargo build -j4`, `isabelle build -j 1
-o threads=4`), never the CPUs pinned by experiment #11's timing runs
(4-7 and 36-39, re-checked with `lscpu -e` and the other experiments'
notes before starting). At most 3 hours of wall-clock per run, setup
included. Long jobs run under `tmux` (or `nohup`), with logs in
`<exp>/out/`. Each proof check runs under a `timeout` (20 min) and
`ulimit -v 64G`, except `isabelle build`, whose JVM reserves large
virtual ranges: it runs under `timeout` and Isabelle's own options,
with peak RSS recorded by `/usr/bin/time -v`. Hitting a limit is
recorded as the result for that check. Nothing here is a timing
measurement, so no CPU pinning or load threshold is needed. Disk: about 142 GB free; the extra switches and
Rust toolchains are expected to add 15-25 GB, recorded per tool.

All twelve tools do not fit in 3 hours, so the experiment runs in four
milestones, each one run of at most 3 hours. Milestone 1 is this run;
milestones 2-4 are follow-up runs with the same method and no new
decision needed.

**Milestone 1 (this run): shared harness plus Why3, F\* + Pulse,
Verus.** Their toolchains are already installed (Why3, F\*) or are
binary releases (Verus).

| Phase | Steps | Time |
|-------|-------|------|
| Clone, upstream build, Verus + Rust install, caller check | 2-4 | 25 min |
| Why3, Pulse, Verus prototypes in parallel (3 jobs, 4th for builds) | 5 | 120 min |
| Negative controls, trusted-line count, fetch, record | 6-8 | 35 min |

**Follow-up runs** (each at most 3 hours, same budget):

- **Milestone 2:** Aeneas (with Charon), VST (with CompCert),
  Isabelle-LLVM, completing the report's six. The VST switch and the
  Isabelle-LLVM session build are the slow installs; they start first
  and run alongside the Aeneas prototype. If an install does not finish
  inside the run, the install completes in the next run and the
  prototype follows; the tool stays "pending" meanwhile, and becomes
  "deferred" only if the toolchain cannot be installed at all
  (Decision 2).
- **Milestone 3:** hax, Creusot, RefinedRust.
- **Milestone 4:** Bedrock2, CN, RefinedC.

## Approach

1. **Write the harness** (workstation). `proto.h`, `caller/caller.c`,
   `caller/expected.txt`, `run.sh`, `count-trusted.sh`,
   `provenance.sh`, `setup.sh`; a pure-C reference implementation of
   the four verified functions (`caller/reference.c`, unverified)
   checks that caller and expected output agree. Re-check the branch
   rules of the prototype section against `upstream/src/regexec.c`
   (progress, retraction, each-match) and copy them, with citations,
   into the `harness` notebook entry. Commit and push.

2. **Clone and build upstream** (bench host, about 5 min). Clone the
   branch with `--recurse-submodules` into `<exp>/repo`, check
   `upstream/` is at `f95747b`, build out of tree
   (`cmake -S <exp>/repo/upstream -B <exp>/build/onig
   -DCMAKE_BUILD_TYPE=Debug`, `make -j4`), and run `test_utf8` and
   `test_back`. Their callout cases (`upstream/test/test_utf8.c:1376-1382`,
   `upstream/test/test_back.c:1201-1203`) exercise the built-in callouts
   registered through function pointers (`upstream/src/ascii.c:45-48`,
   `BC0_P` in `upstream/src/regint.h:1002-1009`): a sanity check of the
   path being modelled, not a test of the prototypes.

3. **Toolchains for the milestone** (in parallel with step 2).
   `setup.sh 1`: check `<cache>` and that the switch `provers`, F\*,
   `krml` and Z3 answer with the versions of experiment #7; register the
   bundled Z3 4.15.3 (or 4.13.3) with Why3; install rustup into
   `<cache>`, the Verus release and the Rust toolchain it names; smoke-test each tool on its own hello-world
   (a Why3 module extracted to C, a `#lang-pulse` function extracted
   through `krml`, a Verus function verified and built). Record
   versions and disk use.

4. **Caller check.** Link `caller.c` with `reference.c`; the output must
   equal `expected.txt`. This fixes the harness before any tool runs.

5. **Prototype per tool** (the core; criteria 1-3). For each tool:
   write the four verified functions with their specifications; find
   how the tool expresses a call through a client C pointer; prove the
   postconditions of the prototype section; emit C (Why3 `extract -D c`,
   KaRaMeL), Rust (`cdylib`, `extern "C"`, `#[no_mangle]`) or LLVM; link
   with `caller.c`; compare with `expected.txt`. Where the tool cannot
   type or call a C function pointer, the smallest C or `unsafe` Rust
   shim that does the indirect call is written, given a specification
   in the tool (axiom, `external_body`, `assume val`, driver `syntax`,
   funspec), and listed in `TRUSTED`. The record states which of the
   three modelling styles was used (axiomatised external, trusted shim,
   client contract), the callee assumptions (termination, re-entrancy,
   result range, access to engine state), and the ownership lent to the
   callee: read-only access through the accessors, writes confined to
   the data slots. Re-entrancy (a) and (b) are each built and run, or
   the record states why the tool cannot express them.
   Expectations to check, not assumptions: Why3's C fragment has no
   function-pointer type, so a driver-level shim is likely; KaRaMeL
   compiles first-order function arguments to C function pointers, to
   be confirmed for Pulse functions; Verus may need `external_body`
   wrappers around the indirect call and around raw pointers.

6. **Negative control** (criterion 1). Remove the clamp; the proof must
   fail, and the failure message is kept. A tool whose proof still
   passes is a finding and blocks its verdict until explained.

7. **Count and table** (criteria 2 and 4). `count-trusted.sh` counts
   non-blank, non-comment lines of the files and ranges in each
   `TRUSTED` (shims, axioms, driver entries, glue), with the comment
   syntax stated per language in the script (C and Rust `//`, `/* */`;
   WhyML, F\*, Rocq and Isabelle `(* *)`; Lean `--`, `/- -/`; Why3
   drivers `(* *)`); where a language is not covered it counts raw
   non-blank lines and says so. It also records the sha256 of each
   file listed in `TRUSTED`. `table.md` gets one
   row per tool with the issue's columns: tool, version, verdict,
   modelling style, trusted lines, callee assumptions, re-entrancy (a),
   re-entrancy (b); tools of later milestones appear as "pending".
   Verdicts: *works* (no trusted code beyond the declaration of the
   external call's type and specification), *works with trusted shim*
   (shim size stated), *does not work* (reason stated), or "deferred"
   (Decision 2). Next to any *does not work* verdict, the record cites
   experiment #1's numbers (0 callouts and UTF-8 only across its 5,870
   triples), so the weight of the missing feature is visible; the
   eliminator itself is unchanged.

8. **Fetch back and record.** `rsync` `<exp>/out/<run-id>/` to
   `<workdir>/e05/out/`, run the redaction check (absolute paths,
   hostnames, addresses), copy the files that back a notebook entry
   into `lab/results/`, commit the prototypes and proof artefacts on
   the branch, push, and post the table on issue #13.

Milestones 2-4 repeat steps 3 and 5-8 for their tools.

## Provenance

`provenance.sh` records per run: CPU model and kernel version of the
bench host, the number of jobs used, load average at start and end,
the version or commit of every tool used (from `pins.json` and the
tools' own `--version`), the Rust toolchains and opam switches used,
compiler flags, the repository commit and the `upstream/` commit,
start time and duration. It does not record the hostname, addresses,
user names or absolute paths.

## Lab notebook

With the lab-notebook skill: `lab/notebook.md` (index, one line per
recorded run, linking to its file) and
`lab/results/<date>-exp-05-<topic>.md` (append-only), raw logs beside
it. Planned entries for milestone 1:

1. `toolchains-m1`: versions, smoke tests, disk use of the additions to
   `<cache>`.
2. `harness`: the branch rules read from `regexec.c`, the caller and
   its expected output, the upstream sanity tests.
3. `prototypes-m1`: per tool (Why3, Pulse, Verus), criteria 1-4: build
   and link commands, proof check result and time, negative control,
   modelling style, `TRUSTED` contents and line counts, callee
   assumptions, ownership, re-entrancy (a) and (b), verdict; plus the
   summary table.

Each later milestone adds a `toolchains-m<N>` and a `prototypes-m<N>`
entry. Exploratory runs are not recorded on their own; the maintainer
decides on any further entry.

## Outputs

- `experiments/05-unverified-calls/` (harness, prototypes, proof
  artefacts, `TRUSTED` files, scripts, `pins.json`, `table.md`).
- The lab notebook entries above.
- The summary table posted on issue #13, updated after each milestone.
- Extensions of the shared toolchain cache `<cache>` on the bench host
  (Verus, Rust, Aeneas, VST, Isabelle-LLVM, ...), usable by experiments
  #4, #6, #8, #9, #10 and #13.

## Done-criteria (from the issue)

For each tool in the list above:

1. A minimal prototype, kept on the experiment branch: verified code that takes a C function pointer with a `mbc_enc_len`-like signature and one with an `OnigCalloutFunc`-like signature, calls each, and branches on the result. The prototype compiles to a C-ABI object and is linked and run against a C caller that supplies the pointers. The tool also checks a proof of at least one caller postcondition that depends on the callee's contract (for example: the `mbc_enc_len`-like result is in `[min_enc_len, max_enc_len]` after clamping; the caller's state is unchanged across the call). The proof artefact is kept on the branch.
2. A record of what the tool requires to verify the caller: the shape of the external call's specification, the trusted code added (lines), the assumptions made about the callee, and the ownership lent to the callee (which engine state it may read through accessors, and which it may write, i.e. the callout-data slots).
3. A check of re-entrancy in its two shapes, or the record states why the tool cannot express one of them:
   - (a) verified code passes one of its own functions out as a C pointer that the client calls (`apply_all_case_fold` → `i_apply_case_fold`);
   - (b) the client calls an exported verified symbol by name (the callout accessors).
4. A verdict per tool: *works*, *works with trusted shim* (shim size stated), or *does not work*, with the reason.

Results are recorded in the lab notebook and summarised in one table on this issue, with columns: tool, version, verdict, modelling style (axiomatised external / trusted shim / client contract), trusted lines, callee assumptions, re-entrancy (a), re-entrancy (b).

Milestone 1 meets these criteria for Why3, F\* + Pulse and Verus; the
experiment is done when every tool has a verdict ("deferred" counts as
an interim verdict, Decision 2).

## Risks

- **Prototype engineering exceeds the run.** Two hours for three
  prototypes is tight for proof work. Mitigation: `reference.c` and
  `proto.h` fix the target first; the four functions are tiny; a tool
  whose prototype is not finished keeps "pending" and moves to the next
  run, rather than being forced into a verdict.
- **A tool cannot call a function pointer at all.** That is a result
  (criterion 4), not a failure of the run; the shim fallback is tried
  first, and "does not work" is recorded only with the reason.
- **Trusted shim hides the call.** A shim that also does the branching
  would make the proof vacuous. Rule: the shim does only the indirect
  call and returns the raw `int`; clamping and branching stay in
  verified code. The negative control checks it.
- **Version conflicts between Rocq-based tools.** VST, RefinedRust,
  RefinedC and Bedrock2 may each pin a different Rocq or Iris.
  Mitigation: a separate opam switch per conflicting tool, recorded;
  `provers` is not altered, so experiment #7's results stay
  reproducible.
- **Slow installs (VST, Isabelle-LLVM heap, RefinedRust).** They start
  first in their milestone, at 4 jobs; an unfinished install moves to
  the next run. "Deferred" applies only if installation fails.
- **Rust toolchains.** Verus, Charon, hax, Creusot and RefinedRust
  each pin a nightly or a specific stable Rust; all go into `<cache>`'s
  rustup, never the account's own one.
- **Shared host.** Other experiments run on the bench host; the job
  cap and the CPUs reserved for experiment #11 are respected, and the
  start load is recorded.
- **Leaking host details.** Raw outputs pass a redaction check before
  they are committed; the host is named only as "the bench host".
