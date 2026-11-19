# Plan: experiment #2, semantic probes on the C library

Issue: [#6](https://github.com/tarides/maquizcoatl/issues/6).
Source: maintainer's state-of-the-art report, "Experiments before
deciding", row #2 (https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

## Objective

Record, by running Oniguruma at `f95747b`, how it behaves where its
semantics is expected to differ from JavaScript (and so from
Warblre/Linden): captures in loops, backreferences to unset groups,
empty iterations, lookbehind limits, and multi-character case folding.
From the probes, decide per area whether Linden's backtracking-tree
semantics adapts to Oniguruma (with which change) or must be rewritten,
and seed the deviation log with behaviours that are bugs or
inconsistencies.

## Decisions folded in

- Case-folding encoding scope: option (b) with a single ISO-8859-1
  mode ([comment](https://github.com/tarides/maquizcoatl/issues/6#issuecomment-7006954899)).
  The case-folding area gets one or two extra probes under
  `ONIG_ENCODING_ISO_8859_1`, default syntax, default case-fold flag.
  No other legacy encoding, no flag variants; the rest stays with #8.

## Approach

1. **Build upstream out of tree.** Two builds of `upstream/` at
   `f95747b`, both under `<workdir>/e02/`:
   - `build-debug`: `cmake -S upstream -B <workdir>/e02/build-debug
     -DCMAKE_BUILD_TYPE=Debug`, then `make -j4`.
   - `build-asan`: same, with `-DCMAKE_C_FLAGS="-fsanitize=address,undefined
     -fno-omit-frame-pointer"`, so that "crash or sanitizer report" in
     the done-criteria is actually checked. Upstream CMake builds libonig
     as a shared library by default (`upstream/CMakeLists.txt:9`), so the
     harness's ASan variant is compiled *and linked* with the same
     `-fsanitize=address,undefined -fno-omit-frame-pointer` flags, and
     each harness variant is linked with an rpath to its own build
     directory (with `LD_LIBRARY_PATH` set to the same directory at run
     time as a guard), so the Debug harness never loads the ASan library
     or the reverse. Runs set
     `ASAN_OPTIONS=detect_leaks=1:abort_on_error=0` and
     `UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=0`; the exact values
     are recorded in the notebook command lines.
   Sanity check: run `test_utf8` on the Debug build and record its
   `RESULT` line (expected 1554 SUCC). `upstream/` is never written to;
   `git -C upstream status` must stay clean. The exact `cmake` command
   lines and the effective `CMAKE_C_FLAGS` of each build are recorded in
   the notebook.
2. **Write the probe harness** (`probes/harness.c` in this repository,
   built against `<workdir>/e02/build-*`). It reads a probe data file
   and, for each line, compiles the pattern with `onig_new` under the
   named syntax, encoding and options, searches the subject with
   `onig_search`, and prints one record per probe: pattern, subject,
   options, syntax, encoding, case-fold flag
   (`onig_get_default_case_fold_flag`), `onig_version()`, build type,
   and the result (match range and all capture ranges, no-match, or the
   error code and message from `onig_error_code_to_str`). Output is
   TSV, one line per probe, so the run can be diffed and replayed.
   Before the first `onig_new`, the harness calls `onig_initialize` with
   `ONIG_ENCODING_UTF8` and `ONIG_ENCODING_ISO_8859_1`, and it calls
   `onig_end` at exit.
   Syntax names map to the built-in `OnigSyntax*` objects; a special
   `Oniguruma+STRICT_BACKREF` name copies `OnigSyntaxOniguruma` with
   `onig_copy_syntax` and adds `ONIG_SYN_STRICT_CHECK_BACKREF` via
   `onig_set_syntax_behavior`. Subjects are given as escaped strings
   (`\xHH` for ISO-8859-1 bytes).
3. **Write the JavaScript oracle** (`probes/oracle.mjs`, run with
   Node.js 22 and the V8 flags `--js-regexp-modifiers
   --js-regexp-duplicate-named-groups`, so that inline modifier groups
   `(?i:…)` and duplicate named groups, both in ECMA-262 2025, are
   expressible; rows that rely on either flag are marked `js-flagged`,
   and the flags are recorded with `node --version`). It reads the same data files, translates each pattern to a
   JavaScript `RegExp` where the syntax is expressible (a per-probe
   `js` column holds the JavaScript spelling when it differs, or
   `n/a` with an ECMA-262 clause reference, citing the edition, only
   when ECMA-262 itself cannot express the probe), runs it with and without the `u` flag where the
   area asks for both, and prints the same TSV schema. Capture ranges
   come from the `d` (indices) flag. For ISO-8859-1 probes, the
   JavaScript side runs on the same code points as a UTF-16 string and
   is marked `js-on-codepoints`.
4. **Write the probe data**, one file per area under `probes/`
   (`captures-in-loops.tsv`, `backref-unset.tsv`, `empty-iterations.tsv`,
   `lookbehind.tsv`, `case-folding.tsv`), at least 5 probes each,
   seeded from the anchors in the issue:
   - captures in loops: `(?:(a)|b)+` on `ab`, `(?:(a)|b)+\1` on `aba`
     and `abb`, nested-group and lazy-quantifier variants;
   - backreferences to unset groups: `(a)$|\1` on `az`, `\1(a)`, a
     named group defined twice with only the first set
     (multi-group continue path), the same probes under
     `Oniguruma+STRICT_BACKREF`;
   - empty iterations: `()*\1`, `(?:()|())*\1\2`,
     `(?:()|()|()|(x)|()|())*\2b\5`, `(a|)*` and `(?:a?)*?b`,
     plus one loop whose body may be empty through a recursive call,
     which is what selects the `_PUSH` variant
     (`OP_EMPTY_CHECK_END_MEMST_PUSH`, `upstream/src/regcomp.c:993-994`,
     taken only when the body is `ND_IS_RECURSION`,
     `upstream/src/regcomp.c:5076`, `:5098`): a self-calling quantified
     group such as `(?<r>a?\g<r>?)*b`, JavaScript column `n/a` (no
     subexpression calls in ECMA-262 2025);
   - lookbehind: `(?<=az*)abc`, `(?<=ta+|tb+|tc+|td+)zz`,
     `(?<=a.*\w)z`, `(?<=a|bc)x`, `(?<!(a))b`, `(?i:(a)(?<=\1))`, and
     the `alt_reduce_in_look_behind` rewrite: `(?<=a+b)`, `(?<=a*b)`,
     `(?<=ba+)`, `(?<=a+b*c)`, positive and negative, head and non-head.
     The rewrite runs before `node_char_len`
     (`upstream/src/regcomp.c:4628-4631`), so its observable effect is on
     compile acceptance under the Ruby and Perl syntaxes (which reject
     variable-length lookbehind), not on match results. `(?<=a+b*c)`
     reduces to `ab*c` (reduction continues only after a removal), so it
     stays variable-length. The data file records the expected
     compile/error outcome per syntax for each of these probes. Every
     lookbehind probe is run under the Oniguruma, Ruby and Perl
     syntaxes;
   - case folding (UTF-8): `(?i:ss)` against `ß`, `ẞ`, `ſ`;
     `ǰ`; the lookbehind limitation of `upstream/doc/RE:313-316`
     (single-character conversions only; cf. `upstream/test/test_utf8.c:1575-1578`,
     where the cross cases are commented out): `(?i)(?<!ss)z` on `ssz`,
     `SSz`, `ßz`, and `(?i)(?<=ss)v` and `(?i)(?<=ß)v` on `ssv` and `ßv`; the same with
     `ONIG_OPTION_IGNORECASE_IS_ASCII`; JavaScript with and without
     `u`. Case folding (ISO-8859-1, single mode): `(?i)ss` against
     `\xDF` and `(?i)\xDF` against `ss`.
5. **Run.** Each data file through the Debug harness, the ASan/UBSan
   harness and the Node oracle; a small `probes/compare.mjs` joins the
   three outputs on probe id and adds a `same/different` column and a
   `sanitizer` column. Runs are deterministic: one run per
   configuration, no repetitions.
6. **Classify.** For each probe marked different or sanitizer-flagged,
   apply the issue's bug-or-inconsistency test (crash, sanitizer report
   or error where a match was expected; contradiction with `doc/RE`,
   `doc/SYNTAX.md` or `doc/API`; two probes differing with no syntax
   flag, option or documented rule explaining it). Differences
   explained by a syntax flag are by design. Candidates go into
   `lab/results/` as a deviation-log table citing the probe ids.
7. **Verdicts.** One paragraph per area: Linden's semantics adapts
   (naming the change, e.g. "do not reset captures at iteration
   start") or needs rewriting, citing the probes that force it.
8. **Record and report.** Lab-notebook entry (below); results summary
   posted on #6.

## Tools and versions

All actively maintained, all already installed on the machine:

- GCC 15.2 and Clang 21.1 (Clang for the sanitizer build if GCC's
  UBSan output proves noisy), CMake 4.2.
- Node.js v22.22.1 (JavaScript oracle, with `--js-regexp-modifiers
  --js-regexp-duplicate-named-groups`; the exact `node --version` and V8
  flags are recorded with every run).
- No spec or proof tool is used or chosen by this experiment.

## Where things live

- Builds, toolchain caches, raw run outputs before recording:
  `<workdir>/e02/` (outside the repository). Never inside the
  repository and never inside `upstream/`.
- In the repository (branch `exp/02-semantic-probes`): `probes/`
  (harness source, oracle, data files, a `Makefile` taking the build
  directory as a variable), `lab/notebook.md`, `lab/results/`, this
  plan.
- The harness `Makefile` builds into `<workdir>/e02/probes-build/`,
  not into the source tree.

## Machine budget

- At most 4 parallel jobs (`make -j4`; probe runs are sequential and
  single-process).
- Wall-clock for the whole run: at most 3 hours. Expected: two upstream
  builds at a few minutes each, probe runs in seconds; most of the time
  goes into writing probes, classifying and writing verdicts. Disk
  under 500 MB in `<workdir>/e02/`.
- First milestone that fits the budget, if writing probes runs long:
  the five areas at 5 probes each (lookbehind under three syntaxes),
  the ISO-8859-1 case-folding probes, both builds, and the verdicts.
  Follow-up beyond that (not required for done): widening the corpus
  from all `upstream/test/*.c` macros, and replacing Node.js by the
  Warblre extraction if #13 builds it.

## Lab notebook

Recorded with the lab-notebook skill, append-only:

- `lab/notebook.md`: one index entry for the run (date, commit of this
  branch, upstream `f95747b`, `onig_version()`, build types, compiler
  and Node.js versions, CPU model and OS version for provenance, the
  exact `cmake` command lines and `CMAKE_C_FLAGS` per build, the V8
  flags, the `ASAN_OPTIONS`/`UBSAN_OPTIONS` values, and the command
  lines to replay it), pointing at its results files. Hostnames and
  absolute paths are kept out (paths written as `<workdir>/...` or
  repository-relative).
- `lab/results/02-semantic-probes-<date>/`: the joined TSV per area
  (Oniguruma Debug, ASan, JavaScript, same/different), the
  `test_utf8` sanity line, the candidate deviation-log table, and the
  verdicts.
- Deterministic re-runs that change nothing are not recorded; the
  maintainer decides what is worth keeping.

## Outputs

- `probes/` harness, oracle and five data files (the seed of the
  characterisation corpus in the report's Methodology section).
- Lab-notebook entry and results directory as above.
- Per-area verdicts and the candidate deviation-log entries, summarised
  in a comment on #6.
- A draft PR from `exp/02-semantic-probes`, opened with this plan;
  results are pushed to the same branch. The PR also adds `probes/` and
  `lab/` to the Layout section of `CLAUDE.md`.

## Done-criteria (from the issue)

- A probe harness (outside `upstream/`) that compiles and runs every
  probe against the `f95747b` build and prints pattern, subject,
  options, syntax, encoding, case-fold flag, `onig_version()`, build
  type and the observed result (match range and captures, no-match, or
  error code). Probes are kept as data files (one per area) so the
  lab-notebook entry can replay the run.
- At least 5 probes per area for each of the five areas, each run and
  recorded; each probe states the JavaScript (ECMA-262) result
  alongside Oniguruma's, marked same/different. Counting rule: each area
  has at least 5 probes with a concrete JavaScript result; `n/a` probes
  are extra and do not count toward the 5.
- Each lookbehind probe runs under at least the Oniguruma, Ruby and
  Perl syntaxes, and records the syntax.
- The case-folding area also has ISO-8859-1 probes (one or two, single
  configuration: default syntax, default case-fold flag), in addition
  to its UTF-8 probes, with the encoding recorded. JavaScript has no
  byte-encoding mode, so their JavaScript column compares against the
  same code points in UTF-16 and is marked as such.
- For each area, a one-paragraph verdict: Linden's semantics adapts
  (with which change) or needs rewriting.
- Every behaviour judged a bug or inconsistency is listed as a
  candidate deviation-log entry with the probe that shows it. A bug or
  inconsistency is: a crash, sanitizer report, or error where a match
  was expected; a result contradicting `doc/RE`, `doc/SYNTAX.md` or
  `doc/API`; or two probes whose results differ with no syntax flag,
  option or documented rule explaining it. Differences explained by a
  syntax flag are by design.
- Runs recorded in the lab notebook; results summarised on the issue.

## Risks

- **Pattern translation to JavaScript.** Oniguruma syntax (`\k<n>`
  with duplicate names, `(?i:…)` inline groups, subexpression calls)
  has no direct JavaScript spelling in some probes. Mitigation: the
  per-probe `js` column, and `n/a` with the ECMA-262 clause when
  inexpressible in ECMA-262 2025. V8 flags make `(?i:…)` and duplicate
  named groups expressible. `n/a` probes do not count toward the 5
  compared probes per area; they are extra.
- **Node.js is an engine, not the spec.** V8 could deviate from
  ECMA-262 on an edge case. Mitigation: for each "different" verdict
  that drives an area verdict, check the ECMA-262 clause by hand and
  note it; Warblre can replace Node later (#13).
- **Sanitizer build noise.** UBSan may report benign issues unrelated to
  the probes. Mitigation: record only reports raised while running a
  probe, attribute each to its probe id, and keep the baseline
  `test_utf8` run under ASan for comparison.
- **Syntax-dependent results mistaken for bugs.** Mitigation: the
  classification step checks each difference against the syntax's
  `ONIG_SYN_*` flags before listing it as a candidate.
- **Time budget.** Writing and translating probes dominates. Mitigation:
  the first milestone above; corpus widening is follow-up.
- **Licence.** Probes copied from `upstream/test/*.c` are short
  patterns; any larger quoted code keeps Oniguruma's copyright notice
  and BSD-2-Clause conditions.
