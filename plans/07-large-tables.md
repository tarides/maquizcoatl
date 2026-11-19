# Plan: experiment #7, large tables in the prover

Issue: [#11](https://github.com/tarides/maquizcoatl/issues/11) (the
issue body is the reference for scope, inputs, measurement method and
done-criteria; this plan says how).
Source: maintainer's state-of-the-art report, "Experiments before
deciding", row #7, and the "Generated tables" item
(https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

## Objective

Load Oniguruma's largest generated table,
`upstream/src/unicode_property_data.c` (612 `CR_*` range arrays, 24,443
ranges, 629 `CodeRanges` entries, 886 property names, Unicode 16.0), into
Rocq, Lean 4, Why3 and F\*, push it through each tool's extraction or
compilation path, and measure the cost: check time and peak memory,
extraction and compile time, in-prover membership queries, one sanity
lemma, and correctness of the extracted membership function against the
C library. The outcome is a per-tool verdict, provisional until
experiment #6 reports: table as an in-prover definition, or as
unverified runtime data checked by the generator or a separate check.

## Decisions folded in

1. **Acceptance budget (criterion 6): relative cap**, from the
   maintainer's
   [comment](https://github.com/tarides/maquizcoatl/issues/11#issuecomment-7008343994):
   the table must not exceed the rest of the spec's build time, settled
   after experiment #6 (issue #1). #6 has not run, so this run records
   every number needed to apply the cap later (check, extraction and
   compile times and peak memory, per tool and per target), and states
   each verdict as **provisional**, with the threshold left symbolic
   ("in-prover if T_table <= T_spec(#6)"). When #6 reports, the
   verdicts are settled from the recorded numbers in a new notebook
   entry; nothing is re-run unless tool versions differ.
2. **Execution host**, from the maintainer's
   [comment](https://github.com/tarides/maquizcoatl/issues/11#issuecomment-7007356627):
   the run happens on the blocksci bench host (64 hardware threads,
   about 500 GB RAM, about 160 GB free disk, no root). The workstation
   RAM and disk limits of the original issue no longer apply. Public
   provenance of that host is its CPU model, kernel and tool versions
   only.
3. **Concurrency of timed runs: (c)**, from the maintainer's
   [comment](https://github.com/tarides/maquizcoatl/issues/11#issuecomment-7008749724):
   exploratory and bisection runs may run concurrently; the three timed
   runs that enter the notebook run one after another (see Machine
   budget).
4. **F\* C backends: (b), both**, same comment, as decided for
   experiment #4: KaRaMeL (`--codegen KrmlC` + `krml`) and the direct C
   backend (`--codegen C`) are two separate targets, each recorded under
   criteria 2 and 5.

## Where things live

- **Bench host.** Nothing is installed system-wide and the account's
  existing opam root (opam 2.1.5) is not touched.
  - `~/maquizcoatl-work/cache/` (written `<cache>`): shared toolchains,
    reusable by later experiments (#13 on issue #3, #5 on issue #13):
    `<cache>/bin/opam` (a pinned current opam binary),
    `<cache>/opam/` (`OPAMROOT`, one switch `provers` holding OCaml,
    Rocq, Why3, Alt-Ergo, F\*), `<cache>/karamel/` (KaRaMeL built from a
    pinned commit), `<cache>/elan/` (`ELAN_HOME`, Lean toolchains),
    `<cache>/z3/` (the Z3 versions F\* asks for), `<cache>/env.sh`
    (sets `OPAMROOT`, `ELAN_HOME`, `PATH`; every later command runs
    through it).
  - `~/maquizcoatl-work/exp/07-large-tables/` (written `<exp>`): a
    clone of `tarides/maquizcoatl` at the branch's commit with the
    `upstream/` submodule at `f95747b` (`<exp>/repo/`, read only for
    `upstream/`), the out-of-tree C build (`<exp>/build/onig/`), the
    UCD 16.0.0 files (`<exp>/ucd/`), per-tool build directories
    (`<exp>/build/<tool>/`), and raw outputs (`<exp>/out/<run-id>/`).
- **Workstation.** `<workdir>` is the work directory outside the
  repository; this branch's worktree is under `<workdir>/wt/`. Raw
  outputs are copied back to `<workdir>/e07/out/` before selection.
- **Repository** (branch `exp/07-large-tables`):
  - `lab/07-large-tables/`: `setup.sh` (toolchains), `emit.py` (parser
    and per-tool emitters), `fidelity.py`, `oracle.c` (C oracle),
    `sample.py` (query sample), `run.sh` (timed runs), `provenance.sh`,
    `summarise.py`, `pins.json` (versions, URLs, sha256), and the
    hand-written per-tool parts under `rocq/`, `lean/`, `why3/`,
    `fstar/` (membership function, queries, sanity lemma, extraction
    driver). Generated table sources are not committed (they are
    reproducible from `emit.py`); their sizes and sha256 are recorded.
  - `lab/notebook.md` and `lab/results/`: the lab notebook.

Scripts take `<cache>` and `<exp>` from environment variables with the
defaults above and never print absolute paths, hostnames or addresses
into their output, so raw files can be committed after a redaction
check.

## Tools and versions

All actively maintained. Versions are the latest releases on the day
this plan was written, except OCaml (see below); `setup.sh` pins every
version in `pins.json`, and the notebook records the versions actually
installed.

| Tool | Version | Source on the bench host |
|------|---------|--------------------------|
| opam | 2.6.1 | release binary in `<cache>/bin`, sha256 checked |
| OCaml | 5.4.1 (`ocaml-base-compiler`) | opam switch `provers` |
| Rocq | 9.3.0 (`rocq-prover`), plus `rocq-native` | opam |
| Why3 | 1.9.0 | opam |
| Alt-Ergo | exact version fixed in `pins.json` when it is written (step 1: the latest opam release that day), never "latest" at setup | opam (prover for the Why3 lemma, if needed) |
| F\* | v2026.11.15, with Pulse (stage 3 `fstar.exe`) | Linux binary release first (`fstar.lib` and the Pulse-enabled `fstar.exe`); source build only if the binary release does not suffice (see below) |
| Z3 | 5.3.0, the version F\* v2026.11.15 requires (its `INSTALL.md`; `.scripts/get_fstar_z3.sh` also fetches 4.8.5, 4.13.3 and 4.15.3, installed only if F\* asks for them) | GitHub release binaries in `<cache>/z3` |
| KaRaMeL | `master` at setup, commit recorded (no release tag since v1.0.0 of 2022-02; last commit 2026-11-17) | git clone, built against the F\* above |
| elan | v4.4.0 | release binary, `--no-modify-path`, `ELAN_HOME=<cache>/elan` |
| Lean 4 | v4.36.0 | elan, pinned by `lean-toolchain` |
| GCC | Ubuntu 24.04 package | system (C oracle, KaRaMeL and Why3 C output, Lean's native build) |
| CMake | system | out-of-tree build of `upstream/` |
| Python | 3.12, stdlib only, run with `-I` | system |

OCaml is pinned to 5.4.1 although 5.5.2 is the latest release: 5.4.1
is the one release line on which all of Rocq 9.3.0, Why3 1.9.0,
Alt-Ergo and F\*'s `fstar.lib` are expected to install together, and
`fstar.lib` must be compiled by the switch's OCaml for the extracted
OCaml to link. The reason is recorded beside the pin in `pins.json`.

F\*: the Linux binary release is checked first. If its `fstar.exe`
is Pulse-enabled and its `fstar.lib` links with OCaml code compiled by
the switch, no source build is done. Otherwise F\* is built from the
release source tarball, building only the `3.full` target (not
`make all`, which builds three stages and runs the stage-1 and stage-2
tests), and the choice is recorded. Low\* is not part of F\*
v2026.11.15 (it moved to the separate `FStarLang/LowStar` repository)
and is not used: the report's Decisions name Pulse, not Low\*. At
setup, a one-line `#lang-pulse` module is checked as a smoke test.
`gperf` is not needed.

## Machine budget

Bench host: experiments #3 (fuzzing, up to 40 jobs) and #11 (timing,
pinned to the L3 complex of CPUs 4-7 and SMT siblings 36-39) run there
at the same time, so this run uses at most 12 parallel jobs
(`opam --jobs=12`, `make -j12`) and never uses CPUs 4-7 or 36-39. Up
to 32 jobs would be allowed on an otherwise idle host,
and at most 3 hours of wall-clock for the whole run, setup included.
Long jobs run under `tmux` (or `nohup`), with logs in `<exp>/out/`.
Each tool check runs under `ulimit -v 64G` and a `timeout`; hitting
either counts as the documented failure of criterion 1 for that tool
and representation, with the size reached.

Timed runs (criterion 2) that enter the notebook run one after
another (Decision 3), never two at a time, each pinned with `taskset`
to one L3 complex kept for timing (the EPYC 7502P has eight complexes
of four cores; avoiding complex 0, which takes most interrupts, and
complex 1, pinned by #11; layout re-checked with `lscpu -e`).
Exploratory and bisection runs may run concurrently with each other,
on other cores. `uptime` is checked before each timed run and its load
average is recorded with the run; timed runs are not started when the
load average exceeds 8 (the background load of #3 is recorded, not
avoided). Per-run cap: 20 minutes;
if the first clean run of a step exceeds 10 minutes, that step is run
once and flagged "single run" instead of the median of three.

Expected schedule (wall-clock):

| Phase | Steps | Time |
|-------|-------|------|
| Setup, in parallel | 1-3 | 60 min |
| Emit, fidelity, oracle | 4-6 | 15 min (overlaps setup) |
| Per-tool check, extract, compile, queries (four tools concurrently) | 7-10 | 60 min |
| Sanity lemma by reflection, sample check | 11-12 | 30 min |
| Fetch, record | 13-14 | 15 min |

**Milestone 1** (fits in 3 hours): all four tools, one representation
each (the primary one below), criteria 1, 2, 3, 5 and 6 (provisional),
and criterion 4 as a proof by computation (reflection) with a 30-minute
check cap per tool. **Follow-up**, outside this budget, listed on the
issue if needed: the secondary representations; a structural
(non-computational) proof of the sanity lemma within the issue's
2-hour engineering budget per tool, for tools where reflection fails;
settling the verdicts when #6 reports.

## Representations

The representation is the main variable behind the timings (Goal of
the issue), so each is recorded. Primary (milestone 1) and secondary
(follow-up, or fallback if the primary fails):

| Tool | Primary | Secondary |
|------|---------|-----------|
| Rocq | one `Definition` per property, `list (Z * Z)`; membership by a recursive scan; `CodeRanges` as a list of those definitions | `PrimInt63` bounds in a `PArray.array` with binary search (fast `vm_compute`, extracts to native OCaml arrays) |
| Lean 4 | one `def` per property, `Array (UInt32 × UInt32)` literal; binary search | `List` literal converted with `.toArray`, or a single flat `Array UInt32` split into chunks (Lean is known to be slow on large literals) |
| Why3 | one `constant` per property, list of `(int, int)` pairs; membership as a recursive `let rec function` | for the C target (no WhyML arrays in the C fragment, per the report): a generated decision tree of bound comparisons per property |
| F\* | one top-level `list (U32.t & U32.t)` per property, for OCaml extraction; Pulse static global arrays (`Pulse.Lib.GlobalArray.mk_static_array`) for the KaRaMeL C target | `FStar.Seq` of bounds |

The name lookup in every tool is the stated equivalent of the issue: a
map from the 886 names, normalised as the generator's
`normalize_prop_name` does, to the 629 `CodeRanges` indices,
represented as an association list sorted by name.

## Approach

1. **Push the scripts** (workstation). Write `emit.py`, `fidelity.py`,
   `oracle.c`, `sample.py`, `run.sh`, `provenance.sh`, `setup.sh` and
   the hand-written per-tool parts; smoke-test `emit.py` and
   `fidelity.py` on the workstation (Python only, no prover); commit
   and push the branch. Fill `pins.json` with URLs and sha256.

2. **Toolchains** (bench host, about 60 min, in parallel, 32 jobs).
   `setup.sh`: check that `<cache>` and `<exp>` are under the home
   directory and that disk and load are as expected; download the opam
   binary and verify it; `opam init --bare --disable-sandboxing -n`
   with `OPAMROOT=<cache>/opam`; create switch `provers` with OCaml
   5.4.1; install `rocq-prover.9.3.0`, `rocq-native`, `why3.1.9.0`
   and `alt-ergo` at the version in `pins.json`; install F\* from the
   binary release (or, failing that, build `3.full` from the release
   source tarball, see Tools and versions) and smoke-test
   `#lang-pulse`; fetch Z3 5.3.0 (and any other version F\* names);
   check that the OCaml produced by `--codegen OCaml` on a small module
   compiles and links against `fstar.lib`, recording the exact command
   lines; clone and build KaRaMeL at the pinned commit against that
   F\*. In parallel: install elan into `<cache>/elan` and
   the Lean v4.36.0 toolchain. `setup.sh` is idempotent so later
   experiments reuse `<cache>`.

3. **C library** (in parallel with step 2, about 5 min). Clone the
   repository branch with `--recurse-submodules` into `<exp>/repo`,
   check `upstream/` is at `f95747b`, build it out of tree
   (`cmake -S <exp>/repo/upstream -B <exp>/build/onig
   -DCMAKE_BUILD_TYPE=Release`), run `test_utf8` as a sanity check.

4. **Emit the tables** (about 5 min). `emit.py` parses
   `upstream/src/unicode_property_data.c` directly (its format is
   regular: the array type `static const OnigCodePoint` on one line and
   `CR_X[] = { n,` on the next, then `0xA, 0xB,` lines, so the parser
   tolerates the split; the `CodeRanges[]` list with the 17 `#define`
   aliases; the gperf word list of 886 `{pool_offset(N), ctype}`
   entries, whose names are the `unicode_prop_name_pool_strN` fields of
   `unicode_prop_name_pool_contents`, joined by `N`) into an
   intermediate JSON, then writes one source per tool and
   representation, recording size and sha256 of each.

5. **Fidelity check** (about 10 min). `fidelity.py` checks 612 arrays,
   24,443 ranges, 629 `CodeRanges` entries and 886 names, and that every
   range count matches the array's leading count. Then the generator
   `upstream/src/make_unicode_property_data.py` is copied into
   `<exp>/gen/` with the nine UCD 16.0.0 files copied (or symlinked)
   flat into `<exp>/gen/` (from
   `https://www.unicode.org/Public/16.0.0/ucd/`, `GraphemeBreakProperty.txt`
   from its `auxiliary/` subdirectory and `emoji-data.txt` from its
   `emoji/` subdirectory; sha256 recorded) and run there; its
   `CR_*` arrays are compared with the upstream file. Agreement is
   evidence for the "check the generator output" path of the report's
   "Generated tables" item; any difference is recorded, not fixed.

6. **C oracle and sample** (about 5 min). `oracle.c`, linked against
   the out-of-tree build, maps each of the 886 names through
   `ONIGENC_PROPERTY_NAME_TO_CTYPE` (`upstream/src/oniguruma.h:287`) and
   answers the table question (is the code point in the `CR_*` table
   of that ctype?) with `onigenc_unicode_ctype_code_range`
   (`upstream/src/regenc.h:188`) followed by `onig_is_in_code_range`
   (`upstream/src/regenc.h:261`). It also records, beside each answer,
   the answer of `onigenc_unicode_is_code_ctype`
   (`upstream/src/regenc.h:186`), named in the issue. The two differ by
   design: for `ctype <= 14` and `code < 256`, `is_code_ctype` uses the
   ISO-8859-1 ctype table, which disagrees with the `CR_*` tables on 13
   code points (`CR_Cntrl`: U+00AD; `CR_Print`: U+0009-U+000D, U+0085;
   `CR_Word`: U+00B2, U+00B3, U+00B9, U+00BC-U+00BE). U+00B9 is in the
   sample, so comparing extracted tables against `is_code_ctype` would
   mark every target incorrect. The 13 differences are listed in the
   `fidelity` entry as a finding for the deviation log. `sample.py`
   builds the query set:
   for each of the 629 indices, every range endpoint and its neighbours
   (`lo-1, lo, hi, hi+1`, clipped to `[0, 0x10FFFF]`, deduplicated),
   about 98k queries, plus the 886 names. The oracle's table answers
   are the expected output for step 12.

7. **Check the table in each prover** (criteria 1 and 2). Clean build,
   `/usr/bin/time -v` (wall-clock and peak RSS), median of three runs
   (or a flagged single run, see Machine budget):
   - Rocq: `rocq compile` of the table file, then of the file using it;
   - Lean: `lake build -v` of the table module; `lake` does not
     report elaboration and C compilation separately, so the `lean`
     (elaboration and C emission) and `leanc` (C compilation)
     invocations it prints are re-run and timed individually, and the
     notebook says that this is the method used;
   - Why3: `why3 prove -L . --type-only` (parsing and typing), then
     `why3 prove -L .` without a prover to time VC generation;
   - F\*: `fstar.exe` verification of the table module, with the
     `--cache_checked_modules` cache cleared before each run.
   If the full table fails, the size at which it fails is found by
   bisection on the number of properties (at most four steps), and the
   error is recorded.

8. **Extract and compile** (criteria 2 and 5), per target, same timing
   method:
   - Rocq to OCaml (`Extraction` with `ExtrOcamlZBigInt` or native
     ints, recorded), compiled with `ocamlfind ocamlopt`;
   - Lean: `lake build` of a native executable (Lean's own C path);
   - Why3 to OCaml (`why3 extract -D ocaml64`) and to C
     (`why3 extract -D c`), compiled with `ocamlopt` and `gcc -O2`;
   - F\* to OCaml (`--codegen OCaml`, the Custard extraction path;
     legacy ML extraction is removed; compiled against `fstar.lib`),
     to C via KaRaMeL (`--codegen KrmlC`, then `krml`, compiled
     with `gcc -O2`), and to C via the direct backend (`--codegen C`,
     compiled with `gcc -O2`), KaRaMeL and direct C being two separate
     targets (Decision 4), with the command lines validated at setup.
   The size of each extracted source and binary is recorded. Compile
   steps that take the 24k-element nested `Cons` literals run under
   `ulimit -s unlimited`; a stack overflow is recorded as such, not as
   an extraction failure.

9. **In-prover membership queries** (criterion 3). The three fixed
   queries of the issue (U+0041 and U+00E9 against `Lu`, and a code
   point in the last range of `CR_Grapheme_Base`, U+31350..U+323AF:
   U+323AF, its upper bound, plus U+323B0, just past it), each timed
   separately: Rocq `Eval vm_compute` and `Eval native_compute`
   (`rocq-native` is installed in the switch so this figure is not
   missing by omission); Lean `#eval` (and `#reduce` once, to
   record whether the kernel can do it); Why3 `why3 execute`; F\*
   `assert_norm`. Each query is checked against the oracle.

10. **Provisional verdict inputs.** For each tool and target, the
    run records `T_table` = check time + extraction + compile time
    of the table, and peak RSS, so the relative cap of Decision 1 can
    be applied as soon as #6 gives `T_spec`.

11. **Sanity lemma** (criterion 4). Statement: in every `CR_*` array,
    ranges satisfy `lo <= hi` and `hi_i + 1 < lo_(i+1)` (sorted,
    disjoint, non-adjacent; the precondition of
    `onig_is_in_code_range`, `upstream/src/regcomp.c:7840`). Milestone 1
    proof by computation: a boolean checker proved equal to `true`
    with Rocq `vm_compute; reflexivity`, Lean `by decide` (and
    `native_decide`, recorded separately since it trusts the compiler),
    Why3 the `compute_in_goal` transformation, F\* `assert_norm`.
    The checker's soundness (boolean true implies the propositional
    statement) is proved once per tool on the generic definition,
    independent of the table. 30-minute check cap per tool; time or the
    blocking error is recorded. A non-computational proof is follow-up.

12. **Sample check** (criterion 5). Each extracted or compiled
    artefact reads the query set of step 6 from a file and prints its
    answers; `sample.py --compare` diffs them with the oracle. Every
    mismatch is listed; any mismatch marks that target incorrect.

13. **Fetch back** (about 10 min). `rsync` `<exp>/out/<run-id>/` to
    `<workdir>/e07/out/`, scan it for absolute paths, hostnames and
    addresses (redaction check), and copy the files that back a
    notebook entry into `lab/results/`.

14. **Report.** `summarise.py` builds the tool x target table (check,
    extract, compile times, peak RSS, artefact sizes, queries, lemma,
    sample), with the representation per tool. Commit the notebook
    entries from the local worktree, push, open the PR, and post the
    table with the provisional verdicts on issue #11.

## Provenance

`provenance.sh` records, per run: CPU model and kernel version of the
blocksci bench host, the CPU lists used for pinning, load average
before and after, versions of every tool in the table above (and the
KaRaMeL commit), compiler flags, the repository commit and the
`upstream/` commit, start time and duration. It does not record the
hostname, addresses, user names or absolute paths.

## Lab notebook

With the lab-notebook skill: `lab/notebook.md` (index, one line per
recorded run, linking to its file) and
`lab/results/<date>-exp-07-<topic>.md` (append-only), raw data in
`lab/results/<date>-exp-07-<topic>.csv` (or `.json`) beside it.
Planned entries:

1. `toolchains`: installed versions, KaRaMeL commit, setup time and
   disk use of `<cache>` (useful to #13 and #5).
2. `fidelity`: counts, generator-versus-file comparison, oracle build,
   and the 13 code points where `onigenc_unicode_is_code_ctype`
   disagrees with the `CR_*` tables (a finding for the deviation log).
3. `tables`: per tool and representation, criteria 1, 2 and 3
   (load success or failure size, timings, peak RSS, queries).
4. `extraction`: per target, criterion 2 extraction and compile
   timings and exact command lines, artefact sizes, and criterion 5 sample results.
5. `sanity-lemma`: per tool, criterion 4 outcome.
6. `verdicts`: the provisional per-tool verdicts (criterion 6) with
   the numbers they rest on and the open threshold from #6.

Exploratory and bisection runs are recorded only as part of the entry
they explain. The maintainer decides on any further entry, including
the one settling the verdicts after #6.

## Outputs

- `lab/07-large-tables/` (scripts, per-tool sources, pins).
- The lab notebook entries above, with raw data.
- Summary table and provisional verdicts posted on issue #11.
- A reusable toolchain cache `<cache>` on the bench host, documented
  in the `toolchains` entry.

## Done-criteria (from the issue)

For each of the four tools, recorded in the lab notebook:

1. The full table (all 612 range arrays and the name lookup, or a stated equivalent) is loaded, or the failure is documented with the error and the size at which it occurs. The stated equivalent of the name lookup is a map from the 886 names, normalised as the generator's `normalize_prop_name` does, to the 629 `CodeRanges` indices; the gperf hash is not ported.
2. Wall-clock time and peak memory to check the file, and, per extraction target, to extract and compile the result, on a stated machine. Method: clean build, `/usr/bin/time -v` for wall-clock and peak RSS, median of three runs; tool versions and CPU/RAM recorded in the notebook.
3. Fixed membership queries evaluated inside the prover, with wall-clock per query: U+0041 and U+00E9 against `Lu`, and a code point in the last range of `CR_Grapheme_Base`. Evaluator per tool: Rocq `Eval vm_compute` / `native_compute`, Lean `#eval`, Why3 `execute`, F\* `assert_norm` / compute.
4. One sanity lemma over the table (for example, ranges are sorted and disjoint): a bounded attempt (suggested: 2 h engineering and 30 min check time per tool), with time, and the blocking error if it does not go through.
5. Per extraction target, size of the extracted artefact, and whether the extracted code answers membership correctly on a sample checked against the C library. Sample: every range endpoint and its neighbours (lo-1, lo, hi, hi+1) for all 629 ctype indices (about 98k queries), compared with `onigenc_unicode_is_code_ctype` (`upstream/src/regenc.h:186`) from an out-of-tree C build, plus the 886 names via `ONIGENC_PROPERTY_NAME_TO_CTYPE` (`upstream/src/oniguruma.h:287`).
6. A one-line verdict per tool: table as in-prover definition, or as unverified runtime data, judged against the relative cap (see Decisions): the table's check-plus-extraction cost must not exceed the build time of the rest of the spec. Until experiment #6 reports that build time, the verdict is recorded as **provisional**, together with the raw numbers needed to settle it.

## Risks

- **Toolchain setup eats the budget.** Building F\* from source and
  KaRaMeL is the slowest part. Mitigation: 32 jobs; Lean and the C
  build proceed in parallel; the F\* binary release is tried first and
  a source build, if needed, is limited to `3.full`; if
  KaRaMeL does not build against the pinned F\*, the KaRaMeL C target
  becomes follow-up and is recorded as such.
- **A prover cannot load the full table in the time or memory cap.**
  That is a result (criterion 1), not a failure of the run: bisection
  gives the size reached, and the secondary representation is tried
  only if time remains.
- **Lean large literals.** Elaboration of large `Array` literals is a
  known slow path in Lean 4; the secondary representation is the
  mitigation.
- **Why3 C fragment.** Lists of pairs may not be accepted by
  `why3 extract -D c`; the generated decision tree is the fallback; if
  neither works within the budget, the failure is recorded for the C
  target.
- **Reflection proofs are slow on list representations.** The 30-minute
  cap bounds them; a structural proof is follow-up.
- **Shared host noise.** Other users share the bench host. Mitigation:
  pinning on separate L3 complexes, load check before each timed run,
  medians of three, load average recorded.
- **Verdict depends on #6.** By decision, the verdicts stay provisional
  until #6 reports; the numbers recorded here are sufficient to settle
  them without re-running, provided tool versions are compatible with
  #6's.
- **Old opam on the host (2.1.5).** A current opam binary in `<cache>`
  is used; the system one is not upgraded.
- **Leaking host details.** Raw outputs pass a redaction check before
  they are committed; the host is named only as the blocksci bench host.
