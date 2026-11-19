# Experiment #2: semantic probes on the C library (2026-11-19)

Issue: [#6](https://github.com/tarides/maquizcoatl/issues/6). Plan:
[`plans/02-semantic-probes.md`](../../../plans/02-semantic-probes.md).

## What

134 probes in five areas (captures in loops, backreferences to unset
groups, empty iterations, lookbehind, multi-character case folding) were
run against upstream Oniguruma `f95747b` (Debug build and
ASan/UBSan build) and against JavaScript (Node.js 22 / V8, with and
without the `u` flag). Each probe's results are joined in
`raw/<area>.joined.tsv` and marked `same` / `different` / `n/a`.

## Why

The maintainer's state-of-the-art report
(https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc, "Experiments before
deciding", row #2) asks whether Linden's backtracking-tree semantics
(written for ECMAScript, and so for Warblre) can be adapted to Oniguruma,
or must be rewritten, and wants the deviation log seeded with behaviours
that are bugs or inconsistencies. The five areas are where Oniguruma is
expected to differ from ECMA-262.

## Provenance

- Branch `exp/02-semantic-probes`, probes committed at `cda40ca`
  (harness, oracle, comparer, data); this results directory is the next
  commit.
- Upstream: `f95747b` (`onig_version()` = `6.9.10`), `git -C upstream
  status` clean before and after.
- Machine: 12th Gen Intel Core i7-1260P, 16 threads, 15 GB RAM; Ubuntu
  26.04.1 LTS, Linux 7.0.0-43-generic.
- Toolchain: GCC 15.2.0 (Ubuntu 15.2.0-16ubuntu1), CMake 4.2.3, Node.js
  v22.22.1 (V8 flags `--js-regexp-modifiers
  --js-regexp-duplicate-named-groups`). Clang was not needed (GCC's
  UBSan output was silent).
- Builds (`<workdir>` is outside the repository; `make -j4` for both):
  - Debug: `cmake -S upstream -B <workdir>/build -DCMAKE_BUILD_TYPE=Debug`;
    effective `CMAKE_C_FLAGS` empty (Debug adds `-g`).
  - ASan/UBSan: `cmake -S upstream -B <workdir>/build-asan
    -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_FLAGS="-fsanitize=address,undefined
    -fno-omit-frame-pointer"
    -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined"
    -DCMAKE_SHARED_LINKER_FLAGS="-fsanitize=address,undefined"`;
    effective `CMAKE_C_FLAGS` = `-fsanitize=address,undefined
    -fno-omit-frame-pointer`.
  - Harness: `make -C probes BUILD=<workdir>/build OUT=<workdir>/probes-build harness`
    and the same with `BUILD=<workdir>/build-asan` (the ASan variant is
    compiled and linked with the sanitizer flags; each variant has an
    rpath to its own build directory, checked with `ldd`).
- Run: `probes/run.sh <workdir>/probes-build lab/results/02-semantic-probes-2026-11-19/raw`
  with `ASAN_OPTIONS=detect_leaks=1:abort_on_error=0` and
  `UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=0` (set by `run.sh`).
  Exit status 0, about 1 s. Deterministic: one run per configuration.
- Default case-fold flag (`onig_get_default_case_fold_flag`): `0x40000000`
  (`ONIGENC_CASE_FOLD_MIN` = multi-character folding on).
- Sanity: [`sanity-test_utf8.txt`](sanity-test_utf8.txt): `test_utf8`
  1554/0/0 on both builds, 0 sanitizer reports in the ASan run.

## Raw data

`raw/<area>.debug.tsv`, `.asan.tsv`, `.asan.stderr`, `.js.tsv`, and the
joined `raw/<area>.joined.tsv` (columns documented in
[`probes/README.md`](../../../probes/README.md)).

| Area | Probes | same | different | n/a (extra) | Sanitizer reports | Debug = ASan |
|------|-------:|-----:|----------:|------------:|------------------:|:------------:|
| [captures in loops](raw/captures-in-loops.joined.tsv) | 12 | 1 | 11 | 0 | 0 | all |
| [backref to unset group](raw/backref-unset.joined.tsv) | 15 | 3 | 10 | 2 | 0 | all |
| [empty iterations](raw/empty-iterations.joined.tsv) | 16 | 3 | 9 | 4 | 0 | all |
| [lookbehind](raw/lookbehind.joined.tsv) (23 patterns x Oniguruma/Ruby/Perl) | 69 | 32 | 37 | 0 | 0 | all |
| [case folding](raw/case-folding.joined.tsv) (20 UTF-8 + 2 ISO-8859-1) | 22 | 14 | 8 | 0 | 0 | all |

No probe crashed and no sanitizer report was raised; the Debug and ASan
results agree on every probe.

## Analysis

Offsets below are code points; `1=-` is an unset group.

### 1. Captures in loops

Oniguruma never resets captures at the start of an iteration; ECMA-262
does (RepeatMatcher, ES2025 22.2.2.3.1, step 4: captures of the quantified
atom are set to undefined before each iteration). Every probe with a
capture skipped in a later iteration differs:

| Probe | Pattern / subject | Oniguruma | JavaScript |
|-------|-------------------|-----------|------------|
| cl01 | `(?:(a)\|b)+` / `ab` | `M 0-2 \| 1=0-1` | `M 0-2 \| 1=-` |
| cl02 | `(?:(a)\|b)+\1` / `aba` | `M 0-3 \| 1=0-1` | `M 0-2 \| 1=-` |
| cl03 | `(?:(a)\|b)+\1` / `abb` | `N` | `M 0-3 \| 1=-` |
| cl07 | `(z)((a+)?(b+)?(c))*` / `zaacbbbcac` | group 4 = `4-7` | group 4 unset (the ES spec's own NOTE example) |
| cl09 | `(?:(a)\|b)*?\1c` / `abac` | `M 0-4 \| 1=0-1` | `M 3-4 \| 1=-` |

cl12 `(a|b)*` (same group every iteration) is the control and agrees.
cl03 and cl09 also show the interaction with area 2: in JavaScript a
reset group makes `\1` match empty, in Oniguruma a stale capture keeps
`\1` bound.

**Verdict: adapts.** Drop the capture reset of RepeatMatcher step 4
(keep the previous iteration's captures, restored only on backtracking).
This is a local change to the repeat matcher; the backtracking-tree
structure is unaffected.

### 2. Backreferences to unset groups

Oniguruma fails a backreference to a group that has not participated;
ECMA-262 matches it as the empty string (BackreferenceMatcher, ES2025
22.2.2.7.2). Forward references (`\1(a)`, br02) behave the same way: the
group is unset when `\1` runs, so it fails. The result is the same under
Oniguruma, Ruby and Perl syntaxes (br01, br14, br15).
`ONIG_SYN_STRICT_CHECK_BACKREF` changes only compile-time acceptance
(br11: `\1(a)` becomes error -208), not the run-time rule (br10, br12).
Duplicate names follow `doc/RE` section 8 ("the last group with the name
is checked first, if not matched then the previous one"): br08
`(?<n>a)(?<n>x)?\k<n>` on `aa` matches through group 1 while group 2 is
unset (multi-group continue path); br06/br07 agree with JavaScript's
duplicate named groups across alternatives.

**Verdict: adapts.** Make BackreferenceMatcher fail (instead of
succeeding with an empty match) when the group is unset, and, for a name
bound to several groups, try the groups from last to first, skipping
unset ones, succeeding on the first that matches. Both are local to the
backreference matcher.

### 3. Empty iterations

> **Erratum (2026-11-19, after review):** the capture-status check
> described below is narrower than stated: `OP_EMPTY_CHECK_END_MEMST` is
> emitted only for groups referenced by a backreference *outside* the
> loop (`upstream/src/regcomp.c:984`, `:3941-3957`); ei04, ei11 and ei16
> get the plain `OP_EMPTY_CHECK_END`. The corrected verdict and D3 are in
> [run 2](../02-semantic-probes-2026-11-19-r2/README.md); the text below
> is kept as recorded.

ECMA-262 rejects an iteration that consumed nothing once the minimum
count is reached (RepeatMatcher, ES2025 22.2.2.3.1, step 2.b: return
failure), so the empty iteration and its captures are backtracked away.
Oniguruma instead *exits* the loop after an empty iteration and keeps
what that iteration captured, and, for bodies containing captures
(`OP_EMPTY_CHECK_END_MEMST`), lets the loop continue when the capture
status changed (`doc/RE:592-595`):

| Probe | Pattern / subject | Oniguruma | JavaScript |
|-------|-------------------|-----------|------------|
| ei01 | `()*\1` / `a` | `M 0-0 \| 1=0-0` | `M 0-0 \| 1=-` |
| ei04 | `(a\|)*` / `aa` | `M 0-2 \| 1=2-2` | `M 0-2 \| 1=1-2` |
| ei05 | `(a\|)*` / `b` | `M 0-0 \| 1=0-0` | `M 0-0 \| 1=-` |
| ei10 | `(?:a\|())*\1` / `aa` | `M 0-2 \| 1=2-2` | `M 0-2 \| 1=-` |
| ei11 | `(?:(a)\|())*` / `ab` | `M 0-1 \| 1=0-1 2=1-1` | `M 0-1 \| 1=0-1 2=-` |
| ei16 | `(?:\1a\|())*` / `a` | `M 0-0 \| 1=0-0` | `M 0-1 \| 1=-` |

Lazy and non-capturing loops agree (ei06, ei09), as does `(a*)+` (ei08,
first iteration below the minimum). The recursion variant
(`OP_EMPTY_CHECK_END_MEMST_PUSH`, chosen when the body is a recursive
group, `upstream/src/regcomp.c:5076`, `:5098`, `:993-994`) is exercised by
ei14/ei15 `(?<r>a\g<r>?b|)*c`, which keep the empty last iteration's
capture (`1=6-6`, `1=0-0`); the bytecode was not dumped, so the opcode
choice rests on the code reading. ei12 `(?<r>a?\g<r>?)*b` (the plan's
example) is rejected with -221 "never ending recursion", the documented
ban on left-most recursion (`doc/RE:474-477`), so ei14/ei15 replace it.

**Verdict: adapts, with the largest change of the five.** Replace the
RepeatMatcher's empty-iteration failure by Oniguruma's empty check: on an
empty iteration, leave the loop keeping the iteration's state; for
capture-bearing bodies, compare the capture status with the one at
iteration start and continue the loop if it changed; for recursive
bodies, the same with the push variant. The rule must be specified from
`regexec.c` (`OP_EMPTY_CHECK_END*`), not from `doc/RE`, because ei16
shows the doc's wording does not predict the result (see deviation
candidate D3). The tree structure still holds: this is a different
continuation at the loop node, not a different execution model.

### 4. Lookbehind

Compile acceptance depends on the syntax, as expected from
`ONIG_SYN_VARIABLE_LEN_LOOK_BEHIND` (Oniguruma, Java) and
`ONIG_SYN_DIFFERENT_LEN_ALT_LOOK_BEHIND` (Ruby): Oniguruma accepts every
positive pattern probed; Ruby accepts only fixed-length bodies and
different-length top-level alternatives (lb04r); Perl accepts only
fixed-length bodies. These syntax-driven errors are by design.

Where both run, the match ranges agree with JavaScript, but **captures
inside a variable-length lookbehind differ**: Oniguruma steps back
`min` characters, matches the body *forward* and, on failure, steps back
one more character (`OP_STEP_BACK_START` / `OP_STEP_BACK_NEXT`,
`upstream/src/regexec.c:4481-4504`), so it takes the *nearest* start that
works; ECMA-262 matches the body *backward* (22.2.2.4, direction
backward), so greedy quantifiers take the *farthest* start:

| Probe | Pattern / subject | Oniguruma | JavaScript |
|-------|-------------------|-----------|------------|
| lb08o | `(?<=(a+))b` / `aab` | `M 2-3 \| 1=1-2` | `M 2-3 \| 1=0-2` |
| lb22o | `(?<=(a*))b` / `aab` | `M 2-3 \| 1=2-2` | `M 2-3 \| 1=0-2` |
| lb21o | `(?<=(a\|aa))b` / `aab` | `1=1-2` | `1=1-2` (agrees: alternatives in order) |

Captures are forbidden in negative lookbehind under every syntax (lb05,
lb06: error -122; `ALLOWED_BAG_IN_LB_NOT`,
`upstream/src/regcomp.c:3499`), which `doc/RE` does not state.

The `alt_reduce_in_look_behind` rewrite (`upstream/src/regcomp.c:4531-4594`,
run at `:4628` before `node_char_len`) is visible only in Ruby/Perl
acceptance. Each data row records the outcome expected from reading the
reducer alone; the observed outcomes split:

| Body | Ruby / Perl | Expected from the reducer |
|------|-------------|---------------------------|
| `a+` (lb16), `a+a` (lb17), `\w+b` (lb18), `(?<!a+)` (lb19), `a+\|b` (lb23) | compiles | compiles |
| `a+b` (lb09), `(?<!a+b)` (lb10, lb20), `a*b` (lb11) | **error -122** | compiles |
| `ba+` (lb12, lb13), `a+b*c` (lb14) | error -122 | error -122 |

The reducer only rewrites a bare `ND_QUANT` (`:4536`), but
`tune_tree(body)` runs first (`:4625`) and its automatic possessivisation
(`tune_next`, `:4714-4727`) wraps `a+` in an atomic group whenever the
next literal is exclusive of `a` (`a+b`, `a*b`), so the reduction no
longer applies. `a+a` and `\w+b` are not exclusive, so they are reduced
and accepted. See deviation candidate D1.

**Verdict: needs rewriting for this construct.** Linden's lookbehind
(backward matching) produces the wrong captures for Oniguruma; the
lookbehind node must be re-specified as "find the nearest start position
p' such that the body, matched forward from p', ends exactly at the
current position", atomic once found (`OP_CUT_TO_MARK`), plus per-syntax
compile restrictions (length classes, no captures in negative
lookbehind, max length `LOOK_BEHIND_MAX_CHAR_LEN`). The rest of the tree
semantics is unaffected; only the lookbehind node and its compile-time
checks change.

### 5. Case folding

Oniguruma applies Unicode full (multi-character) case folding outside
lookbehind: `(?i:ss)` matches `ß` (cf01), `ẞ` (cf02); `(?i:ß)` matches
`ss`/`SS` (cf04, cf05); `(?i:ǰ)` matches `J` + U+030C (cf07). JavaScript
uses simple folding only (Canonicalize, ES2025 22.2.2.7.3) and fails
them, with or without `u`; with `u`, `ſ` and the Kelvin sign fold to
`s`/`k` (cf03, cf20), which Oniguruma also does.

Inside lookbehind, multi-character folding is off, as documented in
`doc/RE:314-317`: `(?i)(?<=ss)v` does not match `ßv` (cf12),
`(?i)(?<=ß)v` does not match `ssv` (cf13), and `(?i)(?<!ss)z` matches
`ßz` (cf10), although `(?i:ss)` matches `ß` outside lookbehind (cf01).
This agrees with JavaScript by accident (JavaScript has no
multi-character folding anywhere). `ONIG_OPTION_IGNORECASE_IS_ASCII`
turns off every non-ASCII fold (cf15-cf17, cf19 Kelvin sign), as
documented in `doc/API:90`.

ISO-8859-1 (single configuration: Oniguruma syntax, default case-fold
flag): `(?i)ss` matches byte `\xDF` (cf21) and `(?i)\xDF` matches `ss`
(cf22): the multi-character fold `ß`/`ss` also exists in this
single-byte encoding. JavaScript on the same code points (marked
`js-on-codepoints`) does not match.

**Verdict: adapts.** Replace Canonicalize-based character comparison by
Oniguruma's case-fold expansion (a character may match a string of
several characters, and a string may match one character), made
encoding-dependent (ISO-8859-1 has `ß`/`ss` too) and switched off inside
lookbehind and under `IGNORECASE_IS_ASCII`. The expansion is a compile
step (`regcomp.c` expands case-fold strings before `node_char_len`), so
it can be specified as a tree rewrite before matching, keeping Linden's
matcher.

## Candidate deviation-log entries

Tested against the issue's rule (crash, sanitizer report or error where
a match was expected; contradiction with `doc/RE`, `doc/SYNTAX.md` or
`doc/API`; two probes differing with no flag, option or documented rule
explaining it).

| # | Kind | Probes | Behaviour at `f95747b` | Proposed spec position |
|---|------|--------|------------------------|------------------------|
| D1 | Inconsistency (two probes differ, no flag explains it) | lb09r/p, lb10r/p, lb11r/p, lb20r/p vs lb16r/p, lb17r/p, lb18r/p | Under Ruby and Perl syntax, `(?<=a+a)x` and `(?<=\w+b)x` compile but `(?<=a+b)x`, `(?<=a*b)x`, `(?<!a+b)x` are rejected (-122). Cause: automatic possessivisation (`regcomp.c:4714-4727`) runs inside `tune_tree(body)` (`:4625`) before `alt_reduce_in_look_behind` (`:4628`), whose `node_reduce_in_look_behind` only accepts a bare quantifier (`:4536`). | Acceptance should not depend on whether the next literal is exclusive: either reduce through the atomic wrapper (accept all head-quantifier bodies) or never reduce. Maintainer decision. |
| D2 | Undocumented restriction (error where `doc/RE` suggests a match) | lb05o/r/p, lb06o/r/p | `(?<!(a))b` is a compile error (-122) under every syntax; `doc/RE:306-317` lists only absent-operator and ignore-case restrictions for lookbehind. Source: `ALLOWED_BAG_IN_LB_NOT` (`regcomp.c:3499`). | Either lift the restriction (captures in a negative lookbehind are always unset after it, as in JavaScript) or keep it and document it. Maintainer decision. |
| D3 | Contradiction with `doc/RE` (weak) | ei16 | `doc/RE:592-595` says an empty iteration stops the loop unless the capture status changed, and cites `/(?:\1a\|())*/ =~ "a"`. Read literally, iteration 1 sets group 1 (status changed, loop continues) and iteration 2 matches `a`, giving `[0,1)`. Oniguruma gives `M 0-0 \| 1=0-0`, and `upstream/test/test_utf8.c:742` pins group 1 = `[0,0)`. | Specify the rule from `regexec.c`; either fix the doc wording or the behaviour. Maintainer decision. |

Not candidates (by design: a syntax flag, option or documented rule
explains them): syntax-dependent lookbehind errors (`ONIG_SYN_*` flags);
STRICT_BACKREF compile error br11; the left-most recursion error ei12
(`doc/RE:474-477`); no multi-character folding in lookbehind
(cf10, cf12, cf13; `doc/RE:314-317`, a documented limitation that the
bug-free goal may still want to lift); `IGNORECASE_IS_ASCII` results;
the differences with JavaScript in areas 1-3 (Oniguruma's own semantics,
consistent across probes and syntaxes). The nearest-start capture rule in
lookbehind (lb08o, lb22o) is undocumented but consistent; it goes into
the spec as confirmed behaviour.

## Open questions

> **Update (run 2):** the first question is closed: the
> `ONIG_DEBUG_COMPILE` dump shows `empty-check-end-memst-push` for
> ei14/ei15 ([run 2](../02-semantic-probes-2026-11-19-r2/README.md)).

- The opcode choice behind ei14/ei15 (`OP_EMPTY_CHECK_END_MEMST_PUSH`)
  is inferred from the source, not observed; a bytecode dump
  (`ONIG_DEBUG_COMPILE` build) would confirm it.
- The ECMA-262 clauses are cited from the ES2025 algorithm steps; each
  "different" result that drives a verdict agrees with those steps, but
  Node.js stands in for the spec until Warblre (#13) can replace it.
- Corpus widening from `upstream/test/*.c` is follow-up, as planned.
