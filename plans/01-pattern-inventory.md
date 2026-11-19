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
only. jq: `tests/*.test` and the manual. PHP: php-src
`ext/mbstring/tests/*.phpt` and the PHP manual (php/doc-en) examples. No
GitHub code search, no API token.

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
  unescaping, tabulation.
- Node.js 22 LTS with npm 9 — running vscode-textmate and
  vscode-oniguruma (pinned npm versions, matching the pinned commits) to
  replay the colorize fixtures.
- git 2.53 — sparse, shallow checkouts.
- jq and PHP are built from pinned release tarballs (pre-generated
  `configure`, so no extra autotools or bison/re2c dependency), linked
  against the stock upstream build.
- tree-sitter with the tree-sitter-php grammar (both actively
  maintained), via its Python binding, for PHP string-literal extraction;
  fallback: a small hand-written PHP string-literal lexer.

## Approach

1. **Pin the sources** (about 15 min). Shallow/sparse checkouts under
   `<workdir>/exp01/src/`: microsoft/vscode (`extensions/` only, via
   `git sparse-checkout`), microsoft/vscode-textmate,
   microsoft/vscode-oniguruma, jqlang/jq, php/php-src
   (`ext/mbstring/` only), php/doc-en (`reference/mbstring/` only).
   Record in `sources.json`: repository, commit, licence, retrieval
   date. For each VS Code grammar, take upstream repository, commit and
   licence from `extensions/<name>/cgmanifest.json` (criterion 1).

2. **Confirm the host compile configurations** (about 15 min). Read and
   cite, at the pinned commits: vscode-textmate's `OnigScanner` call and
   its `RegExpSource` rewriting of `\A`/`\G` and of back-references in
   `end`/`while`; vscode-oniguruma `src/onig.cc` (`createOnigRegExp`);
   jq `src/builtin.c` (`f_match`); php-src `ext/mbstring/php_mbregex.c`.
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
     from `tests/*.test` and the manual (`docs/content/manual/`); jq
     string unescaping; interpolated or computed arguments are
     `non-literal`.
   - PHP: arguments of `mb_ereg`, `mb_eregi` (adds `IGNORECASE`),
     `mb_ereg_replace`, `mb_eregi_replace`, `mb_ereg_replace_callback`,
     `mb_split`, `mb_ereg_match`, `mb_ereg_search_init` and the
     `mb_ereg_search*` family, plus option strings and preceding
     `mb_regex_encoding()` / `mb_regex_set_options()` calls in the same
     file; single- and double-quoted string unescaping; anything else
     `non-literal`.
   Deduplicate into distinct triples while keeping occurrence counts.

4. **Classification build** (about 20 min). Two out-of-tree builds of
   upstream `f95747b` with `-j4`:
   - *stock*: `cmake -S upstream -B <workdir>/exp01/build/onig`; used for
     criterion 2 (compile success or error code for every triple);
   - *instrumented*: a copy of `upstream/src` in
     `<workdir>/exp01/build/onig-instr/` with a small patch, kept in the
     repo as `experiments/01-pattern-inventory/instrument.patch`, that
     exports per-pattern token counters from `fetch_token` /
     `fetch_token_cc` (possessive repeats, intervals, `TK_CHAR_PROPERTY`,
     absent group openers) and a multi-character-fold flag from the
     compile step. `upstream/` itself is never edited. The classifier
     (`classify.c`) links against the instrumented library and its
     internal headers, calls `onig_new`, then walks `reg`'s parse tree
     via `onig_parse_tree` with the same arguments. A consistency check
     asserts that stock and instrumented builds accept exactly the same
     triples with the same error codes.

5. **Column definitions** (criterion 3). Each column is a count of
   triples for which the fact holds:

   | Column | Defining fact |
   |---|---|
   | captures | an `ND_BAG` with `BAG_MEMORY` |
   | named groups | `BAG_MEMORY` with `ND_ST_NAMED_GROUP` |
   | backreferences | an `ND_BACKREF` node (numbered or named, any level) |
   | lookahead | `ND_ANCHOR` with `ANCR_PREC_READ` or `ANCR_PREC_READ_NOT` |
   | lookbehind | `ND_ANCHOR` with `ANCR_LOOK_BEHIND` or `ANCR_LOOK_BEHIND_NOT` |
   | atomic groups | `BAG_STOP_BACKTRACK` nodes beyond those produced by possessive tokens |
   | possessive quantifiers | token counter: `TK_REPEAT`/`TK_INTERVAL` with the possessive flag set |
   | bounded repetition | token counter: `TK_INTERVAL` with a finite upper bound |
   | subexpression calls | an `ND_CALL` node |
   | absent operator | token counter: `(?~` group opener |
   | conditionals | `BAG_IF_ELSE` |
   | callouts | `ND_GIMMICK` with `GIMMICK_CALLOUT` (pattern callouts only) |
   | Unicode properties | token counter: `TK_CHAR_PROPERTY` (`\p{..}`, `\P{..}`, `\p{^..}`) |
   | case-insensitive | `ONIG_OPTION_IGNORECASE` in the call options, or a `BAG_OPTION` setting it |
   | multi-character case folding | compile fact: a literal or class compiled under `IGNORECASE` has a fold item with more than one code point, or a multi-character sequence folding to one, under the triple's encoding |

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
   `<workdir>`) that logs `onig_new` arguments and every
   `onig_search`/`onig_match` (pattern id, subject, start offset, range)
   to a file, for the native hosts:
   - VS Code: a Node script loads each grammar with the pinned
     vscode-textmate and vscode-oniguruma and tokenises every file under
     `extensions/*/test/colorize-fixtures` line by line; a JS wrapper
     around `OnigScanner`/`findNextMatchSync` logs the patterns, strings
     and start positions (the WASM build cannot be preloaded);
   - jq: run the jq built against the stock upstream library on its own
     `tests/*.test` cases with the shim;
   - PHP: build `php` CLI from the pinned release tarball with
     `--disable-all --enable-mbstring`, run `ext/mbstring/tests/*.phpt`
     with the shim.
   The captured triples are also checked against step 3: triples seen
   at run time but missed statically (computed patterns) are added as
   `dynamic-only`. Workloads are written in one fixed JSONL format
   (`workloads/<source>.jsonl`: triple, subject, start, range, expected
   result from the stock build) with `fetch.sh` and `build.sh` that
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
- **vscode-textmate rewriting.** `\A`/`\G` handling and `begin`-capture
  substitution change the compiled string at run time. Mitigation: static
  triples keep the grammar text; dynamic capture records what was
  actually compiled; both are reported.
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
