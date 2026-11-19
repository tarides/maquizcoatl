# Plan: experiment #4, ABI feasibility per output mechanism

Issue: https://github.com/tarides/maquizcoatl/issues/7 (the issue body is
the reference for scope, inputs and done-criteria; this plan says how).
Source: maintainer's state-of-the-art report, section "Experiments before
deciding", row #4: https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc

## Objective

For each of the four output mechanisms (1: C from F\* + Pulse, through
two emitters, 1a KaRaMeL `--codegen KrmlC` and 1b Custard's direct
`--codegen C`; 2: C proven directly, VST or Why3; 3: Rust `cdylib`; 4: Isabelle-LLVM),
find out whether it can produce a true drop-in for `libonig` at
`f95747b`, and where verification stops at the ABI boundary.

Scope follows decision (b) on the issue
(https://github.com/tarides/maquizcoatl/issues/7#issuecomment-7007006165):
the binary-level criteria (1-3, 5, 6) apply to all four mechanisms; the
source-level criterion 4 (pkg-config, CMake/autotools, emscripten) is run
for mechanisms 1 and 2 only. For mechanisms 3 and 4 the source-level
verdict is the report's prediction ("source level needs Rust" for stacks
B and D, "binary level only" for stack F), recorded as predicted, not
measured.

Mechanism 1 follows the second decision on the issue
(https://github.com/tarides/maquizcoatl/issues/7#issuecomment-7007376276),
option (b): both F\* to C routes are tested, as sub-rows 1a (KaRaMeL,
`--codegen KrmlC`) and 1b (Custard, `--codegen C`) sharing one Pulse
source and the same harness. Criteria 1-6 are answered for each
emitter separately.

## Where things live

- `<workdir>` is a directory outside the repository. Builds, toolchains,
  stubs and logs go under it, never in the repo and never in `upstream/`
  (and not in the session scratchpad, a small tmpfs):
  - `<workdir>/exp04/build/onig/` and `<workdir>/exp04/build/onig-posix/`
    — out-of-tree Release builds of upstream `f95747b`, default and
    `-DENABLE_POSIX_API=ON` (the symbol oracle);
  - `<workdir>/exp04/harness/` — test binaries, `testp`, the 15 samples
    (15 of the 16 `sample/*.c`; `crnl.c` excluded, it needs
    `USE_CRNL_AS_LINE_TERMINATOR`, which the CMake build sets to 0),
    the client-encoding test and the layout program, built against the
    upstream headers;
  - `<workdir>/exp04/stubs/{m1a,m1b,m2,m3,m4}/{default,posix}/` — per mechanism a
    default stub and a POSIX stub (the default one plus the 8
    `onig_posix_*` functions and `onigposix.h`), each installed into its
    own prefix (`lib/`, `include/`, `lib/pkgconfig/`) and diffed against
    the matching oracle build;
  - `<workdir>/toolchains/` — emsdk, the F\* release tarball (Pulse and
    KaRaMeL included), Why3 and CompCert's `clightgen` (opam switch),
    Isabelle + Isabelle-LLVM;
    shared with other experiments where they already exist.
- In the repository (branch `exp/04-abi-feasibility`):
  - `experiments/04-abi-feasibility/` — scripts (`oracle.sh`,
    `check-stub.sh`), `layout.c`, `client_encoding.c`, the stub sources
    per mechanism, the symbol classification, and the results tables;
  - `lab/notebook.md` and `lab/results/` — the lab notebook.

## Tools and versions

Only actively maintained tools. Installed now (recorded again in the
notebook at run time): GCC 15.2, Clang 21.1, CMake 4.2, GNU binutils 2.46
(`nm`, `readelf`, `ld`), pkg-config, rustc/cargo 1.93.1, opam 2.4.1.
To install, from binary releases where they exist, one at a time, latest
release at run time with the exact version recorded:

- `cbindgen` (via `cargo install`) — C header from the Rust stub's
  `#[repr(C)]` types, for mechanism 3's layout check;
- Why3 (opam, 1.9.0 in the default opam repository) for mechanism 2's
  WhyML-to-C extraction check (`why3 extract -D c`);
- CompCert `clightgen` for VST's front end: package `coq-compcert` from
  the Rocq released opam repository (`rocq-released`,
  https://rocq-prover.org/opam/released), which is not configured here
  and must be added; it builds on `rocq-prover` (9.3.0 in the default
  repository), tens of minutes and 2-3 GB on a fresh switch;
- emsdk (latest emscripten) for criterion 4, mechanisms 1 and 2;
- F\* Linux x86_64 release tarball (v2026.11.15 or later, about 250 MB),
  which ships `bin/fstar.exe`, `bin/krml`, `share/pulse/` and
  `share/krml/`, for mechanism 1; not the opam `karamel` package (1.0.0,
  stale);
- Isabelle release tarball (Isabelle2026) plus Isabelle-LLVM from
  `lammich/isabelle_llvm`, branch `2026` (matching Isabelle2026; `master`
  was last pushed in 2022-09 and is not used), for mechanism 4.

## Approach

1. **Oracle** (about 20 min; criterion 1). Two out-of-tree Release builds
   of `upstream/` with `make -j4`. Record `nm -D --defined-only`,
   `readelf -d` (SONAME `libonig.so.5`) and the three file names
   `libonig.so.5.5.0` -> `libonig.so.5` -> `libonig.so`. Classify each
   exported symbol as public (declared in `oniguruma.h`, `oniggnu.h`,
   `onigposix.h`) or leaked internal (`regenc.h`), by grepping the
   installed headers; write `symbols.tsv` (name, kind F/D, class,
   header:line, build default/posix). The expected counts are derived
   from `symbols.tsv`, never hard-coded; as a cross-check, the review
   measured 270 functions and 52 data symbols in the default build
   (44 public: 30 `OnigEncoding*`, KOI8 declared-only, 12 `OnigSyntax*`,
   `OnigDefaultSyntax`, `OnigDefaultCaseFoldFlag`; plus 8 leaked
   internals), and 278 functions (the 8 extra `onig_posix_*`) and the
   same 52 data symbols in the POSIX build. The POSIX symbols at
   `f95747b` are prefixed: `onig_posix_regcomp`, `onig_posix_regexec`,
   `onig_posix_regfree`, `onig_posix_regerror`,
   `onig_posix_reg_set_encoding`,
   `onig_posix_reg_name_to_group_numbers`, `onig_posix_reg_foreach_name`,
   `onig_posix_reg_number_of_names` (`upstream/src/onigposix.h:163-173`);
   unprefixed `regcomp` etc. are macros (`:176-187`) and exist as symbols
   only with `ENABLE_BINARY_COMPATIBLE_POSIX_API`, off by default and
   not used here.

2. **Harness** (about 30 min; criteria 2, 3). In `<workdir>/exp04/harness/`:
   - the seven test binaries taken from the default build and only
     `testp` from the POSIX build (so no binary's `RUNPATH` points at
     the other build), relinked against any `libonig.so.5` via
     `LD_LIBRARY_PATH`. Upstream's CMake gives them a `DT_RUNPATH` to
     the build tree, so a stub prefix lacking `libonig.so.5` would
     silently resolve upstream; the copies in the harness have their
     `RUNPATH` removed (`patchelf --remove-rpath`), and `check-stub.sh`
     also asserts the resolved library path (below);
   - the 15 of the 16 `sample/*.c` (`crnl.c` excluded) compiled directly against
     `upstream/src/oniguruma.h` with `-lonig` (`posix.c` against the
     POSIX build); golden outputs recorded from upstream (stdout, exit
     status) for later mechanisms that implement real behaviour;
   - `client_encoding.c`: a caller-filled `OnigEncodingType` seeded from
     `OnigEncodingASCII`'s initialiser (`upstream/src/ascii.c:103`),
     every function pointer and data field set, used with `onig_new` /
     `onig_search`; shared with #5;
   - `layout.c` and `layout_posix.c`: print `sizeof` and every
     `offsetof` for each non-opaque public struct listed in the issue's
     Inputs, compiled once against the upstream header and once against
     a stub's shipped header; outputs diffed. The POSIX part is a
     separate translation unit using the real type names
     `onig_posix_regex_t` and `onig_posix_regmatch_t`
     (`upstream/src/onigposix.h:79-89`), because `oniguruma.h:716`
     typedefs `regex_t` while `onigposix.h:176` defines it as a macro.
   - `check-stub.sh <prefix> <default|posix>`: runs criteria 1-3
     against a stub prefix and the matching oracle (symbol diff with the
     public/internal split, SONAME and the three names, layout diff, and
     per binary). Per binary it first asserts, with `ldd` (or
     `LD_DEBUG=libs`), that the `libonig.so.5` actually resolved lives
     under the stub prefix; a binary resolving it elsewhere fails. Then
     pass = `ldd -r` reports no `undefined symbol` **and** the run under
     `LD_BIND_NOW=1` (with a timeout) does not end with the loader's
     `symbol lookup error` (exit status 127). Any other exit status
     (abort or segfault at the first wrong result) is recorded, not
     scored.
   Validate the harness on upstream itself: `check-stub.sh` on each
   oracle build must report zero missing symbols and all passes; and a
   negative control, an empty prefix, must fail every binary.

3. **Mechanism 2, hand-written C stub** (about 30 min; criteria 1-3, 5).
   A C stub generated mechanically from the public headers: every public
   function with a fixed return value, every data symbol as a file-scope
   initialised struct with function pointers, a genuinely variadic
   `onig_error_code_to_str` using `va_list`; linked with
   `-Wl,-soname,libonig.so.5`, installed with the three names; a
   default and a POSIX variant. Ship the upstream headers. Run
   `check-stub.sh` on both. Then the Why3 check: Why3 does not consume
   C, its C route is WhyML to C (`why3 extract -D c`). Write a minimal
   WhyML module and record, per construct, whether the C driver can emit
   (a) a named file-scope struct initialised with function pointers
   under an exact exported name (`OnigEncodingUTF8`), (b) an `extern`
   data symbol with an exact C name, (c) a variadic definition
   (expected: no, so a hand-written C layer, recorded under
   criterion 5). For Why3 the C is generated, so its ABI boundary looks
   like mechanism 1's (generated C plus a hand-written shell); for VST
   the proof is about the hand-written C itself. The results table keeps
   them as two rows of mechanism 2. The `clightgen` (VST) check on the
   hand-written stub's constructs (file-scope struct initialisers
   holding function pointers, the variadic definition, `va_list`,
   `OnigCalloutArgs` layout) comes last in milestone 1, see below. This
   stub is also the C shell the other mechanisms can be compared
   against.

4. **Mechanism 3, Rust `cdylib`** (about 40 min; criteria 1-3, 5).
   Edition 2024, rustc 1.93.1 (version recorded). `#[repr(C)]` types
   mirroring the headers, `#[unsafe(no_mangle)] pub static` data symbols
   with function pointers, `extern "C"` functions; soname via
   `-C link-arg=-Wl,-soname,libonig.so.5`. Cargo emits only
   `libonig.so`; `libonig.so.5.5.0` is the installed file and
   `libonig.so.5`, `libonig.so` are symlinks made by the install step.
   Layout checked twice: the shipped upstream header against the Rust
   types (via `layout.c` and a Rust program printing
   `size_of`/`core::mem::offset_of!`, stable), and a `cbindgen` header.
   Record how `onig_error_code_to_str` is defined: rustc 1.93.1 rejects
   a variadic definition with `error[E0658]: C-variadic functions are
   unstable` (rust-lang/rust#44930); keep that compiler error as the
   criterion 5 evidence. The expected route is a small C shim linked
   into the `cdylib`; that shim is outside any proof. Criterion 4:
   predicted verdict only.

5. **Mechanism 2 source level** (about 25 min; criterion 4). A CMake
   build and an `oniguruma.pc` for the mechanism 2 stub; `pkg-config
   --cflags --libs oniguruma` and a client build against the installed
   prefix; install emsdk and build the stub with `emcmake cmake`.

6. **Mechanism 1, C from F\* + Pulse, two emitters** (follow-up, see
   budget). Install the F\* release tarball (it ships Pulse, KaRaMeL and
   Custard). Write one Pulse/F\* source for a minimal stub (one encoding
   struct, one syntax struct, `onig_new`/`onig_free`/`onig_search`
   returning fixed values), then extend it mechanically to the full
   symbol set. The same source is extracted twice; since F\* v2026.11.15
   extraction goes through Custard, and every run needs an entry-point
   flag (`--custard_main`, `--custard_entry` or
   `--custard_entry_module`); the exact flags are recorded in the
   notebook.
   - **1a, KaRaMeL** (`--codegen KrmlC`): KaRaMeL module prefixes,
     `-bundle`/`-no-prefix` options.
   - **1b, Custard** (`--codegen C`): Custard's own naming and layout
     rules.
   For each emitter, check what the generated C looks like at the ABI:
   symbol names, struct layout and field order, static initialisers
   with function pointers, soname. Whatever the emitter cannot produce
   (variadic function; possibly the data-symbol names) goes into a
   hand-written C layer, recorded as outside the proofs; the two
   emitters may need different shells. Each output is built into its
   own stub prefix (`m1a`, `m1b`), and `check-stub.sh` and criterion 4
   (CMake, pkg-config, emscripten on the generated C) run on both. The
   results table has two sub-rows, 1a and 1b, each with its own
   criteria 1-6, criterion 5 stating per emitter what sits inside and
   outside the proofs and how `onig_error_code_to_str` is defined.

7. **Mechanism 4, Isabelle-LLVM** (follow-up). Install Isabelle2026 and
   Isabelle-LLVM from its branch `2026`; export a minimal stub to LLVM IR, compile with Clang
   to a shared object with soname `libonig.so.5`; check which ABI
   constructs Isabelle-LLVM can express (named global structs with
   function pointers, C struct layout, variadic definition) and which
   need a C or hand-written LLVM shim. Criteria 1-3, 5; criterion 4
   predicted.

8. **Verdicts and report** (about 15 min; criteria 5, 6). One results
   table per mechanism (criteria 1-4 pass/fail, criterion 5 statement,
   verdict with blocker), notebook entries, push, summary comment on
   the issue, then the PR.

## Machine budget

At most 4 parallel jobs (`make -j4`, `cargo -j4`, at most 4 concurrent
test binaries) and at most 3 hours of wall clock for the run. Plan with
about 4 GB of RAM and about 20 GB of disk on the shared drive, with
other experiments running in parallel. Toolchains are installed
sequentially, never in parallel with a build.

The four mechanisms together are "days per mechanism" in the report, so
they do not fit in 3 hours. Milestones:

- **Milestone 1 (this run, 3 h):** steps 1-5 and 8 for mechanisms 2
  and 3: the oracle, the full harness, criteria 1-3 and 5 for
  mechanisms 2 and 3, criterion 4 for mechanism 2, the predicted
  source-level verdict for mechanism 3, and the Why3 check of
  mechanism 2. The step estimates sum to 160 min with no install time,
  so toolchain installs (cbindgen, emsdk, Why3) get an explicit
  allowance of about 45 min inside the milestone; the two upstream
  builds take about a minute each, so step 1 can absorb part of it. The
  CompCert `clightgen` check (adding `rocq-released`, installing
  `coq-compcert`, running `clightgen`) comes last, boxed at 30 min; if
  it overruns, it is recorded as pending and moves to follow-up 1.
  Disk under 4 GB in `<workdir>` (emsdk about 1.5 GB) plus 2-3 GB for
  the Rocq/CompCert switch.
- **Follow-up 1:** step 6, mechanism 1 (F\* + Pulse, extracted with
  KaRaMeL and with Custard), its own run: 3 hours plus about half a day
  for the second emitter (extraction, its C shell, `check-stub.sh` and
  criterion 4 on a second prefix); the Pulse source, the harness and
  emsdk are shared.
- **Follow-up 2:** step 7, mechanism 4 (Isabelle-LLVM), its own run;
  Isabelle needs several GB of disk and its session builds most of the
  free RAM, so it runs alone on the machine. This scheduling constraint
  is noted on issue #7 so other experiments' runs do not overlap it.

If any step exceeds twice its estimate, stop, record where it stands in
the notebook and report on the issue instead of continuing.

## Lab notebook

Using the lab-notebook skill: `lab/notebook.md` (index, one line per
recorded run) and `lab/results/` (append-only, never overwritten).
Each entry carries provenance: commit of this branch and of `upstream/`
(`f95747b`), CPU model and RAM, kernel and OS version, compiler and tool
versions, build flags, exact commands, durations.
Planned entries:

1. `oracle` — symbol listings and classification, SONAME, file names,
   harness validation against upstream (criterion 1 reference).
2. `m2-c-stub` — criteria 1-3 for mechanism 2, the front-end construct
   table, criterion 4 results.
3. `m3-rust-cdylib` — criteria 1-3 for mechanism 3, the variadic route,
   predicted criterion 4.
4. `m1a-krml`, `m1b-custard` and `m4-isabelle-llvm` — in the
   follow-up runs.
5. `verdicts` — criteria 5 and 6 across the mechanisms done so far
   (updated by a new entry, never by editing, after each follow-up).

Re-runs that only confirm an earlier deterministic result are not
recorded.

## Outputs

- `experiments/04-abi-feasibility/`: `oracle.sh`, `check-stub.sh`,
  `layout.c`, `client_encoding.c`, `symbols.tsv`, stub sources
  (`m2-c/`, `m3-rust/`, later `m1-pulse/` with its two extraction
  outputs `m1a-krml/` and `m1b-custard/`, `m4-isabelle/`), results
  tables (Markdown).
- Lab notebook entries as above.
- A summary comment on issue #7 and a PR from `exp/04-abi-feasibility`.
- Golden outputs of the samples and the client-encoding test are shared
  with #5.

## Done-criteria (from the issue)

For each of the four mechanisms, a results table recording:

1. Every exported symbol (functions and data): diff `nm -D
   --defined-only` of the stub against the same listing of upstream's
   `libonig.so.5` built from `f95747b`, listing every missing and every
   extra symbol. Classify each upstream symbol as public (declared in
   the installed headers `oniguruma.h`, `oniggnu.h`, `onigposix.h`) or a
   leaked internal (from `regenc.h`: `OnigEncDefaultCharEncoding`,
   `OnigEncAscii*Table`, `OnigEncISO_8859_1_ToLowerCaseTable`,
   `OnigUnicodeFolds1/2/3`, `OnigAsciiLowerMap`). `readelf -d` shows
   `SONAME libonig.so.5`, and the three names `libonig.so.5.5.0`,
   `libonig.so.5`, `libonig.so` exist.
2. Layout check: a C program asserting `sizeof` and `offsetof` for every
   field of every non-opaque public struct listed under Inputs is
   compiled against both upstream's header and the stub's shipped
   header, and the two outputs compared; pass/fail per struct.
3. Each upstream test binary, `testp`, every `sample/` program and the
   client-encoding test loads and links against the stub via
   `LD_LIBRARY_PATH` without unresolved symbols, run under
   `LD_BIND_NOW=1` or checked with `ldd -r` so lazily bound functions
   are resolved (pass/fail per binary; exit status is not the measure,
   and match results are not expected from a stub).
4. Source level, mechanisms 1 and 2: `pkg-config --cflags --libs
   oniguruma` works, the CMake or autotools build succeeds, and an
   emscripten build succeeds (pass/fail each). Mechanisms 3 and 4: not
   run; record the report's predicted verdict ("source level needs
   Rust" for stacks B and D, "binary level only" for stack F) with the
   foreign toolchain the client build would need, marked as predicted,
   not measured.
5. A short statement of which code is inside and which is outside the
   proofs at the ABI boundary, including how each mechanism defines the
   variadic `onig_error_code_to_str` (KaRaMeL cannot emit variadic
   definitions; Rust `c_variadic` is unstable). For mechanism 1 this
   is answered separately for each emitter (1a KaRaMeL, 1b Custard).
6. A verdict per mechanism: binary drop-in yes/no, source drop-in yes/no
   (predicted for mechanisms 3 and 4), with the blocker if no.

Results recorded in the lab notebook; no build artefacts in the
repository.

## Risks

- **Budget.** Four mechanisms at days each cannot fit one run.
  Mitigation: milestones above; the harness is built once and reused.
- **Stub crashes under the test binaries.** Upstream tests abort on the
  first wrong result. Mitigation: criterion 3 scores linkage only
  (`ldd -r`, `LD_BIND_NOW=1`), each run under a timeout; crashes after
  load are noted, not scored.
- **Symbol drift between builds.** CMake and autotools builds may export
  slightly different sets. Mitigation: the oracle is the CMake Release
  build, as in the issue; the autotools set is not used.
- **Layout check blind spots.** `offsetof` does not cover bit-fields or
  padding inside unions. Mitigation: also compare `sizeof` and
  `_Alignof` of each field type; note any bit-field explicitly.
- **KaRaMeL naming and layout.** KaRaMeL prefixes names with the module
  path and may rename fields; data symbols with exact names may need
  `-no-prefix`, `-bundle` or a C alias layer; Custard's direct C
  backend may differ. That is a finding for criterion 5, not a failure
  of the plan. Decided on issue #7: both routes are tested (1a
  `--codegen KrmlC`, 1b `--codegen C`).
- **Second emitter cost.** Testing both routes adds about half a day to
  follow-up 1. Mitigation: one shared Pulse source and harness; if one
  emitter blocks early (e.g. cannot emit an exact data-symbol name),
  record the blocker for that sub-row and finish the other.
- **Front-end availability for mechanism 2.** `clightgen` comes with
  CompCert, whose licence is non-commercial for most of its sources;
  fine for a feasibility check, recorded next to the result. It is not
  in the configured opam repositories (needs `rocq-released`). If
  CompCert or Why3 does not install within its box, the check moves to
  follow-up 1.
- **Isabelle resources.** Isabelle-LLVM session builds may exceed the
  free RAM. Mitigation: run follow-up 2 alone; if it still does not fit,
  record the blocker and report on the issue.
- **Disk pressure.** About 20 GB free on the shared disk. Mitigation:
  binary releases, a 4 GB cap for milestone 1, build trees removed after
  the run (the pins make them reproducible).
