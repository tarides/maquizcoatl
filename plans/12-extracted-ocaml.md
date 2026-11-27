# Plan: experiment #12 follow-up, cost of Rocq- and F\*-extracted OCaml

Issue: [#22](https://github.com/tarides/maquizcoatl/issues/22) (the
issue body is the reference for scope, plan requirements, decisions and
done-criteria; this plan says how). Parent: experiment #12, issue
[#10](https://github.com/tarides/maquizcoatl/issues/10), merged as PR
#23 (`82b7ada`), plan `plans/12-ffi-vs-native.md`. Extracted code:
experiment #9, issue [#4](https://github.com/tarides/maquizcoatl/issues/4),
merged as PR #32 (`e1b9936`). Source: maintainer's state-of-the-art
report, "Deliverables: libonig drop-in and OCaml library" and
"Experiments before deciding", row of experiment #12
(https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

## Objective

Put two more columns in experiment #12's table: the backtracking VM
that experiment #9 proved, as OCaml extracted from **Rocq** and as
OCaml extracted from **total F\***. Both are measured with experiment
#12's harness, workloads, retry-budget rules, machine and pinning,
against freshly rerun baselines (C-only driver, `[@@noalloc]` stubs,
ctypes, hand-written OCaml VM), all on the workload calls inside
experiment #9's fragment (literals, concatenation, `|`, greedy `*`,
plain capture groups). The outcome restates experiment #12's
conclusion (FFI crossing cost against engine cost, per workload shape)
with the extracted columns, and says whether verified extraction
changes which way the evidence points on the report's open question
"OCaml library: native code or bindings?".

## Decisions folded in

From the issue's Decisions section (maintainer, 2026-11-27; binding):

1. **Scope: (a), retarget to experiment #9's extracted OCaml.** The
   Why3 and Pulse columns of the original scope are gone. Experiment
   #10 (issue #8) is not a dependency.
2. **Fragment membership of a workload call: (a), by construct.** A
   call is in the fragment when `select.py`'s `recognise` accepts its
   pattern, its encoding is UTF-8, its syntax is Oniguruma, Ruby or
   Perl_NG, and its options are in plan requirement 8's set (see
   Workloads).
3. **Catastrophic shape: (b).** No retry-budget measurement for the
   extracted columns, with the reason recorded. Every column runs
   `(a|aa)*b` and `(aa*)*b` on `"a"*n "!"`. At n = 16 the columns are
   compared on the time of a complete backtracking search; at n >= 32
   the extracted columns report the time to exhaust a stated fuel,
   labelled not comparable.
4. **Large-shape fallback: (a), pre-authorised.** If the pilot projects
   the large series over about 90 minutes, the extracted columns run at
   1 MiB only and the 16 MiB rows are recorded as not run.
5. **Switches: (a), `ffi` only** for the extracted columns. Flambda is
   a follow-up row if time remains in the run.

The issue review's fixes are the issue's "Plan requirements" 1-11;
each one is implemented below and mapped in the last table. Three
statements of the issue were checked while writing this plan and are
corrected here (none changes a decision):

- **Experiment #9's Rocq reference verdicts.** Requirement 6 (iii)
  names `lab/results/2026-11-25-exp-09-raw/rocq/fragment.verdicts.txt`.
  That file is run 1's and covers 50 of the 66 fragment cases. The
  66-case file is correction 1's,
  `lab/results/2026-11-25-exp-09-correction-1-raw/rocq/fragment.verdicts.txt`
  (1,017 lines; run 4's rerun is byte-identical to it, entry
  `2026-11-25-exp-09-rocq-m2.md`). Its `vm` lines are identical to
  F\*'s `lab/results/2026-11-25-exp-09-fstar-m1-raw/fstar/fragment.verdicts.txt`
  (checked with `cmp`). The extra probes' references are
  `lab/results/2026-11-25-exp-09-raw/rocq/extra.verdicts.txt` and
  `lab/results/2026-11-25-exp-09-fstar-m1-raw/fstar/extra.verdicts.txt`.
- **Why `frag.ml` and `Custard.ml` are not in the repository.**
  `rocq/rocq.sh` and `fstar/fstar.sh` write them into the bench host's
  build directory, not into the source tree; the `.gitignore` of
  `lab/09-representative-proof/` does not name them. Requirement 2's
  consequence (regenerate from `e1b9936`) is unchanged.
- **Large-shape pattern count.** The fragment keeps 14 of experiment
  #12's 16 log-source patterns (`\=` and `\s*(\[)` are out) but 15 of
  the 16 source-file patterns: the source list has no `\s*(\[)`
  (it ranks `<=|>=|<>|<|>` 16th instead), so only `\=` is out. Checked
  by running `recognise` on `lab/results/2026-11-19-exp-12-raw/work/large.list`.

One finding of this plan's checks bears on decision 3 and is handled
without changing it (see Catastrophic patterns): Oniguruma's search
optimiser rejects both new patterns before any backtracking.

`plans/12-ffi-vs-native.md:28-37` and `:109-116`, and the `reason`
field of `lab/12-ffi-vs-native/pins.json`, predate decision 1 and are
not carried over.

## Where things live

- **Bench host.** No root, nothing installed system-wide.
  - `<bench-workdir>/cache/` (written `<cache>`): the shared toolchain
    cache (opam 2.6.1 at `<cache>/bin/opam`, `OPAMROOT` `<cache>/opam`,
    `<cache>/env.sh`). Its default switch (`compcert`) is never
    changed, the opam root is never upgraded, no `opam update` is run;
    every command goes through `opam exec --switch <name> --`. Switch
    `provers` is used unchanged (extraction). Switch `ffi` receives the
    F\* column's packages (Tools); `ffi-flambda` is not touched.
  - `<bench-workdir>/exp/12-extracted-ocaml/` (written `<exp>`): a
    clone of this branch with `upstream/` at `f95747b` (`<exp>/repo/`,
    `upstream/` read only); out-of-tree C builds `<exp>/build/onig-release/`,
    `onig-noopt/` (`-DONIG_DONT_OPTIMIZE`) and `onig-dbgc/`
    (`-DONIG_DEBUG_COMPILE`, never timed); the extraction directories
    `<exp>/extract/{rocq,fstar}/`; the generated sources
    `<exp>/gen/{rocq,fstar}/`; the dune staging tree `<exp>/src/`;
    binaries `<exp>/bin/`; subjects `<exp>/subjects/`; raw outputs
    `<exp>/out/<run-id>/`.
  - Experiment #12's directory `<bench-workdir>/exp/12-ffi-vs-native/`
    is read only: its large subjects are copied from there (sha256
    checked against `lab/results/2026-11-19-exp-12-raw/subjects-manifest.txt`).
- **Workstation.** `<workdir>` is the work directory outside the
  repository; this branch's worktree is `<workdir>/wt/12-extracted-ocaml`.
  Development and untimed unit tests of the adapters, the parser port
  and the scripts happen here. No Rocq or F\* toolchain is installed on
  the workstation: the adapters are compiled during development against
  copies of experiment #9's extracted files, fetched read only from the
  bench host's experiment #9 build directory (Rocq run 4, F\* run 2), in
  a local OCaml 5.4.1 switch with the pinned packages. Those copies are
  never timed and never committed. Raw outputs are copied back to
  `<workdir>/e12x/out/` before selection.
- **Repository** (branch `exp/12-extracted-ocaml`), requirement 10:
  - `lab/22-extracted-ocaml/` (new):
    - `extract.sh`: regenerates the extracted sources from `e1b9936`
      (step 4) and prints their sha256;
    - `gen/rocq/dune`, `gen/fstar/dune`: the dune stanzas copied beside
      the generated sources (libraries `rocq_extracted`, module `Frag`;
      `fstar_extracted`, modules `Prims` and `Custard`, with the
      packages and preprocessors of `fstar/fstar.sh:23`, `:36`);
    - `adapter/`: library `extracted22` (marked `optional`): `frag_parse.ml`
      (OCaml port of `recognise`), `rocq22.ml`, `fstar22.ml` (the
      engines, Engines below), `extracted22.ml` (exports `Rocq`,
      `Rocq_scan`, `Fstar`, `Fstar_scan`);
    - `x22/`: executable `x22.exe` for the checks and measurements
      that experiment #12's harness has no subcommand for: `astcheck`,
      `astwork`, `verdicts`, `conv`, `conv-subject`, `cata-fuel`
      (Approach);
    - `prep22.py` (fragment selection and coverage), `run22.py`
      (pilot and series, built on `run.py`), `summarise22.py`,
      `setup.sh`, `provenance.sh`, `pins.json`, `README.md`.
  - `lab/12-ffi-vs-native/`, registration only: four cases in
    `engine_of` (`bench/main.ml:98-102`), four entries in `run.py`'s
    `ENGINES` (`run.py:28-37`). Linking them needs two things more,
    which are part of the registration: `bench/dune` lists `extracted22`
    in a dune `select` whose fallback is a new one-module file
    `bench/extracted.none.ml` (four stand-in engines answering `Error 1`,
    "unsupported by this engine"), so that `lab/12-ffi-vs-native/`
    still builds on its own and experiment #12's replay
    (`lab/12-ffi-vs-native/README.md`) is unchanged; and `run.py`
    removes the four new names from its default engine set, as it does
    for `c-noopt` (`run.py:38-43`), so a replay of run `r1` runs the
    same cells as before.
  - `lab/09-representative-proof/` is untouched.
  - `lab/notebook.md` and `lab/results/`: the notebook (Lab notebook).

The dune build root on the bench host is the staging tree `<exp>/src/`:
`setup.sh engines` copies `lab/12-ffi-vs-native/`, `lab/22-extracted-ocaml/`
and `<exp>/gen/` into it and writes a `dune-workspace` file, so lab/12's
`bench` executable sees the `extracted22` library. Scripts take
`<cache>` and `<exp>` from environment variables and never print
absolute paths, host names or addresses.

## Tools and versions

All actively maintained. Checked read only on the bench host on
2026-11-27; `pins.json` records them and `provenance.sh` re-records the
versions actually used.

| Tool | Version | Role |
|------|---------|------|
| opam | 2.6.1 (`<cache>/bin/opam`) | switches, no `opam update` |
| OCaml | 5.4.1, switch `ffi` (`ocaml-base-compiler.5.4.1`, no flambda) | every timed OCaml column |
| dune | 3.25.0 (in `ffi`) | builds, `--profile release` as experiment #12 |
| ctypes, ctypes-foreign | 0.24.0 (in `ffi`) | ctypes column |
| mtime | 2.2.0 (in `ffi`) | harness clock |
| zarith, yojson, ppx_deriving, ppx_deriving_yojson | 1.14, 3.0.0, 6.2.0, 3.10.0: the versions of switch `provers`, which built experiment #9's F\* driver; installed into `ffi` (requirement 7) | F\* column (`Prims.ml`, `Z.t`) |
| their dependencies | conf-gmp 5, cppo 1.8.0, ocaml-compiler-libs v0.17.0, ppx_derivers 1.2.1, ppxlib 0.39.0, sexplib0 v0.17.0 (opam's `--dry-run` solution against the cache's current repository state: 10 installs, no upgrade or removal) | |
| Rocq | rocq-core 9.3.0, rocq-stdlib 9.2.0, switch `provers` (OCaml 5.4.1) | extraction (`Extract.v`: `ExtrOcamlBasic`, `ExtrOcamlNatInt`) |
| F\* | 2026.11.15 binary release, commit `b92b0f87`, `--z3version 5.3.0` | extraction (`--codegen OCaml`, the nine `--custard_entry` names of `fstar/fstar.sh:24`) |
| F\* `Prims.ml` | from the release (`<cache>/fstar/lib/fstar/lib/app/Prims.ml`), sha256 `e5b8a7e7...220aa8` | compiled into the F\* column; the release's `fstar.lib` (OCaml 5.3.0) is not linked |
| GCC, CMake | 13.3.0, 3.28.3 (system) | libonig builds, C driver |
| Python | 3.12 (system, stdlib, `-I`) | scripts |

Experiment #12's ffi switch had dune, ctypes, ctypes-foreign, re,
mtime and conf-libffi; `opam install --dry-run` on 2026-11-27 showed
that the four F\* packages add 10 packages and change none.
`setup.sh switch` exports `ffi` before and after the install
(`opam switch export`) and records both files, so experiment #12's
state stays reconstructible. If opam's solution at run time differs
from the one above, the installed versions are recorded and the run
continues only if the four named packages are at the pinned versions.

## Workloads: the fragment subset (decision 2, requirement 8)

Inputs are experiment #1's workload files on `main`
(`experiments/01-pattern-inventory/workloads/data/`), turned into work
files by experiment #12's `prep.py`, unchanged. `prep22.py` reads
`<fam>.all.work` and keeps a call when:

- its pattern entry has syntax 0, 1 or 2 (Oniguruma, Ruby, Perl_NG;
  `prep.py` gives non-UTF-8 calls syntax 8, so this also enforces
  UTF-8);
- its options are within MULTILINE (4), SINGLELINE (8),
  NEGATE_SINGLELINE (64), CAPTURE_GROUP (256), IGNORECASE_IS_ASCII
  (32768), WORD_IS_ASCII (65536), DIGIT_IS_ASCII (131072),
  SPACE_IS_ASCII (262144), POSIX_IS_ASCII (524288)
  (`upstream/src/oniguruma.h:375-404`; the issue's
  "NEGATE_SINGLE_LINE" is `ONIG_OPTION_NEGATE_SINGLELINE`), and its
  search options within NOTBOL (512) and NOTEOL (1024);
- `recognise` from `lab/09-representative-proof/cases/select.py`,
  imported unchanged, accepts the pattern bytes (it rejects `\=`, `}`
  and `]`, which Oniguruma reads as literals; the coverage table
  counts these rejections under their own reasons);
- it is a forward call (`range >= start`, or a match call). This rule
  excludes two PHP search calls with an empty pattern and `range <
  start`: case 7 (`start` 1, `range` 0, empty subject) and case 159
  (`start` 11, `range` 10, 10-byte subject); the coverage table counts
  them under their own reason.

`prep22.py` writes `<fam>.frag.work` (same format), `<fam>.ast.tsv`
(pattern id and `recognise`'s s-expression) and the coverage table:
per family, calls, VS Code calls weighted by the frequency profile,
and distinct pattern entries admitted out of the total, with the
rejection reasons. It also checks that every admitted call is in
experiment #12's subset (`<fam>.work`, written by experiment #12's
classifier); the review found none outside it, and a call outside it
stops the run.

Expected counts, recomputed on the workstation with `prep.py` and
`recognise` on 2026-11-27, with the four rules above (a difference at
run time is reported, not corrected; the issue's 65 PHP calls include
the two backward calls that the forward-call rule excludes):

| Family | Calls admitted | Weighted (VS Code) | Pattern entries |
|--------|---------------:|-------------------:|----------------:|
| jq | 91 / 217 (41.9%) | | 10 / 44 |
| PHP | 63 / 421 (15.0%) | | 21 / 187 |
| VS Code (expanded searches) | 77,067 / 429,020 (18.0%) | 127,660 / 759,850 (16.8%) | 277 / 4,221 |
| long-subject PHP (synthetic row) | 10 / 18 | | 1 / 5 |

Escapes in the admitted patterns: none under Perl_NG (jq); `\?` and
`\\` under Ruby (PHP); escaped metacharacters and `\&`, `\-`, `\/`,
`\<`, `\>` under Oniguruma (VS Code). The three syntaxes read these as
literals (`\<`, `\>`: `ONIG_SYN_OP_ESC_LTGT_WORD_BEGIN_END` is cleared,
`upstream/src/regparse.c:71-77`, `:123-129`,
`upstream/src/regsyntax.c:208-214`); step 7's agreement with C checks
it on every call.

- **Short subjects.** Experiment #12's families jq, PHP, VS Code
  (scanner searches expanded per member triple, repeated by the
  frequency profile's `count`) and the long-subject PHP row,
  restricted to the fragment.
- **Large subjects.** Experiment #12's subjects (log and source files,
  1 MiB and 16 MiB) and its ranked pattern list, restricted to the
  fragment: 14 log patterns and 15 source patterns (rank and pattern
  id kept, no new ranking). `prep22.py` writes the restricted
  `large.list`.
- **Catastrophic patterns** (decision 3): `(a|aa)*b` (label
  `php-frag`, Ruby, options 12, the shape of PHP's `(a|aa)+$`) and
  `(aa*)*b` (label `jq-frag`, Perl_NG, options 256, the shape of jq's
  `(a+)+$`), on `"a"*n "!"` for n = 16, 32, ..., 4096. Both are in the
  fragment (`recognise`: `(. (* (g 1 (| L61 (. L61 L61)))) L62)` and
  `(. (* (g 1 (. L61 (* L61)))) L62)`). Experiment #12's three
  catastrophic patterns are outside the fragment and are not rerun.

## Engines

Every timed column goes through experiment #12's harness
(`lab/12-ffi-vs-native/bench/main.ml`) and its `ENGINE` signature.

- **Baselines** (requirement 1): C driver (`cdriver`), stubs, ctypes,
  hand-written VM, all built from this branch in `ffi` against
  `<exp>/build/onig-release/libonig.so`, Release flags as experiment
  #12. Experiment #12's short-shape figures are per family pass, so no
  fragment-subset figure can be derived from them: every baseline is
  rerun on the fragment subset, in the same interleaved series as the
  extracted columns. The `ffi-flambda` VM and `ocaml-re` columns are
  not rerun; experiment #12's full-subset figures stay in the table as
  context, labelled as such.
- **Extracted columns**, two engines (Rocq, F\*), each registered in
  two subject modes (requirement 4), hence four names:
  - `rocq`, `fstar` (short shape except long PHP, agreement,
    catastrophic): on each `search` or `match_` call the subject suffix
    from `start` is converted to the extracted representation inside
    the call (the fragment has no look-behind and no anchor, so a call
    never reads before `start`);
  - `rocq-scan`, `fstar-scan` (large shape, and the long-PHP row, which
    is the large shape's labelled synthetic row:
    `plans/12-ffi-vs-native.md`, "Large subjects"; `run.py:183-184`):
    each subject is converted once, on the first call with that subject
    string, which is in the untimed warm-up (the warm-up scan of `scan`,
    the warm-up pass of `time`). The adapter keeps a cache holding every
    subject of the work file, keyed by physical equality (the long-PHP
    work file has one subject; each large `scan` process has one), and
    per subject a cursor on the suffix at the last start position: a
    later start moves it forward, a start before the cursor restarts it
    from the head. The long-PHP row needs this: its 10 admitted calls
    are pattern `a` at `start` 0..4 (4 twice), `range` 2,097,152, on the
    one 2 MiB subject, each matching at its first position, so a
    per-call conversion (about 2 million list cells) would outweigh the
    engine's one `IStr` per call by orders of magnitude.

  Representation: `int list` for Rocq (`ExtrOcamlNatInt`), `Z.t list`
  for F\* (`fstar/main.ml:85`), one element per byte.
- **Position loop** (requirement 3). The adapter never calls the
  extracted `search` and never passes an absolute position: at each
  start position p from `start` to `min range n`, one byte at a time
  (the meaning of `search_from`, `rocq/Syntax.v:69-79`), it calls
  `vm fuel code ncap suffix_p 0` and adds p back to the match end and
  every capture bound. It stops at the first result that is not
  `NoMatch`, as `search_from` does. Calling the extracted search
  instead would cost O(n²) `skipn` steps (`rocq/Vm.v:73-75`): about
  5·10¹¹ at 1 MiB, past experiment #12's 120 s timeout. One-byte steps
  give the same results as Oniguruma's one-character steps here: a
  nullable pattern matches at the first position tried, and a
  non-nullable one needs an ASCII byte, which never occurs inside a
  UTF-8 multibyte character. `match_` is one `vm` call at `at`.
  Backward calls are outside the subset (Workloads). The notebook says
  that this loop is harness code with the meaning of `search_from`
  (`FRAGMENT.md` section 7: the search is the same function of the
  per-position results).
- **Parser** (requirement 6). `frag_parse.ml` ports `recognise` to
  OCaml, unverified, and runs in `compile`, outside every timed region.
  Its AST is mapped to `Frag.regex` (Rocq) or `Custard.syntax_regex`
  (F\*), then compiled with the extracted `compile`.
- **Fuel, limits, results** (requirement 5). Fuel is `max_int` (Rocq)
  and `Z.of_int max_int` (F\*) in every harness call; the `limit` and
  `stack_limit` of `ENGINE.compile` are ignored. `OutOfFuel` maps to
  code -2000 (below every `ONIGERR_*` code, the lowest being -500,
  `ONIGERR_LIBRARY_IS_NOT_INITIALIZED`, `upstream/src/oniguruma.h:654`), shown as `fuel`, and counts as a
  disagreement. The 63 in-fragment PHP calls carry `retry_limit_in_match`
  1,000,000 and `match_stack_limit` 100,000; the extracted columns do
  not apply them, and the agreement entry says so.

## Approach

1. **Code** (workstation, before the run). Write `lab/22-extracted-ocaml/`
   and the registration in `lab/12-ffi-vs-native/`. Untimed checks on
   the workstation: the adapters build against experiment #9's
   extracted copies; check (i) of step 6 passes; `dune build --root
   lab/12-ffi-vs-native` still builds on its own (fallback of the
   `select`); `prep22.py` reproduces the counts above. Commit and push.

2. **Setup** (bench host, build CPU set). `setup.sh clone`: clone this
   branch with `--recurse-submodules` into `<exp>/repo`, check
   `upstream/` is at `f95747b`. `setup.sh switch`: export `ffi`,
   install the four packages at the pinned versions with `--jobs=4`,
   export again. `setup.sh cbuild`: libonig Release, Release with
   `-DONIG_DONT_OPTIMIZE`, Debug with `-DONIG_DEBUG_COMPILE` (library
   only), out of tree, as experiment #12's `setup.sh cbuild` and
   `cbuild-noopt`; `test_utf8` of the Release build as a sanity check
   (1,554 cases). `setup.sh subjects`: copy the four large subjects from
   experiment #12's directory, check their sha256 against experiment
   #12's manifest.

3. **Source check.** `extract.sh` first checks that the clone's
   `lab/09-representative-proof/{rocq,fstar}/`, `lab/06-spec-speed/rocq/Spec2.v`
   and `lab/06-spec-speed/fstar/Spec2.fst` are identical to `e1b9936`
   (`git diff --quiet e1b9936 HEAD -- ...`; true on `main` at
   `f582937`), and stops otherwise.

4. **Regenerate the extracted sources** (requirement 2; untimed, build
   CPU set, switch `provers`). Rocq, the steps of `rocq/rocq.sh:23` and
   `:31`: copy the `.v` files into `<exp>/extract/rocq/`, `TablesStub.v`
   as `Tables.v`, then `rocq compile -R . S` on `Syntax`, `Sem`,
   `Compile`, `Vm`, `Extract` (the files `Extract.v` imports). F\*, the
   steps of `fstar/fstar.sh:21-24`, `:28`, `:31-35`: the `.fst` files and
   experiment #6's `Spec2.fst` into `<exp>/extract/fstar/`, `TablesStub.fst`
   as `Tables.fst`, check `Syntax Sem Compile Vm Statement Tables Spec2
   Extract` with `fstar.exe --cache_checked_modules --cache_dir cache
   --z3version 5.3.0`, extract with `--codegen OCaml` and the nine
   `--custard_entry` names, copy the release's `Prims.ml`. Record
   `rocq --version`, `fstar.exe --version`, the exact commands and the
   sha256 of `frag.ml`, `frag.mli`, `Custard.ml` and `Prims.ml`. For
   reference, the copies in experiment #9's build directory hash to
   `e76cf6f5...bc27c6f` (`frag.ml`, Rocq run 4), `0fd45240...91f1458e`
   (`frag.mli`), `ae703add...95f238` (`Custard.ml`, F\* run 2) and
   `e5b8a7e7...220aa8` (`Prims.ml`); a difference is recorded with the
   reason found (run 2 predates F\*'s M2 runs), not treated as an
   error, since `e1b9936` is the reference. Copy the four files and the
   committed `gen/*/dune` into `<exp>/gen/`.

5. **Build the engines** (build CPU set). `setup.sh engines`: staging
   tree, `dune build -j 4 --profile release` in `ffi` (the only switch
   built), copy `main.exe` to `<exp>/bin/main-ffi.exe` and `x22.exe`;
   `cdriver` and `cdriver-noopt` with `gcc -O2` against `onig-release`
   and `onig-noopt`. Record the effective `ocamlopt` flags of the
   extracted libraries (same profile as the hand-written VM; generated
   code warnings disabled, nothing else).

6. **Checks before any timing** (requirement 6; untimed). (i)
   `x22.exe astcheck` on `cases/fragment.tsv` and `cases/extra.tsv`:
   the port's AST equals column 10 on all 66 + 4 cases. (ii)
   `x22.exe astwork` on each `<fam>.frag.work`: the port's s-expression
   equals `prep22.py`'s in `<fam>.ast.tsv` for every admitted pattern.
   (iii) `x22.exe verdicts rocq|fstar` on the same case files, through
   the adapters' `search` and `match_` (the engine modules the harness
   uses): its per-position and search lines, in experiment #9's
   format, equal the `vm` lines of the reference files named under
   Decisions folded in. This validates the parser, the position loop
   and the conversion. Any failure stops the run before step 9; it is
   fixed and the checks rerun, or, if the fix does not fit, the run
   records what failed and the timing moves to a second run.

7. **Agreement** (issue #10's criterion 7, both columns). Experiment
   #12's `agree` subcommand for `c`, `stubs`, `ctypes`, `vm`, `rocq`,
   `fstar` on every `<fam>.frag.work`, 4 jobs on the build CPU set. C
   is the reference; every difference of another column is listed with
   pattern, subject offset and both answers. `<fam>.agreed.work` keeps
   the calls on which C returns neither -15
   (`ONIGERR_MATCH_STACK_LIMIT_OVER`), -17 nor -18 (retry limits) and
   every other column agrees with C (experiment #12's rule, extended to
   the new columns); the excluded calls are counted. The exclusion for
   a C limit code is expected to be empty: experiment #12's three
   limit-code calls (`A(B|C+)+D|AC+X`, retry limit; `\s+$` twice, stack
   limit; `lab/results/2026-11-19-exp-12-agreement.md`) are outside the
   fragment, and every in-fragment PHP call completed under its
   1,000,000-retry limit in experiment #12. So the extracted columns,
   with fuel `max_int`, face no call on which C gave up (the `agree`
   jobs have no `timeout`, `run.py:69-72`). The C driver's
   spans are compared with experiment #1's `expected` for jq, PHP and
   long PHP, and for VS Code on the scanner searches that have at least
   one member and whose members are all in the fragment (requirement
   11: 215 of 11,263, recomputed and reported as such, not over the
   family). `summarise22.py` keeps experiment #12's rule from
   `summarise.py`'s `agreement`: the 12 searches on the 5 member-less
   scanners of `vscode.scanners.jsonl` are skipped (the issue review's
   227 counted them vacuously).

8. **Conversion cost** (requirement 4; untimed series, CPU 2). `x22.exe
   conv rocq|fstar` on each `<fam>.agreed.work`: the short shape's
   per-call conversion alone, same passes and protocol as `time`,
   reported as ns per call and ns per byte, minor and major words per
   call. For the large shape, `scan`'s output already separates it:
   the conversion happens in the warm-up; `x22.exe conv-subject` times
   it once per subject (ns per byte, words) and records `Gc.get ()`
   (default settings, `OCAMLRUNPARAM` unset) and the heap size after
   conversion (about 400 MB at 16 MiB).

9. **Pilot** (CPU 2). One untimed run of every cell of steps 10-12,
   with one exception for the extracted columns' 16 MiB cells: their
   1 MiB cells run first, and each 16 MiB cell is projected as 16 × its
   1 MiB time. A 16 MiB extracted cell runs in the pilot only when the
   projection keeps the large series under 90 minutes and the cell
   under the 120 s timeout; otherwise decision 4 is applied from the
   projection. Without this order the pilot has no upper bound (a
   `scan` process does two scans; at 0.5 MB/s the F\* 16 MiB cells
   alone take about 32 minutes). The pilot projects each series as
   10 × its pilot wall time (+10% for IQR repeats). If the large
   series projects over 90 minutes, decision 4 applies: the extracted
   columns run at 1 MiB only and their 16 MiB rows are recorded as not
   run. If the whole run still projects over
   its 4 hours, experiment #12's reduction rule applies to the large
   series (patterns removed from the bottom of the ranking, never the
   10 runs), and the reduction is recorded. Any cell that times out in
   the pilot is recorded with its timeout.

10. **Short-subject series** (issue #10 criterion 2). Columns `c`,
    `stubs`, `ctypes`, `vm`, `rocq`, `fstar` (`rocq-scan`, `fstar-scan`
    on the long-PHP row, Engines); families jq, PHP, VS Code, long PHP;
    `<fam>.agreed.work`. Experiment #12's protocol
    unchanged: one process per cell under `taskset -c 2`, `timeout 120`,
    one untimed warm-up pass, passes repeated for at least 0.5 s;
    time per call, minor and major words per call; 10 runs, interleaved
    with the order shuffled by seed r; min, median and IQR; a cell
    whose IQR exceeds 10% of its median is repeated once with 10 more
    runs, then reported as noisy if it still does.

11. **Large-subject series.** Columns `c`, `stubs`, `ctypes`, `vm`,
    `rocq-scan`, `fstar-scan`; 29 patterns (14 log, 15 source) × 1 MiB
    and 16 MiB (extracted columns at 1 MiB only under decision 4);
    experiment #12's `scan` find-all loop, warm-up scan untimed, 10
    interleaved runs, `timeout 120`; throughput in bytes per second per
    (source, size, pattern) and the median over patterns, words per
    match. A timed-out cell is recorded as such.

12. **Catastrophic patterns** (decision 3). `run22.py cata` sets
    `run.py`'s `CATA` to the two patterns above (in `run22.py`, so
    experiment #12's own `CATA` and its replay are unchanged) and runs
    experiment #12's `cata` subcommand, `timeout 60`, 10 interleaved
    runs, retry limit 10,000,000 (`run.py`'s `CATA_LIMIT`), outcome and
    time per point, rows stopped at the first length where every run
    is `cap`:
    - columns `c`, `c-noopt`, `stubs`, `ctypes`, `vm` at every length;
      `rocq`, `fstar` at n = 16 (fuel `max_int`). At n = 16 the
      columns are compared on the time of a complete search, and their
      outcomes must agree (`MISMATCH`).
    - `rocq`, `fstar` at n >= 32 through `x22.exe cata-fuel` with a
      stated fuel of 10,000,000 instructions per start position: the
      time until `OutOfFuel`, labelled "not comparable" (fuel counts
      instructions, the C budget counts backtracks).
    - The optimiser finding: on a local `f95747b` build (workstation,
      2026-11-27), the default library's optimiser picks `STR_FAST` on
      the required literal `b` (dmin 0, dmax infinite) and returns
      `MISMATCH` in about 2 µs at every n, without backtracking; with
      `-DONIG_DONT_OPTIMIZE` it backtracks (n = 16: 0.17 ms and
      1.2 ms; `(a|aa)*b` completes at n = 32 and hits -17 at 64;
      `(aa*)*b` hits -17 from 32). So `c`, `stubs` and `ctypes` measure
      the optimiser's rejection, not a backtracking search, and the C
      backtracking figure that decision 3's comparison needs is
      `c-noopt`'s, experiment #12's review-fix column (the same driver
      on the `ONIG_DONT_OPTIMIZE` build). Both are reported, with the
      optimiser's choice for each pattern read from the `onig-dbgc`
      build. The hand-written and extracted VMs have no optimiser.

13. **Fetch back** (workstation). `rsync` `<exp>/out/<run-id>/` to
    `<workdir>/e12x/out/`, scan for absolute paths, host names and
    addresses, copy the files that back a notebook entry into
    `lab/results/`.

14. **Report.** `summarise22.py` builds the tables: per shape and
    family, every column's median and spread on the fragment subset,
    experiment #12's full-subset figures beside them as context;
    extraction cost (extracted VM minus hand-written VM, both net and
    gross of conversion on the short shape); engine cost (each VM
    minus C driver) and FFI crossing cost (stubs or ctypes minus C
    driver) on the same subset; the coverage of each workload. Then the
    conclusion (done-criterion 2), which names the representation costs
    as findings, not defects: `Z.t` arithmetic throughout the F\*
    column, captures as an association list (`rocq/Vm.v:17-23`), one
    `IStr` per byte (the fragment's literals are single bytes), no
    search optimiser. Commit, push, update the draft PR, post the
    summary on issue #22.

## Runs (launched one by one by the maintainer)

One run, at most 4 hours of wall clock on the bench host, ending with
the notebook entries and a push. Nothing starts automatically.

| Run | Content | Done when |
|-----|---------|-----------|
| 1 | Steps 2-14 | every entry recorded, or step 6 failed (then: what failed is recorded and run 2 is needed) |
| 2 (only if needed) | Steps 6-14 after a fix | as run 1 |

## Machine budget

- **CPU sets** (experiment #12's pinning, unchanged). Every job, builds
  included, under `taskset -c 0-3,32-35`, at most 4 parallel jobs
  (`--jobs=4`, `make -j4`, `dune build -j 4`). Timed processes under
  `taskset -c 2`, one at a time, with nothing else of this experiment
  running. Load average and the CPU 2 governor (`schedutil`) are logged
  before and after each series and run (`run.py`'s `conditions.csv`);
  a series started with a 1-minute load average above 16 is flagged.
  The experiment #12 time limits apply: `timeout 120` per short and
  large process, `timeout 60` per catastrophic point.
- **Disk.** 41 GB free on the bench work directory on 2026-11-27;
  floor 20 GB: stop and report below it. This run needs about 1 GB
  (clone, three C builds, packages, staging and dune builds, subjects
  34 MB, outputs). Memory: one 16 MiB subject converted is about 400 MB
  of list cells per process (503 GB RAM).
- **Schedule** (wall clock, bench host):

| Phase | Steps | Time |
|-------|-------|------|
| Setup: clone, packages into `ffi`, three C builds, subjects | 2 | 25 min |
| Source check, extraction, hashes, engines build | 3-5 | 15 min |
| Checks, agreement, conversion cost | 6-8 | 20 min |
| Pilot | 9 | 15 min |
| Short-subject series | 10 | 10 min |
| Large-subject series | 11 | at most 90 min (about 25 min under decision 4's fallback) |
| Catastrophic patterns | 12 | 15 min |
| Fetch, redaction check, record, push | 13-14 | 30 min |
| Total | | 3 h 40 min at most |

Estimates: experiment #12's baselines took about 2.3 s per column per
short run and 4-29 s per column per large run (64 cells); the
baselines on the subset cost about 15 minutes in all. The extracted
columns dominate the large series: every instruction allocates a state
record, a stack cell and a captures cell, and F\* adds `Z.t`
arithmetic, so the review's estimate of 5-30 MB/s (Rocq) and a few
MB/s (F\*) puts them at 1-3 hours over both sizes; the pilot decides.
The engineering (step 1) is done before the run and is not counted.
If time remains after step 12, the flambda row of decision 5 is added
(the extracted columns built in `ffi-flambda`, short shape first),
which requires the four packages in `ffi-flambda` and is recorded as
its own entry; otherwise it stays a follow-up.

## Provenance

`provenance.sh` (experiment #12's, extended) records: upstream commit
`f95747b`; repository commit; experiment #9's commit `e1b9936` and the
source check of step 3; Rocq and F\* versions (`rocq --version`,
`fstar.exe --version` with its commit), the extraction commands and
flags (`ExtrOcamlBasic`, `ExtrOcamlNatInt`; `--codegen OCaml`, the
`--custard_entry` list, `--z3version 5.3.0`); the sha256 of `frag.ml`,
`frag.mli`, `Custard.ml` and `Prims.ml`; OCaml version and `ocamlopt
-config` lines of `ffi`; every package version of `ffi` (the two
switch exports); ctypes, libffi, dune, mtime versions; CMake build
types and effective C flags of the three builds; GCC and CMake
versions; CPU model, RAM, kernel, OS; timing CPU 2, build CPUs
0-3,32-35, CPU 2 governor; GC settings; load averages; the other
experiments running (by number); start time and duration. It records
no host name, address, user name or absolute path.

## Lab notebook

With the lab-notebook skill. Rows are appended to the "Experiment #12"
table of `lab/notebook.md`, with "follow-up (issue #22)" in the
Experiment column; results files are
`lab/results/<date>-exp-12-followup-<topic>.md`, raw data in
`lab/results/<date>-exp-12-followup-raw/`. Planned entries:

1. `provenance`: versions, packages installed into `ffi`, extraction
   commands and the four sha256, the source check, coverage of each
   workload by the fragment, the restricted large pattern list.
2. `checks`: requirement 6's checks (i)-(iii), the conversion rules of
   requirement 4 and their measured cost, the position-loop statement
   of requirement 3, fuel and the limits not applied (requirement 5).
3. `agreement`: issue #10's criterion 7 for both columns, the excluded
   calls (none expected for a C limit code: experiment #12's three
   limit-code calls are outside the fragment, so the fuel-`max_int`
   extracted columns face no call on which C gave up), the
   expected-span check on the 215 scanner searches.
4. `short`: time per call and words per call, every column on the
   fragment subset, experiment #12's figures as context.
5. `large`: throughput and words per match, the fallback if applied.
6. `catastrophic`: decision 3's figures, the reason there is no
   retry-budget measurement for the extracted columns, and the
   optimiser finding.
7. `conclusion`: done-criterion 2.

Pilot runs and repeated noisy cells are recorded only inside the entry
they explain. Deterministic re-runs are not recorded twice. The
maintainer decides on any further entry.

## Outputs

- `lab/22-extracted-ocaml/` and the registration in
  `lab/12-ffi-vs-native/`.
- The notebook entries above with raw CSV.
- The summary and conclusion posted on issue #22, in a draft PR.

## Done-criteria and requirements

| Item | Where |
|------|-------|
| Done-criterion 1: the measurements for the Rocq- and F\*-extracted OCaml with provenance, or a recorded reason | steps 7-12, entries 1-6; the catastrophic retry-budget measurement has a recorded reason (decision 3) |
| Done-criterion 2: experiment #12's conclusion restated with the two columns | step 14, entry 7 |
| Requirement 1: baselines rerun on the subset | Engines, steps 10-12 |
| Requirement 2: regenerate from `e1b9936`, four sha256 | steps 3-4, entry 1 |
| Requirement 3: harness walks the subject | Engines (position loop), step 6 (iii), entry 2 |
| Requirement 4: conversion per shape | Engines (subject modes), step 8, entry 2 |
| Requirement 5: fuel, retry and stack limits | Engines, step 7, entries 2-3 |
| Requirement 6: parser and its checks | Engines, step 6 |
| Requirement 7: packages for F\* | Tools, step 2 |
| Requirement 8: membership needs encoding and options | Workloads |
| Requirement 9: budget, schedule, pilot gate | Machine budget, step 9 |
| Requirement 10: where code and results go | Where things live, Lab notebook |
| Requirement 11: VS Code expected spans on 215 searches (issue: 227) | step 7 |
| Decisions 1-5 | Decisions folded in; decision 2 Workloads, 3 step 12, 4 step 9, 5 step 5 and Machine budget |

## Risks

| Risk | Effect | Mitigation |
|------|--------|------------|
| The extracted sources do not compile as a dune library in `ffi` (ppx, warnings, module names) | run time lost in step 5 | built during step 1 against experiment #9's copies; dune stanzas mirror `fstar.sh`'s `ocamlfind` flags |
| Regenerated sources differ from experiment #9's copies | doubt about what was measured | the timed code is the regenerated one from `e1b9936`; the sha256 and the difference are recorded |
| Parser port, position loop or conversion wrong | wrong figures | step 6 stops the run before timing |
| A syntax reads an admitted escape differently | disagreement with C | step 7 lists it; the call leaves the timed set |
| Extracted columns slower than estimated | large series over budget, 120 s timeouts at 16 MiB | pilot gate; decision 4's fallback; timeouts recorded |
| GC cost of a 400 MB list in the major heap | throughput includes major GC work | counted as part of the representation's cost; GC settings and heap size recorded |
| Captures as an association list | stars over groups cost more per iteration | none of the 29 large patterns has one; named in the conclusion |
| C optimiser rejects the catastrophic patterns without backtracking | C figures are not backtracking times | `c-noopt` column, optimiser choice recorded (step 12) |
| Packages added to the shared `ffi` switch | experiment #12's switch changes | install only (dry run: no upgrade or removal), exports before and after |
| Noise from other work on the host | spread | pinning, interleaving, IQR gate, load average logged |
| Disk below 20 GB | run cannot finish | checked before each phase; stop and report |
