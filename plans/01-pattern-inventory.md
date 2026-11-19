# Plan: experiment #1, pattern inventory

Issue: https://github.com/tarides/maquizcoatl/issues/5 (the issue body is
the reference for scope, inputs and done-criteria; this plan says how).
Source: maintainer's state-of-the-art report, section "Experiments before
deciding": https://claude.ai/artifact/8w6PVuiTsLCKpugpCowMHc

## Objective

Collect the (pattern, flags, encoding) triples that Oniguruma's main hosts
compile (VS Code TextMate grammars, jq, PHP mbstring), classify them with
upstream's own parser and compiler at `f95747b`, and package them with
subjects as workloads. The results decide the first verified subset, the
share of patterns per ReDoS tier, and whether subexpression calls, pattern
callouts and the absent operator can wait.

Corpus scope is decision (a) on the issue: the hosts' own repositories
only. jq: `tests/jq.test`, `tests/onig.test`, `tests/optional.test`
and one manual version, `docs/content/manual/manual.yml` (the
development manual of the pinned release; the versioned copies under
`docs/content/manual/v*/` and the generated `tests/man.test` /
`tests/manonig.test` are excluded so that one example is not counted
several times). PHP: php-src `ext/mbstring/tests/*.phpt` and the PHP
manual (php/doc-en) examples. No GitHub code search, no API token.

## Where things live

- `<workdir>` is a directory outside the repository. Clones, builds,
  toolchains, logs and intermediate files go under it, never in the repo
  and never in `upstream/`:
  - `<workdir>/exp01/src/` — pinned clones and release tarballs;
  - `<workdir>/exp01/build/onig/` — out-of-tree upstream build (stock);
  - `<workdir>/exp01/build/onig-instr/` — instrumented copy (see step 4);
  - `<workdir>/exp01/build/{jq,php}/` — host builds;
  - `<workdir>/exp01/out/` — raw extraction and capture output.
- In the repository (branch `exp/01-pattern-inventory`):
  - `experiments/01-pattern-inventory/` — scripts, the instrumentation
    patch, `sources.json` (pins and licences), the extracted triples
    (`patterns/*.jsonl`), the classification tables, and `workloads/`;
  - `lab/notebook.md` and `lab/results/` — the lab notebook.

## Tools and versions

All actively maintained; versions are those installed now and are
recorded again in the notebook's provenance at run time.

- GCC 15.2, CMake 4.2, GNU Make 4.4 — upstream and host builds.
- Python 3.14 (standard library only, run with `-I`) — extraction,
  unescaping, tabulation. No third-party Python package is used.
- Node.js 22 LTS with npm 9 — running vscode-textmate and
  vscode-oniguruma (pinned npm versions, matching the pinned commits) to
  replay the colorize fixtures. vscode-oniguruma 2.1.0 bundles
  Oniguruma v6.9.8 (`08d3611`), not `f95747b`; this is recorded in
  `sources.json` and in the workloads notebook entry, and expected
  results in the workloads always come from the stock `f95747b` build.
- git 2.53 — sparse, shallow checkouts.
- jq and PHP are built from pinned release tarballs (pre-generated
  `configure`, so no extra autotools or bison/re2c dependency), linked
  against the stock upstream build. Each is pinned once, in step 1:
  jq 1.8.2 (tag `jq-1.8.2`) and PHP 8.5.12 (tag `php-8.5.12`) as of
  writing; `sources.json` records the tag, the commit it points to, the
  tarball URL and its sha256. The static corpora of step 3 are read from
  the extracted tarball trees, so the extracted and the built code are
  the same version. php/doc-en has no releases and is pinned by commit.
- PHP string-literal extraction uses a small hand-written lexer in
  Python (standard library): single- and double-quoted strings,
  heredoc and nowdoc, comments, and `?>`/`<?php` boundaries. tree-sitter
  is not installed and is not needed. Heredoc and nowdoc bodies are
  unescaped like double- and single-quoted strings respectively; a
  heredoc containing interpolation is `non-literal`.

## Approach

1. **Pin the sources** (about 15 min). Shallow/sparse checkouts under
   `<workdir>/exp01/src/`: microsoft/vscode (`extensions/` only, via
   `git sparse-checkout`), microsoft/vscode-textmate,
   microsoft/vscode-oniguruma, jqlang/jq, php/php-src
   (`ext/mbstring/` only), php/doc-en (`reference/mbstring/` only).
   jq and PHP are not cloned: download the pinned release tarballs
   (`jq-1.8.2.tar.gz` from the GitHub release, `php-8.5.12.tar.xz` from
   php.net), check and record their sha256 and the tag-to-commit
   mapping, and extract them under `<workdir>/exp01/src/`. Record in
   `sources.json`: repository, commit (and tarball, sha256), licence,
   retrieval date. For each VS Code grammar, take upstream repository, commit and
   licence from `extensions/<name>/cgmanifest.json` (criterion 1).

2. **Confirm the host compile configurations** (about 15 min). Read and
   cite, at the pinned commits: vscode-textmate's `OnigScanner` call and
   its `RegExpSource` rewriting of `\A`/`\G` and of back-references in
   `end`/`while`, and its unconditional rewrite of `\z` into
   `$(?!\n)(?<!\n)`; vscode-oniguruma `src/onig.cc` (`createOnigRegExp`,
   the `OnigScanner` regset and the `FindOption` flags);
   jq `src/builtin.c` (`f_match`); php-src `ext/mbstring/php_mbregex.c`
   (including the `OnigMatchParam` limits it sets and whether they differ
   from upstream defaults).
   Write the resulting (syntax, options, encoding) mapping per host into
   `sources.json`. Any divergence from the issue's Inputs section is
   reported on the issue before step 3.

3. **Static extraction** (about 30 min). One script per host, output
   one JSONL record per occurrence: source, file, line, raw text,
   unescaped pattern, flags/options, encoding, syntax, and a status
   (`literal`, `non-literal`, `host-substituted`).
   - TextMate: every `match`, `begin`, `end`, `while` string of each
     `*.tmLanguage.json`, JSON-unescaped. `end`/`while` patterns with
     `\N` references to `begin` captures are marked `host-substituted`.
   - jq: string-literal first arguments of `test`, `match`, `capture`,
     `scan`, `split/2`, `splits`, `sub`, `gsub`, with their flag literal,
     from the three test files and the one manual named under Objective,
     read from the extracted release tarball; jq
     string unescaping; interpolated or computed arguments are
     `non-literal`.
   - PHP: arguments of `mb_ereg`, `mb_eregi` (adds `IGNORECASE`),
     `mb_ereg_replace`, `mb_eregi_replace`, `mb_ereg_replace_callback`,
     `mb_split`, `mb_ereg_match`, `mb_ereg_search_init` and the
     `mb_ereg_search*` family, plus option strings and preceding
     `mb_regex_encoding()` / `mb_regex_set_options()` calls in the same
     file; single- and double-quoted string, heredoc and nowdoc
     unescaping (see Tools); anything else `non-literal`.
   Deduplicate into distinct triples while keeping occurrence counts.

4. **Classification build** (about 20 min). Two out-of-tree builds of
   upstream `f95747b` with `-j4`:
   - *stock*: `cmake -S upstream -B <workdir>/exp01/build/onig
     -DCMAKE_INSTALL_PREFIX=<workdir>/exp01/prefix` (shared library:
     `BUILD_SHARED_LIBS` is `ON` by default, which the `LD_PRELOAD` shim
     of step 7 requires), `make -j4`, then
     `cmake --install <workdir>/exp01/build/onig`. The installed prefix
     provides `libonig.so` and `oniguruma.pc`, which jq
     (`--with-oniguruma=<prefix>`) and PHP mbregex (through
     `PKG_CONFIG_PATH`) link against. Used for criterion 2 (compile
     success or error code for every triple);
   - *instrumented*: a copy of `upstream/src` in
     `<workdir>/exp01/build/onig-instr/` with a small patch, kept in the
     repo as `experiments/01-pattern-inventory/instrument.patch`, that
     exports per-pattern counters: from `fetch_token` / `fetch_token_cc`
     (possessive repeats, intervals, `TK_CHAR_PROPERTY`); from `prs_bag`
     (absent-group openers, `upstream/src/regparse.c:7983-7984`, and
     atomic-group openers `(?>`, `upstream/src/regparse.c:7924-7925`);
     and a multi-character-fold flag (see column definitions). The patch
     is a derivative of Oniguruma's code: it keeps Oniguruma's copyright
     notice and the BSD-2-Clause conditions (in its header and in
     `sources.json`). `upstream/` itself is never edited. A consistency
     check asserts that stock and instrumented builds accept exactly the
     same triples with the same error codes.
   - *classifier* (`classify.c`) links against the instrumented library
     and its internal headers. Per triple, it first calls `onig_new`
     (criterion 2 result and the counters). Then, for the tree walk, it
     uses a fresh `regex_t` initialised with `onig_reg_init` (same
     options, case-fold flag, encoding and syntax), its own `ParseEnv`,
     calls `onig_parse_tree` (`upstream/src/regparse.c:9428`), walks the
     tree, and frees it with `onig_node_free` before `onig_free_body` on
     the scratch `regex_t`. The tree is the parser's output, before
     `reduce_string_list` and `tune_tree` (`upstream/src/regcomp.c:7408`
     onwards); column definitions below are stated against that
     pre-rewrite tree.

5. **Column definitions** (criterion 3). Each column is a count of
   triples for which the fact holds:

   | Column | Defining fact |
   |---|---|
   | captures | an `ND_BAG` with `BAG_MEMORY` that survives the capture rule below |
   | named groups | `BAG_MEMORY` with `ND_ST_NAMED_GROUP` |
   | backreferences | an `ND_BACKREF` node (numbered or named, any level) |
   | lookahead | `ND_ANCHOR` with `ANCR_PREC_READ` or `ANCR_PREC_READ_NOT` |
   | lookbehind | `ND_ANCHOR` with `ANCR_LOOK_BEHIND` or `ANCR_LOOK_BEHIND_NOT` |
   | atomic groups | parser counter: `(?>` opener in `prs_bag` (`regparse.c:7924-7925`) |
   | possessive quantifiers | token counter: `TK_REPEAT`/`TK_INTERVAL` with the possessive flag set |
   | bounded repetition | token counter: `TK_INTERVAL` with a finite upper bound |
   | subexpression calls | an `ND_CALL` node |
   | absent operator | parser counter: `(?~` opener in `prs_bag` (`regparse.c:7983-7984`) |
   | conditionals | `BAG_IF_ELSE` |
   | callouts | `ND_GIMMICK` with `GIMMICK_CALLOUT` (pattern callouts, including built-ins such as `(*FAIL)` and `(*SKIP)`) |
   | Unicode properties | token counter: `TK_CHAR_PROPERTY` (`\p{..}`, `\P{..}`, `\p{^..}`) |
   | case-insensitive | `ONIG_OPTION_IGNORECASE` in the call options, or a `BAG_OPTION` setting it |
   | multi-character case folding | flag set by the patch when, under `IGNORECASE` and with `INTERNAL_ONIGENC_CASE_FOLD_MULTI_CHAR` still in the case-fold flag, a multi-code-point fold is applied, either in a class by the parser (`i_apply_case_fold`, `regparse.c:8740`, `to_len > 1`) or in a string by the compiler (`unravel_case_fold_string`) |

   Column notes:
   - *Captures.* `onig_parse_tree` returns the tree before
     `disable_noname_group_capture` (`upstream/src/regcomp.c:7410-7416`),
     so the classifier applies the same rule itself: when the pattern has
     named groups, the syntax has `ONIG_SYN_CAPTURE_ONLY_NAMED_GROUP` and
     the options do not include `ONIG_OPTION_CAPTURE_GROUP`, unnamed
     groups are not captures. This matters for PHP, which does not pass
     `ONIG_OPTION_CAPTURE_GROUP`.
   - *Atomic groups.* Counted at the `(?>` opener, not by
     `BAG_STOP_BACKTRACK` nodes: possessive quantifiers
     (`upstream/src/regparse.c:9231-9233`) and the absent-operator
     machinery (`upstream/src/regparse.c:2979`, `:3042`, `:3360`) also
     create such nodes. (The issue body's citation for the possessive
     case was corrected from `regparse.c:3041-3046` to
     `regparse.c:9231-9233`.)
   - *Possessive quantifiers.* Includes `{n,m}` with `n > m`, which
     Oniguruma and Ruby syntaxes read as a possessive interval
     (`upstream/src/regparse.c:4712-4721`).
   - *Callouts.* `GIMMICK_CALLOUT` only exists under `USE_CALLOUT`
     (enabled in the default build, checked in `regint.h` at run time).
   - *Multi-character case folding.* `ONIG_OPTION_IGNORECASE_IS_ASCII`
     clears `INTERNAL_ONIGENC_CASE_FOLD_MULTI_CHAR`
     (`upstream/src/regparse.c:7866-7871`); such triples are
     case-insensitive but never multi-character folding.

   Syntax flavour and encoding columns come from the triple. Node and
   token names are from `upstream/src/regparse.h:39-67`,
   `upstream/src/regparse.c:4553-4585` and `upstream/src/regint.h:468-471`.

6. **ReDoS tiers** (criterion 4). A compiled triple is in the fuel tier
   if any of backreferences, subexpression calls, absent operator,
   conditionals or callouts is present; otherwise in the linear tier
   (regular core, lookarounds including lookbehind, atomic/possessive,
   bounded repetition). Patterns that fail to compile are reported
   apart. Shares per source and overall.

7. **Subjects and workloads** (about 60 min; criterion 6). Dynamic
   capture through an `LD_PRELOAD` shim (in the repo, built in
   `<workdir>`, interposing on the shared `libonig.so` of step 4) that
   logs `onig_new` arguments and every `onig_search`, `onig_match`,
   `onig_search_with_param` and `onig_match_with_param` call (pattern
   id, subject, start offset, range, options) to a file; the `_with_param`
   variants must be interposed separately, because PHP calls them and
   upstream `onig_search` is an expanded copy rather than a wrapper
   (`upstream/src/regexec.c:5659`). Non-default `OnigMatchParam` limits
   (retry, stack, subexp-call limits set by PHP) are logged with the
   call. Hosts:
   - VS Code: a Node script loads each grammar with the pinned
     vscode-textmate and vscode-oniguruma and tokenises every file under
     `extensions/*/test/colorize-fixtures` line by line; a JS wrapper
     around `OnigScanner`/`findNextMatchSync` logs the scanner's
     patterns (its membership, in order), the string, the start
     position, the search-time `FindOption` flags and the winning
     pattern index (the WASM build cannot be preloaded). vscode-oniguruma
     searches a scanner with `onig_regset_search` and
     `ONIG_REGSET_POSITION_LEAD` for strings shorter than 1000 bytes, so
     the workload records the scanner as a regset, not as independent
     patterns;
   - jq: run the jq built against the stock upstream library on its own
     `tests/*.test` cases with the shim;
   - PHP: build `php` CLI from the pinned release tarball with
     `--disable-all --enable-mbstring`, run `ext/mbstring/tests/*.phpt`
     with the shim.
   The captured triples are also checked against step 3: triples seen
   at run time but missed statically (computed patterns) are added as
   `dynamic-only`. Workloads are written in one fixed JSONL format
   (`workloads/<source>.jsonl`: triple, subject, start, range,
   search-time options, match-param limits when not default, and for VS
   Code the scanner id, its member triples, the regset lead mode and the
   winning index; expected result from the stock build) with `fetch.sh`
   and `build.sh` that
   recreate them from the pins. Workloads are published first (separate
   commit, notebook entry) so #11 is not blocked on criteria 3-5.

8. **Tables and proposal** (about 20 min; criteria 3-5). Generate the
   per-source tables, the tier shares, and a first subset (encodings,
   flavours, features) with the share of triples it covers, plus a
   yes/no with numbers for deferring subexpression calls, pattern
   callouts and the absent operator. State next to the tables that
   decision (a) limits jq and PHP to the hosts' own repositories, which
   under-represents real-world use.

9. **Record and report** (criterion 7). Notebook entries (below), push,
   summary comment on the issue, then open the PR.

## Machine budget

At most 4 parallel jobs (`make -j4`, at most 4 concurrent extraction or
replay processes) and at most 3 hours of wall clock for the whole run.
The step estimates above add up to about 3 hours, so the first milestone
is defined to fit with margin:

- **Milestone 1 (this run):** steps 1-6 and 8 for all three sources, and
  step 7 for VS Code and jq. Disk use under 3 GB in `<workdir>` (about
  23 GB free on the shared disk).
- **Follow-up, only if milestone 1 overruns:** PHP dynamic capture (the
  php build and `.phpt` replay). In that case PHP subjects in milestone 1
  are the literal subject arguments found statically in the `.phpt`
  files, marked as such in the workload.

If any step exceeds twice its estimate, stop, record where it stands in
the notebook and report on the issue instead of continuing.

## Lab notebook

Using the lab-notebook skill: `lab/notebook.md` (index, one line per
recorded run) and `lab/results/<date>-exp-01-<topic>.md` (append-only).
Planned entries, each with provenance (commits of the repo and of every
pinned source, machine CPU/RAM, kernel, compiler and flags, exact
commands, durations, exit status):

1. `corpus` — sources, pins, licences, occurrence and distinct-triple
   counts per source and per status (criterion 1).
2. `workloads` — workload format, counts of (triple, subject) items per
   source, capture method, `dynamic-only` triples (criterion 6).
3. `compile-and-classify` — compile results and failure list, the
   per-source feature tables, ReDoS tier shares, the subset proposal and
   the deferral answers (criteria 2-5).

Exploratory or confirming re-runs are not recorded. Extraction and
classification scripts print to stdout or `<workdir>`; they never write
into `lab/results/`.

## Outputs

- `experiments/01-pattern-inventory/`: `sources.json`, extraction
  scripts, `instrument.patch`, `classify.c`, the `LD_PRELOAD` shim, the
  Node replay script, `patterns/*.jsonl`, `tables/*.md` (and CSV),
  `workloads/` with `fetch.sh` / `build.sh`.
- Three lab notebook entries.
- A summary comment on issue #5 and a PR from `exp/01-pattern-inventory`.

## Done-criteria (from the issue)

1. Corpora collected and pinned: source, commit/version, licence, pattern
   count per source, recorded in the repo (patterns themselves stored,
   or a reproducible script to fetch them where licences forbid
   redistribution).
2. Every collected pattern compiled with upstream `f95747b` under the
   syntax and encoding its host uses; compile failures counted and
   listed.
3. A table per source with: count and share of patterns using each
   feature (captures, named groups, backreferences, lookahead,
   lookbehind, atomic groups, possessive quantifiers, bounded
   repetition, subexpression calls, absent operator, conditionals,
   callouts, Unicode properties, case-insensitive matching,
   multi-character case folding); syntax flavours; encodings.
4. Share of patterns in each ReDoS tier (as defined in the report's
   ReDoS section), per source and overall.
5. A proposed first subset (encodings, flavours, features) with the
   share of collected patterns it covers, and a yes/no with numbers on
   deferring recursion, callouts and the absent operator. The callouts
   answer covers pattern callouts only (`(*name)` and `(?{...})`, syntax
   flags `ONIG_SYN_OP2_ASTERISK_CALLOUT_NAME` /
   `ONIG_SYN_OP2_QMARK_BRACE_CALLOUT_CONTENTS`, set in the Oniguruma,
   Ruby, Perl and Perl_NG syntaxes); API-level callouts are invisible to
   a pattern inventory.
6. Workloads packaged for #11/#12: patterns plus representative subjects
   for each source, with a fixed format and fetch/build script.
7. Results recorded in the lab notebook; summary comment on this issue.

## Risks

- **Small jq and PHP corpora.** Decision (a) keeps them to the hosts'
  own tests and manuals, which exercise edge cases more than typical
  use. Mitigation: report per-source shares, never pool them silently
  with VS Code; state the bias next to the tables.
- **Licences.** Some VS Code grammars may come from repositories whose
  licence forbids redistribution, and php/doc-en is CC-BY. Mitigation:
  `sources.json` records each licence; patterns from a source that does
  not permit redistribution are replaced by the fetch script.
- **vscode-textmate rewriting.** `\A`/`\G` handling, `begin`-capture
  substitution and the unconditional rewrite of `\z` into
  `$(?!\n)(?<!\n)` change the compiled string at run time. Mitigation:
  static triples keep the grammar text; dynamic capture records what was
  actually compiled; both are reported. The criterion 3 tables for VS
  Code are computed on the compiled form (what Oniguruma actually sees),
  with the grammar-text form given alongside; so a `\z` in a grammar
  counts as lookahead and lookbehind in the main table.
- **Instrumentation drift.** The patch could change parser behaviour.
  Mitigation: the stock-vs-instrumented consistency check in step 4; the
  patch only adds counters.
- **Upstream crashes on some pattern.** A crash is itself a finding
  (bug-free goal). Mitigation: compile each triple in a child process
  with a timeout; record crashes and timeouts as their own category and
  in the notebook.
- **Disk pressure.** The shared disk has about 23 GB free. Mitigation:
  sparse/shallow checkouts, release tarballs, a 3 GB cap, cleanup of
  build trees after the run (pins make them reproducible).
- **Network.** All sources come from GitHub and php.net release
  tarballs; a failure in step 1 stops the run before any build.
