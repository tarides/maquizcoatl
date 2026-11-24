# Plan: experiment #6, milestone 2 (S2)

Issue: [#28](https://github.com/tarides/maquizcoatl/issues/28). The
issue body is the reference for scope, decisions and done-criteria;
this plan says how. It continues milestone 1 (issue
[#1](https://github.com/tarides/maquizcoatl/issues/1), PR #24, merged
on `main`), whose plan `plans/06-spec-speed.md` (step 13, decisions
1-5) and protocol apply unchanged unless stated otherwise below.
Source: maintainer's state-of-the-art report, "Experiments before
deciding", row of experiment #6
(https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc).

## Objective

Extend stack G (the OCaml reference interpreter) and the six provers'
semantics from experiment #9's subset to experiment #1's first subset
S2, then repeat done-criteria 1-4 of experiment #6 on the S2 cases.
Measure `T_spec` of the larger semantics and use it to settle the
experiment #7 verdicts that milestone 1 left open. The experiment
answers the two questions of issue #28:

1. **Interpreted in-prover modes.** Do `why3 execute` and the F\*
   normaliser (about 62 cases/s on milestone 1, under the 8-hour bar by
   only 1.8x) stay at or above 34.7 cases/s on the S2 semantics and
   cases?
2. **Experiment #7's table verdicts.** Does milestone 2's `T_spec`,
   still read as a lower bound (Decision 5 of milestone 1), settle any
   of the nine open targets "in-prover"? Verdicts that are already
   settled are not revisited. Milestone 1 settled none.

## Decisions in force

- **From issue #1** (decisions 1-5 of `plans/06-spec-speed.md`):
  10^6 cases in at most 8 hours on one core (at least 34.7 cases/s, end
  to end), S2 after experiment #9's subset with the semantics extended
  rather than rewritten, stack G as the seventh row, experiment #7's
  `T_spec` protocol, and the lower-bound settling rule (c).
- **From issue #28** (maintainer decision of 2026-11-24, relayed by
  the pipeline): the gate is met and every prover stands (Rocq, Lean 4,
  Why3, F\*, Verus, Isabelle/HOL, plus stack G). Work packages are
  ordered by value, each execution run takes at most 4 hours, and the
  first run is a milestone that fits if S2 does not fit in one run.
  The Why3 bug may be checked and drafted but is never filed without
  approval.

## Scope: what S2 means here

S2 comes from experiment #1
(`lab/results/2026-11-19-exp-01-compile-and-classify.md`, "Proposed
first subset"). It covers UTF-8 and the `ONIG_SYNTAX_ONIGURUMA`,
`ONIG_SYNTAX_PERL_NG` and `ONIG_SYNTAX_RUBY` syntaxes, on the regular
core of the linear tier:

- concatenation, alternation, and greedy, lazy and possessive
  quantifiers, including `+`, `?` and bounded repetition `{n,m}`;
- anchors (`^`, `$`, `\A`, `\z`, `\Z`, `\b`, `\B`, `\G`);
- captures, non-capturing groups and named groups;
- option groups (`(?imsx-imsx)`, `(?imsx-imsx:...)`), with per-syntax
  meanings: `i` is `ONIG_OPTION_IGNORECASE` and `x` is
  `ONIG_OPTION_EXTEND` everywhere; under Ruby and Oniguruma `(?m)` is
  `ONIG_OPTION_MULTILINE` (dot matches newline) and `(?s)` is an error;
  under Perl_NG (`ONIG_SYN_OP2_OPTION_PERL`) `(?s)` is
  `ONIG_OPTION_MULTILINE` and `(?m)` negates `ONIG_OPTION_SINGLELINE`
  (`upstream/src/regparse.c:8354-8368`), with
  `ONIG_OPTION_SINGLELINE` among Perl_NG's default options
  (`upstream/src/regsyntax.c:238`). The Oniguruma-only option letters
  (`(?W)`, `(?D)`, `(?S)`, `(?P)`, `(?y{..})`, `(?a)`, `(?u)`, `(?C)`)
  are out of S2: they select ASCII-only ctypes, text-segment modes or
  capture control, which the S2 tables and semantics do not model, and
  their cases are counted out with that reason;
- bounded repetition with per-syntax rules: `{n,m}+` is possessive only
  under Perl_NG (`ONIG_SYN_OP2_PLUS_POSSESSIVE_INTERVAL`) and is a
  nested repeat (`{n,m}` then `+`) under Ruby and Oniguruma; `{,n}` is
  allowed under Ruby and Oniguruma only
  (`ONIG_SYN_ALLOW_INTERVAL_LOW_ABBREV`);
- character classes, including POSIX brackets, nested classes and
  intersection, and the ctype escapes;
- lookahead and lookbehind, positive and negative;
- atomic groups;
- Unicode properties (`\p{..}`, `\P{..}`, also inside classes);
- case-insensitive matching, including multi-character folding;
- backreferences, numbered (`\1`, `\k<n>`, and the relative `\k<-n>`,
  resolved to a group number by the parser) and named (`\k<name>`, also
  with multiplex names). Backreferences with a nesting level
  (`\k<n+level>`) stay out.

The following stay out of S2 and are counted with their reason, as in
milestone 1: subexpression calls (`\g`), conditionals, the absent
operator, callouts and verbs, backreferences with a nesting level,
`\X`, `\y`/`\Y`, `\R`, `\K`, `\O`, `\N`, encodings other than UTF-8,
the other syntaxes, `test_regset`, and backward search (`test_back`).
Backward search is a search mode of the API, not a pattern feature of
S2, and milestone 1 measured forward search only. Options passed
through the API (`test_options`) are in S2 when they are pattern
options: `ONIG_OPTION_IGNORECASE`, `ONIG_OPTION_EXTEND`,
`ONIG_OPTION_MULTILINE`, `ONIG_OPTION_SINGLELINE` and
`ONIG_OPTION_NONE`. The others are out, with the reason recorded:
`ONIG_OPTION_IGNORECASE_IS_ASCII`, `ONIG_OPTION_WORD_IS_ASCII`,
`ONIG_OPTION_DIGIT_IS_ASCII`, `ONIG_OPTION_SPACE_IS_ASCII` and
`ONIG_OPTION_POSIX_IS_ASCII` (ASCII-restricted ctypes and folding,
not modelled by the S2 tables); `ONIG_OPTION_NOTBOL`,
`ONIG_OPTION_NOTEOL`, `ONIG_OPTION_NOT_BEGIN_STRING` and
`ONIG_OPTION_NOT_END_STRING` (search-time anchor options of the API,
not pattern features); `ONIG_OPTION_MATCH_WHOLE_STRING`,
`ONIG_OPTION_FIND_LONGEST` and `ONIG_OPTION_FIND_NOT_EMPTY` (search
modes of the API, outside the first-match semantics measured here).

The size of the work comes from a heuristic pass over milestone 1's
extraction (`all.tsv`, untimed, on the workstation). The pool is 1,610
UTF-8 forward cases in the three syntaxes. About 234 of them use a
construct outside S2, which leaves at most about 1,376 cases (967
`x2`, 83 `x3`, 249 `n`, 77 `e`), roughly 9 times milestone 1's 152.
Among these, about 178 cases use case folding, 143 named groups, 130
lookbehind, 101 intervals, about 119 backreferences and 71 Unicode
properties. Stack G's classifier gives the exact counts (step 2).

## Where things live

- **Bench host** (all timed runs). `<bench-workdir>/cache/` (written
  `<cache>`) is the shared toolchain cache of experiments #7 and #8:
  the opam root, with switch `provers` and the pins below, plus
  `<cache>/env.sh`. The default opam switch is not changed. Every
  command uses `opam exec --switch=provers --` explicitly (as
  `common.sh` does), never `opam switch set` or `eval $(opam env)`.
  `<bench-workdir>/exp/06-spec-speed/` (written `<exp>`) is milestone
  1's tree, about 0.9 GB, and is kept as it is. Milestone 2 adds
  `<exp>/m2/` with the same layout: `src/` (a copy of the branch's
  `lab/06-spec-speed/`), `gen/`, `build/<tool>/` and
  `out/<run-id>/`. The C library build in `<exp>/build/onig/` is
  reused read only.
- **Workstation.** `<workdir>` is the work directory outside the
  repository. The worktree is `<workdir>/wt/06-spec-speed-m2`. Raw
  outputs are copied back to `<workdir>/e06m2/out/` before they are
  selected for the notebook.
- **Repository** (branch `exp/06-spec-speed-m2`), under
  `lab/06-spec-speed/`. Milestone 1's files are extended, not
  rewritten. Where a milestone 1 script must keep reproducing milestone
  1's figures, its milestone 2 version is selected by a switch
  (`G_SUBSET=s2`, `M=2` in `common.sh`) rather than by an edit that
  changes milestone 1's behaviour.
  - `cases/extract.py`: unchanged (it already extracts every suite with
    its syntax and options).
  - `g/g.ml`: the parser is extended to S2 for the three syntaxes, the
    classifier gains `G_SUBSET=s2`, and the interpreter is extended.
  - `g/tables/` (new): `gen_tables.py`, which reads as data
    `upstream/src/unicode_fold_data.c` (`OnigUnicodeFolds1`, `2` and
    `3`), `upstream/src/unicode_fold1_key.c` (1,423 keys),
    `unicode_fold2_key.c` (59), `unicode_fold3_key.c` (14),
    `unicode_unfold_key.c` (1,557), `unicode_property_data.c`,
    `unicode_property_data_posix.c` and `upstream/src/unicode.c`, and
    emits the fold and property tables. Generated files are not
    committed; their sizes and sha256 are recorded.
  - `oracle/oracle.c`: gains the syntax and options columns, named
    group regions (`onig_name_to_backref_number` for `x3` on names),
    and the same timing loop.
  - `cases/gen.py`: writes the S2 case modules and the table modules
    per prover.
  - `<tool>/Spec*` and the drivers: extended in place, keeping
    milestone 1's definitions as the core. Line counts are reported for
    the whole file and for the S2 additions.
  - `series-m2-<n>.sh`: one script per execution run (below). Also
    `reps-m2.env`, and the milestone 2 sections of `summarise.py`
    (`--m2`) and `pins.json`.

Scripts take `BENCH_WORKDIR` and `EXP` from the environment and print
no absolute path, hostname or address.

## Tools and versions

These are milestone 1's pins (`lab/06-spec-speed/pins.json`), all
actively maintained, and kept for comparability with milestone 1 and
experiment #7:

| Tool | Version | Role |
|------|---------|------|
| OCaml | 5.4.1, switch `provers` (zarith 1.14) | stack G, extracted OCaml, drivers |
| Rocq | rocq-core 9.3.0, rocq-stdlib 9.2.0, rocq-native | `vm_compute`, `native_compute`, extraction |
| Lean 4 | 4.36.0 (elan 4.4.0, lake 5.0.0) | `#eval`, `lake` native build; `lean -c` and `leanc` for `T_spec` |
| Why3 | 1.9.0 (Alt-Ergo 2.6.5) | `why3 execute`, `why3 extract -D ocaml64` |
| F\* | 2026.11.15 (Z3) | normaliser (`assert_norm`), `--codegen OCaml` |
| Verus | 0.2026.11.02.8bf68ee, Rust 1.99.1 | compiled Rust (exec code, verified for safety) |
| Isabelle/HOL | Isabelle2026 (Poly/ML 5.9.2) | `value [code]`, `export_code` OCaml |
| GCC, CMake | 13.3.0, 3.28.3 (system) | C library and oracle |
| Python | 3.12 (system, stdlib, `-I`) | extraction, tables, summaries |

If a pin has been superseded when a run starts, the pin is still kept
and the newer release is noted. The optional Why3 check (step 10)
builds Why3's master in a separate opam switch, `why3-master`, which
leaves `provers` untouched.

## Approach

Steps 1-4 and 10 are session work on the workstation and the bench
host, untimed. Steps 5-9 are machine runs on the bench host.

1. **Tables.** `gen_tables.py` emits, from the upstream data files:
   the simple and multi-character case-fold map (CaseFold, about 1,500
   entries); its inverse closure, for classes and literals under
   `(?i)`; and the range lists of the Unicode properties that the S2
   cases name, plus the ctype classes (`\w`, `\d`, `\s`, `\b`, POSIX
   brackets) under Unicode. The ctype classes are emitted as the code
   computes them, not from the `CR_*` ranges alone: below U+0100,
   `onigenc_unicode_is_code_ctype` uses the ISO-8859-1 ctype table
   (`upstream/src/unicode.c:1142-1146`), and 13 code points differ
   from `CR_*` there (experiment #7's fidelity entry). Stack G links
   the full property table, and
   its output on the S2 cases shows which properties are used. The
   prover table modules hold the fold tables in full and the property
   ranges for the used names only, a restriction that is recorded.
   Representations follow experiment #7's per-tool choices (range
   lists; a dispatch function for Why3; no polymorphic constructor
   holding a list in Why3).
2. **Classification and C reference.** `g classify` with
   `G_SUBSET=s2` on milestone 1's `all.tsv` produces `in-s2.tsv` and
   the out-of-subset reasons. `oracle` (extended) records the C
   result of each case under its syntax and options: region, every
   group region, no match, or error code. The counts per kind and per
   suite are checked against the estimate above.
3. **Stack G on S2** (work package A). The direct-style interpreter
   is extended, keeping milestone 1's rules (priority order, last
   iteration kept, explicit fuel of 10,000,000 per start position,
   subjects as bytes). The empty-iteration check is no longer the
   plain check of experiment #2 run 2, since about 119 S2 cases use
   backreferences: it is either upstream's `EMPTY_STATUS_CHECK`
   selection (an empty iteration ends the loop unless a capture
   referenced by a backreference changed in it,
   `upstream/src/regcomp.c:980-990` and `:3941-3957`, pinned by
   `upstream/test/test_utf8.c:742`) or DEV-003's rule. The maintainer
   chose DEV-003's rule (decision 1 under "Maintainer decisions"):
   DEV-001 to DEV-004 are implemented as decided.
   The extension covers:
   - lazy quantifiers and bounded repetition, as quantifier nodes with
     bounds and greediness, not unrolled;
   - possessive quantifiers and atomic groups: the first success of
     the body commits, with no backtracking into it;
   - lookahead, run at the current position with captures kept on
     success (positive) or discarded (negative). Lookahead and
     lookbehind bodies are atomic: the first success of the body
     commits, and the body is not re-entered on backtracking
     (cut-to-mark and pop-to-mark, `upstream/src/regexec.c:4506`);
   - lookbehind: `(?<=r)` holds at `i` when `r` matches exactly
     `[j, i)` for some `j`. The try order is upstream's: step back the
     body's minimum length, then one more character at a time, so the
     nearest `j` is tried first (`upstream/src/regexec.c:4481-4504`).
     Variable-length bodies are allowed only under the Oniguruma syntax
     (`ONIG_SYN_VARIABLE_LEN_LOOK_BEHIND`); top-level alternatives of
     different lengths are split and tried in order under Oniguruma and
     Ruby, and rejected under Perl_NG. Patterns that Oniguruma rejects
     (`ONIGERR_INVALID_LOOK_BEHIND_PATTERN`) are `e` cases, decided by
     stack G (in the parser or a post-parse pass). This requires
     computing the body's minimum and maximum length in characters as
     upstream does (`upstream/src/regcomp.c:4601-4667`), the per-syntax
     regimes above, the limit `LOOK_BEHIND_MAX_CHAR_LEN` (65535;
     `upstream/test/test_utf8.c:1461` is an S2 case that reaches it), and
     the ignore-case backreference rule
     (`upstream/src/regcomp.c:690-698`);
   - anchors, under the options in force (`ONIG_OPTION_SINGLELINE`,
     `ONIG_OPTION_NEGATE_SINGLELINE`, Ruby's `$` and `^`);
   - backreferences: numbered, named and multiplex, under ignore-case
     through the fold map. A multiplex backreference follows upstream:
     the groups are tried highest number first, skipping unset groups
     and groups whose content does not match at the current position;
     the first group that matches is used, with no backtracking point
     to the others, and the backreference fails only when none matches
     (`upstream/src/regcomp.c:2712-2714`,
     `upstream/src/regexec.c:4103-4127`). A backreference to an unset
     group fails, as found by experiment #2;
   - case-insensitive matching: a literal string under `(?i)` matches
     a subject segment when their full case folds are equal, with
     multi-character folds (`ss`, `st`, `ff`, ...) matching across
     code points. Classes under `(?i)` test the fold closure. This is
     a semantic statement of what `upstream/src/regcomp.c`'s
     compile-time expansion does. Where the two differ on an upstream
     case, the disagreement is either fixed, if the spec was wrong, or
     logged in `spec/deviations.md` with its reason, if the C library
     is wrong or arbitrary;
   - named groups numbered as Oniguruma does
     (`ONIG_OPTION_CAPTURE_GROUP` and the per-syntax rule that plain
     groups do not capture when named groups exist,
     `ONIG_SYN_CAPTURE_ONLY_NAMED_GROUP`), with the remaining groups
     renumbered as `disable_noname_group_capture` does. Stack G's
     parser produces the matching `e` classes:
     `ONIGERR_NUMBERED_BACKREF_OR_CALL_NOT_ALLOWED` for a numbered
     backreference when only named groups capture, and
     `ONIGERR_UNDEFINED_NAME_REFERENCE` for a name with no group.

   The parser stays in stack G for every row, as in milestone 1. The
   provers receive the AST that `classify` prints, so the `e` cases are
   inherited from stack G's parser. Agreement, throughput (parse and
   search separately) and the extrapolation for stack G are criteria
   1-4 of row G.
4. **Prover semantics.** Each prover transcribes stack G's extension
   into its milestone 1 small-step machine: new AST nodes, the
   quantifier bounds, commit points for atomic and possessive, a
   sub-run for lookaround, the fold and property lookups through the
   table module, and the backreference check. As in milestone 1, there
   are no type indices or proof terms in executable definitions, fuel
   is explicit and structural, and positions are `nat` extracted with
   `ExtrOcamlNatInt` for Rocq. Why3 keeps monomorphic list types.
   Verus remains exec code verified for safety. The order is the work
   package order below: Why3 and F\* first, then Rocq and Lean, then
   Verus and Isabelle/HOL. Prover checks run on the bench host's
   `<cache>`, never `why3 execute` on the workstation. Engineering
   time is recorded per tool.
5. **Agreement** (criterion 2, untimed, at most 4 jobs under
   `nice -n 10`, outside CPUs 28-31,60-63). Same as milestone 1 step 5:
   counts per kind (`x2`, `x3`, `n`, `e`), every group region compared,
   the `e` count inherited for the provers and reported as such, the
   out-of-subset count and reasons, and every disagreement either fixed
   or logged as a deviation.
6. **In-prover throughput** (criterion 3). This uses milestone 1's
   method: a fold over the S2 case module, the evaluation minus an
   import-only baseline Q0 (which also imports the table module),
   median of three runs, and a number of passes calibrated in an
   untimed run so that each fold lasts at least 10 s. The modes are
   Rocq `vm_compute` and `native_compute` (semantics precompiled with
   `-native-compiler yes`), Lean `#eval`, Why3 `why3 execute` (one
   function per case or an index dispatch), the F\* normaliser
   (`assert_norm` with the checked-file cache cleared, the milestone 1
   fix), and Isabelle `value [code]`. Each timed run is capped at 20
   minutes. A run that times out is recorded with the cases reached,
   is not repeated, and counts as "below the bar" when fewer than
   41,640 cases (34.7 cases/s times 20 min) were reached. A
   monolithic fold killed by `tm.sh` reports nothing, so the count of
   cases reached comes from a progress line that the in-prover driver
   prints per chunk of cases (where the mode can print during
   evaluation), and otherwise from the rate measured in the untimed
   calibration run on a prefix of the case module, which is stated as
   an estimate. If one pass
   of the interpreted modes exceeds 10 s, a single pass is the fold.
7. **Extracted and compiled throughput** (criterion 3). Same as
   milestone 1 step 7, with the S2 case file and the table module
   linked in: Rocq extraction, Lean `lake` build, Why3 and F\*
   extraction to OCaml, Verus Rust, Isabelle `export_code`, stack G
   `ocamlopt`, and the C oracle. Each run lasts at least 10 s, median
   of three.
8. **Extrapolation and verdict** (criterion 4). 10^6 / (cases/s) per
   tool and mode against 28,800 s. The prover rows add stack G's parse
   time, as in milestone 1. Milestone 1's figures are shown alongside,
   with the slowdown factor from milestone 1 to milestone 2 per mode.
   This factor answers question 1.
9. **`T_spec` and settling experiment #7.** `T_spec` of the S2
   semantics per prover and target (check, extraction and compile
   separately, median of three clean runs, load average per run),
   with milestone 1's method: the case module, table module and driver
   are excluded, so `T_spec` stays the semantics alone and is comparable
   with `T_table`. Before each clean run, the table module is built
   untimed and its artefacts are kept in the clean build directory, so
   a fresh-cache run does not re-check the table inside `T_spec`.
   Experiment #7's idle `T_table` from milestone 1
   (runs 11-13, load 1.1-2.9) is reused if milestone 2's `T_spec`
   series runs at a comparable load (1-minute load at most 8).
   Otherwise experiment #7's `timed.sh` is rerun in the same session
   (about 45 min). A new entry,
   `<date>-exp-07-verdicts-settled-m2.md`, settles the nine open
   targets against milestone 2's `T_spec` as a lower bound: "in-prover"
   for good if `T_table <= T_spec`, otherwise still open with the new
   `T_table / T_spec` ratio. The entry states that the `T_spec` is
   milestone 2's. Verus and Isabelle/HOL get a `T_spec` (the
   `m2-t-spec` entry reports it), but experiment #7 has no table for
   them. If run 2 is not launched, run 1's `m2-t-spec` entry still
   reports the ratio idle `T_table` / `T_spec` for the seven Why3 and
   F\* targets as an informational line; the settling entry stays in
   run 2.
10. **Folded-in items.**
    - *Longer folds on milestone 1* (run 1). Rerun milestone 1's
      Isabelle `value [code]` and Lean `lake` driver on milestone 1's
      cases and semantics, with milestone 1's scripts and more passes
      (`REPS_VALUE_L` 100,000 to 200,000, about 14 s, and `REPS_LEAN`
      50,000 to 75,000, about 12.6 s, to be confirmed by an untimed
      calibration). Three pinned runs each. The new medians are
      recorded as a correction note in milestone 2's throughput entry.
      Milestone 1's entries are not edited (the notebook is append
      only).
    - *Why3 bug* (optional, untimed, only if run 1 leaves time). Build
      Why3 master in the separate switch `why3-master`, run the
      isolated reproducer from milestone 1's agreement entry, and
      record the outcome. If the bug is still present, draft a report
      (reproducer, versions, expected and observed behaviour) in the
      notebook entry and as a comment on issue #28. Nothing is filed
      on Why3's tracker without the maintainer's approval.
11. **Fetch back and report.** After each run: `rsync` to
    `<workdir>/e06m2/out/`, a redaction check (paths, hostnames,
    addresses, other accounts' processes), selection into
    `lab/results/`, commit, push, and a short status comment on issue
    #28. The comparison table and the settling pointer on issue #11
    come after the last run.

## Work packages and execution runs

The work packages, ordered by value:

| WP | Content | Answers |
|----|---------|---------|
| A | Tables, S2 classifier, C oracle, stack G (steps 1-3) | baseline of every row; criteria 1-4 for G |
| B | Why3 S2 semantics, `why3 execute` and extracted OCaml, `T_spec` | question 1 |
| C | F\* S2 semantics, normaliser and extracted OCaml, `T_spec` | question 1 |
| D | Milestone 1 fold reruns (Isabelle `value`, Lean `lake`) | issue's "Also to fold in" |
| E | Rocq and Lean 4 S2 semantics, all modes, `T_spec` | criteria 1-4 for two rows; question 2 (with B and C) |
| F | Settling entry for experiment #7 (step 9) | question 2 |
| G | Verus and Isabelle/HOL S2 semantics, all modes, `T_spec` | criteria 1-4 for the last two rows |
| H | Why3 master check and draft report (optional) | issue's optional item |

S2 on seven rows does not fit in one run. The binding constraint is
not machine time but the session time needed to write six S2
semantics, while each run must stay under 4 hours with fixed scripts.
Milestone 2 therefore takes three execution runs. **Run 1 is the first
milestone, and it answers question 1 on its own.**

**Run 1: WP A, B, C, D, then the full-table spot check (decision 2),
then H if time remains.** Expected 2 h 10 min,
worst case 3 h 40 min:

| Phase | Time (expected / worst) |
|-------|------|
| Sync `<exp>/m2/`, provenance, CPU and load check | 10 / 10 min |
| Oracle and stack G verdicts; Why3 and F\* verdicts (untimed, 4 jobs) | 15 / 20 min |
| Calibration of passes (untimed) | 10 / 15 min |
| Timed: C and stack G throughput (parse, search, end to end) | 10 / 15 min |
| Timed: Why3 and F\* extracted throughput | 10 / 10 min |
| Timed: `why3 execute`, Q0 plus three runs (20 min cap each) | 20 / 50 min |
| Timed: F\* normaliser, Q0 plus three runs (20 min cap each) | 20 / 50 min |
| Timed: `T_spec` Why3 and F\* (OCaml target), three clean runs each | 10 / 15 min |
| Timed: milestone 1 fold reruns, Isabelle and Lean | 10 / 15 min |
| Timed: full-table spot check, `why3 execute` and F\* normaliser, property-heavy cases (20 min cap each, after WPs A-D) | 15 / 40 min |
| Fetch, summarise, redaction check | 15 / 20 min |
| WP H (untimed, overlapping, only if time remains) | 0 / (30 min) |

A worst-case interpreted mode is a first run that hits the 20-minute
cap. It is then not repeated, which bounds each mode at Q0 plus 20 min
in that case, and Q0 plus three runs of at most about 15 min
otherwise. If the 4-hour cap comes near, the run stops after the
current timed series and records what is left.

**Run 2: WP E and F.** Rocq and Lean 4 S2 semantics; Rocq
`vm_compute` and `native_compute` (20 min cap each) and extracted;
Lean `#eval` and `lake`; `T_spec` for Rocq and Lean, with Why3 and F\*
rerun in the same session if run 1's load differs (all four in one
series makes the settling like for like); the conditional experiment
#7 rerun (45 min); and the settling entry. Expected 2 h 30 min, worst
about 3 h 50 min.

**Run 3: WP G.** Verus and Isabelle/HOL S2 semantics; Verus compiled
Rust, Isabelle `value [code]` and `export_code`; their `T_spec`; the
final comparison table on issue #28 and the pointer on issue #11.
Expected 1 h 30 min.

The maintainer decides whether to launch runs 2 and 3 after run 1's
results. If run 1 ends partial, its record lists what is left as
precise runs in the same form.

## Machine budget

- **Bench host.** At most 4 hours of wall-clock per execution run
  (above). Timed runs (throughput and `T_spec`) run one at a time,
  serialised by milestone 1's lock and pinned with
  `taskset -c 28-31,60-63` (L3 complex 7), the same CPU set as
  milestone 1. Before each timed series, `ps -eLo user,psr,pcpu,comm`
  confirms that no other process runs on those CPUs. The load average
  is recorded per run. If heavy load appears, it is recorded and
  timing pauses until it passes. Untimed work runs as at most 4 jobs (12
  for slow installs) under `nice -n 10`, on cores outside
  28-31,60-63. Long steps run under `nohup` or `tmux`.
- **Disk** (bench host). 52 GB free on the bench host at planning
  time. Milestone 2 adds an
  estimated 2-3 GB (the builds and outputs of seven rows, plus about
  1 GB for the optional Why3 master switch). Free disk is checked
  before each run and before the Why3 switch. The run stops as
  blocked if the bench host's free disk would fall under 20 GB. The
  workstation has no builds in this plan.
- **Workstation.** Editing, the heuristic counts and Lean checks only.
  At most 4 parallel jobs and at most 3 hours of wall-clock for any
  untimed batch. Builds and toolchains live under `<workdir>/`, never in
  the repository.
- Session time spent writing the semantics (steps 1, 3, 4) is
  engineering effort, recorded per tool, not machine time.

## Lab notebook

These are recorded with the lab-notebook skill: `lab/notebook.md`
(one index line per recorded run) and
`lab/results/<date>-exp-06-m2-<topic>.md` (append only), with raw data
under `lab/results/<date>-exp-06-m2-raw/` and a `NOTICE` carrying
Oniguruma's copyright and BSD-2-Clause terms for the quoted test
cases. Planned entries for run 1:

1. `m2-provenance`: host (CPU model, kernel), tool versions,
   pinning, commits, load, free disk.
2. `m2-cases`: S2 classification counts per suite and kind,
   out-of-subset reasons, table sizes and sha256.
3. `m2-agreement`: stack G, Why3 and F\* counts, deviations,
   and line counts (whole file and S2 additions).
4. `m2-throughput`: C, stack G, Why3 and F\* in every mode, the
   extrapolation, verdicts and slowdown factors against milestone 1,
   the milestone 1 fold reruns (Isabelle, Lean) as a correction note,
   and the Why3 master check if done.
5. `m2-t-spec`: Why3 and F\*, with the informational
   `T_table` / `T_spec` line of step 9.

Runs 2 and 3 add their rows as new entries (the existing ones are not
edited), plus `<date>-exp-07-verdicts-settled-m2.md` in run 2.
Exploratory runs are recorded only inside the entry they explain. The
maintainer decides on any further entry.

## Outputs

- `lab/06-spec-speed/` extended to S2 (tables generator, classifier,
  oracle, stack G, six prover semantics and drivers,
  `series-m2-<n>.sh`, `reps-m2.env`, `summarise.py --m2`).
- The notebook entries above.
- `spec/deviations.md` entries for any C behaviour the spec does not
  reproduce, each with its reason.
- A status comment on issue #28 after each run; after the last run,
  the comparison table on issue #28 and the settled verdicts linked
  from issue #11.

## Done-criteria (from the issue)

Experiment #6's criteria 1-4 on the S2 cases for stack G and each
standing prover (all six: Rocq, Lean 4, Why3, F\*, Verus,
Isabelle/HOL), and the experiment #7 settling entry updated with
milestone 2's `T_spec`. Criteria 1-4, as worded in issue #1:

1. A semantics of the chosen subset, with its line count, committed
   under the experiment branch.
2. The number of upstream cases in the subset, and how many the spec
   passes, or a deviation is logged with its reason. Agreement is
   defined per case kind: `x2`, the group 0 region equals the C
   library's; `x3`, the region of group `mem` equals the C library's;
   `n`, no match; `e`, the spec rejects the pattern (whether the error
   code also matches is reported separately). The four counts are
   reported separately, plus the count of cases outside the subset.
3. Measured throughput in cases per second, in each execution mode the
   tool offers, on a stated machine: Rocq `vm_compute` /
   `native_compute` and extracted OCaml; Lean 4 `#eval` and `lake`
   native build; Isabelle/HOL `value` and `export_code`; Why3
   `execute` and extracted OCaml; F\* extracted OCaml (plus the
   normaliser, as in milestone 1); Verus compiled Rust; stack G
   native OCaml.
4. An extrapolated wall-clock time for 10^6 differential cases, and a
   verdict against Decision 1 (at most 8 hours on one core, at least
   about 35 cases/s). Compile (parse) and search throughput are
   reported separately where the tool makes the split visible.

Also to fold in: Isabelle `value [code]` and Lean's extracted driver
rerun so that each fold lasts at least 10 s. Optional: the Why3 bug
checked on master and a report drafted, not filed.

Run 1 meets criteria 1-4 for stack G, Why3 and F\* and answers
question 1. Runs 2 and 3 complete the remaining four rows and the
settling entry.

## Maintainer decisions on the plan's questions

Given on 2026-11-24 in the maintainer's session and recorded on issue
#28 (https://github.com/tarides/maquizcoatl/issues/28#issuecomment-7133538725):

1. **Decided deviations inside S2: (A).** Stack G and the six provers
   implement the decided Maquizcoatl behaviour of DEV-001 to DEV-004
   (`spec/deviations.md`). Upstream cases that differ (for example
   `upstream/test/test_utf8.c:742`) count as "deviation logged" under
   criterion 2, with the C verdict recorded next to each case. The
   empty-iteration rule of step 3 is DEV-003's rule.
2. **Prover table modules: (A) plus a full-table spot check.** The main
   throughput runs use table modules restricted to the properties the
   S2 cases name (step 1). In addition, run 1 makes one bounded
   spot-check run of the property-heavy S2 cases with the full property
   table, in `why3 execute` and in the F\* normaliser, so that the
   verdict on question 1 is not optimistic. It is scheduled in run 1
   after WPs A-D and before WP H, and stays within run 1's caps (20-min
   cap per timed run, 4-hour run). If it would exceed them, it is
   recorded as not finished, with what was measured. Its result is
   reported in the `m2-throughput` entry.

## Maintainer decisions after run 1

Given on 2026-11-24 on run 1's results and review, recorded on issue
#28 (https://github.com/tarides/maquizcoatl/issues/28#issuecomment-7136902494).
They apply from run 2 on and take precedence over step 3 and decision 1
above where they differ:

3. **DEV-003's normative form.** The form run 1 implemented, which
   compares only the backreferenced groups of the loop body, is the
   normative rule. The literal "every group of the loop body" form
   makes `a(b|)+d` (`upstream/test/test_utf8.c:1757`) exponential. A new
   entry of `spec/deviations.md` supersedes DEV-003: it states the
   implemented form, why the literal one was dropped, and the evidence
   for the observable equality, without claiming a proof.
4. **Empty iteration in a bounded loop: upstream's rule.**
   `upstream/src/regcomp.c:5681-5688` sets the empty check for every
   quantifier with `upper >= 1` whose body can be empty, bounded or
   not, and the plain check leaves the loop even below `lower`. Stack G
   and the provers follow it, so `upstream/test/test_utf8.c:797`
   agrees with C. The same new entry corrects DEV-003's "Upstream
   behaviour" paragraph, which says "an unbounded loop".
5. **`\x{..}` / `\o{..}` code point lists** (46 cases): in S2 from run
   2. A list is a literal string; inside a class, a set of code points
   and ranges. Stack G's parser accepts them and the case files are
   regenerated, so every row's counts change from run 2 on; run 2
   reruns the agreement of stack G, Why3 and F\* (untimed) on the
   updated S2 and records it as a new entry.
6. **Runs 2 and 3** are launched one after the other: run 3 starts when
   run 2 and its review are done.
7. **Why3 bug report**: tracked in issue #36; the maintainer handles it
   in a separate session (WP H's draft stays as recorded).

Also in run 2, without a decision: the nested-interval product rule of
`g/g2.ml:527` has no upstream source and is removed (the lookbehind
length check then gives `upstream/test/test_utf8.c:1461` C's -122), and
the review's small follow-ups (ctype list wording, "Eval s" column
label, a milestone 2 line in `provenance.sh`) go in a corrections entry.

## Risks

- **Case folding is the hardest part.** Oniguruma expands
  case-insensitive strings at compile time, with limits on
  multi-character folds (for example inside classes and across
  string-node boundaries). A semantic statement may disagree with it
  on some cases. Each disagreement is fixed or logged as a deviation
  with its reason. The agreement counts show how many cases are
  affected. Bug-for-bug compatibility is a non-goal (CLAUDE.md).
- **Lookbehind order and captures.** Captures inside lookbehind and
  the try order of variable-length branches may differ from
  Oniguruma. The same fix-or-log rule applies.
- **Interpreted modes may hit the cap.** S2 has about 9 times more
  cases and a larger semantics. If `why3 execute` or the F\*
  normaliser falls under the bar, that is the answer to question 1,
  not a failure. The 20-minute cap and the no-repeat rule keep run 1
  inside its budget.
- **Why3 table and case constants.** `why3 execute` spent minutes and
  14 GB loading experiment #7's table. The fold table (about 1,500
  entries) is emitted as a dispatch function, not a list constant, and
  its load cost is in Q0, measured and reported.
- **Tables restricted in the provers.** The prover table modules hold
  only the properties the cases use, while stack G and the C library
  use the full table. This changes neither agreement nor `T_spec`
  (tables excluded), but in-prover throughput may be optimistic for
  property-heavy patterns. The restriction and its size are reported.
- **`T_spec` may still settle nothing.** Milestone 1's targets need
  `T_spec` to grow 27x (Why3 to C) to 101x (F\*/Pulse). The S2
  semantics is perhaps 3-6 times milestone 1's. The likely outcome is
  that the nine targets stay open with smaller ratios. That is a valid
  answer under Decision 5 and is reported as such.
- **Session effort.** The report estimates 1-3 weeks per tool. Runs
  are therefore separated by engineering time, and the maintainer
  decides whether to launch runs 2 and 3.
- **The parser stays in OCaml.** As in milestone 1, the provers get
  stack G's AST, so the `e` cases and the syntax differences between
  Oniguruma, Perl_NG and Ruby are checked only in stack G. This is
  stated in the agreement entry.
- **Load and shared host.** Other accounts' processes on the bench host
  are ignored, apart from the CPU-set check. Heavy load pauses timing
  rather than being averaged in.
- **Leaking host details.** Raw outputs pass a redaction check before
  they are committed. The host is named only as "the bench host", and
  its paths are written `<bench-workdir>/...`.
