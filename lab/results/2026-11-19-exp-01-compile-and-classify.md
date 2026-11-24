# exp-01 compile-and-classify: features, ReDoS tiers, first subset

## What

Every distinct triple of the corpus (entry `2026-11-19-exp-01-corpus.md`)
compiled with upstream Oniguruma `f95747b` under its host's syntax,
options and encoding, then classified with upstream's own parser: 15
feature columns, syntax flavour, encoding, ReDoS tier. From these, a
proposed first verified subset and the answers on deferring subexpression
calls, pattern callouts and the absent operator. Full tables:
`experiments/01-pattern-inventory/tables/tables.md` (CSV:
`tables/features.csv`; per-triple data: `patterns/*.jsonl`).

## Why

Criteria 2-5 of issue #5. The report's open questions wait on these
numbers: which encodings, flavours and features the first verified subset
needs, what share of real patterns falls in the linear vs the fuel ReDoS
tier, and whether recursion, callouts and the absent operator can wait.

## Provenance

- Repository: branch `exp/01-pattern-inventory`; `classify.c`,
  `instrument.patch`, `scripts/inventory.py`, `scripts/tables.py` as of
  the commit adding this file (first results in `9484a70`, tables
  regenerated with the dynamic-only section in `2b17634`).
- Oniguruma `f95747b462de672b6f8dbdeb478245ddf061ca53`, two out-of-tree
  builds with GCC 15.2.0, CMake 4.2.3, `CMAKE_BUILD_TYPE=Release`, `make -j4`:
  *stock* (shared library) and *instrumented* (static library from a copy
  of `upstream/src` with `instrument.patch`: token counters for
  possessive/interval/property tokens, `(?>` and `(?~` opener counters in
  `prs_bag`, a multi-character-fold flag in `i_apply_case_fold` and
  `unravel_case_fold_string`). The instrumented build passes upstream's
  `test_utf8` (1554), `test_back` (1225), `test_syntax` (221) and
  `test_options` (47) with no failure.
- Machine: 12th Gen Intel Core i7-1260P, 15 GiB RAM, Ubuntu 26.04.1 LTS,
  Linux 7.0.0-43-generic. Python 3.14.4.
- Run by Claude Code (Opus 5.5) in the experiment pipeline, 2026-11-19.

Commands (from `<workdir>`):

    python3 -I scripts/inventory.py patterns bin/classify bin/classify-stock out/{vscode,jq,php}.occ.jsonl   # 6 s, exit 0
    python3 -I scripts/dynamic_only.py patterns bin/classify out/workloads-full
    python3 -I scripts/tables.py patterns tables > tables/summary.json

Method (plan step 4-5): per triple, a forked child (10 s alarm) calls
`onig_new` (compile result, token and parser counters, fold flag), then
`onig_parse_tree` on a scratch `regex_t` and walks the tree before
`reduce_string_list`/`tune_tree`. Captures apply the
`ONIG_SYN_CAPTURE_ONLY_NAMED_GROUP` rule themselves; backreferences exclude
the checker node that is the condition of `(?(<name>)…)`.

## Data

### Criterion 2: compile results

| Source | triples | compile | fail | crash / timeout | stock vs instrumented mismatches |
|---|---:|---:|---:|---:|---:|
| VS Code (compiled form) | 5,870 | 5,865 | 5 | 0 | 0 |
| VS Code (grammar text) | 5,888 | 5,833 | 55 | 0 | 0 |
| jq | 44 | 44 | 0 | 0 | 0 |
| PHP | 73 | 66 | 7 | 0 | 0 |

Failures: VS Code, 5 patterns of `log.tmLanguage.json` of the form
`(?<=^[\s\d\p]*)\bE\b` (-223, invalid character property name; the
Oniguruma bundled with vscode-oniguruma 1.7.0 accepts them). Grammar
text: the same 5 plus 50 `end`/`while` patterns whose `\N` refer to
`begin` captures (invalid as Oniguruma backreferences, substituted by
vscode-textmate before compiling). PHP: 6 bug-regression tests with
invalid code points (-400) and `(?<0>a)` (-215). Lists in `tables.md`.

### Criterion 3: features (triples that compile)

| Feature | VS Code | jq | PHP |
|---|---:|---:|---:|
| captures | 3831 (65.3%) | 19 (43.2%) | 21 (31.8%) |
| named groups | 90 (1.5%) | 13 (29.5%) | 8 (12.1%) |
| backreferences | 95 (1.6%) | 0 (0.0%) | 3 (4.5%) |
| lookahead | 2425 (41.3%) | 1 (2.3%) | 0 (0.0%) |
| lookbehind | 1419 (24.2%) | 0 (0.0%) | 0 (0.0%) |
| atomic groups | 245 (4.2%) | 0 (0.0%) | 0 (0.0%) |
| possessive | 430 (7.3%) | 0 (0.0%) | 0 (0.0%) |
| bounded repetition | 372 (6.3%) | 0 (0.0%) | 2 (3.0%) |
| subexp calls | 120 (2.0%) | 0 (0.0%) | 0 (0.0%) |
| absent | 2 (0.0%) | 0 (0.0%) | 0 (0.0%) |
| conditionals | 2 (0.0%) | 0 (0.0%) | 0 (0.0%) |
| callouts | 0 (0.0%) | 0 (0.0%) | 0 (0.0%) |
| unicode properties | 137 (2.3%) | 0 (0.0%) | 0 (0.0%) |
| case insensitive | 613 (10.5%) | 6 (13.6%) | 7 (10.6%) |
| multichar casefold | 320 (5.5%) | 0 (0.0%) | 1 (1.5%) |

Flavours and encodings: VS Code Oniguruma syntax, UTF-8 (all); jq
Perl_NG, UTF-8 (all); PHP Ruby (72) and POSIX basic (1), UTF-8 (69),
EUC-JP (2), UTF-32BE (1), ISO-8859-1 (1).

### Criterion 4: ReDoS tiers

| Source | compiled | linear | fuel |
|---|---:|---:|---:|
| VS Code | 5865 | 5657 (96.5%) | 208 (3.5%) |
| jq | 44 | 44 (100.0%) | 0 (0.0%) |
| PHP | 66 | 63 (95.5%) | 3 (4.5%) |
| pooled | 5975 | 5764 (96.5%) | 211 (3.5%) |
| mean of per-source shares | | 97.3% | 2.7% |

Fuel tier drivers in VS Code: subexpression calls 120, backreferences 95,
absent 2, conditionals 2 (a triple can have several). Weighted by
occurrences, VS Code's linear share is 98.0%.

### Criterion 5: subsets and deferral

| Subset | VS Code | jq | PHP | pooled |
|---|---:|---:|---:|---:|
| S0: UTF-8; Oniguruma/Perl_NG/Ruby syntax; linear tier | 96.5% | 100.0% | 87.9% | 96.4% |
| S1: S0 without multi-character case folding | 91.1% | 100.0% | 86.4% | 91.1% |
| S2: S0 + backreferences | 97.9% | 100.0% | 92.4% | 97.9% |
| S3: S2 + subexpression calls, conditionals | 100.0% (5863/5865) | 100.0% | 92.4% | 99.9% |

Files with at least one triple using a feature (a grammar with one
unsupported pattern cannot be fully tokenised): subexpression calls in
18 of 82 VS Code grammars (cpp, csharp, go, json, latex, markdown-basics,
objective-c, php, powershell, razor, swift, yaml); conditionals in 3
(yaml); absent operator in 1 (csharp); pattern callouts in none. No jq or
PHP file uses any of the four.

## Analysis

**Proposed first subset: S2.** UTF-8; Oniguruma, Perl_NG and Ruby
syntaxes; the regular core with captures and named groups, lookahead and
lookbehind, atomic groups and possessive quantifiers, bounded repetition,
Unicode properties, case-insensitive matching including multi-character
folding, and backreferences. It covers 97.9% of compiled VS Code triples,
all of jq's and 92.4% of PHP's (pooled 97.9%). Multi-character folding
should stay in: dropping it costs 5.4 points for VS Code (S1), because
common ligature folds (`st`, `ff`, `ss`) and `\w` classes under `(?i)`
trigger it. PHP's remainder is the non-UTF-8 encodings (4 triples) and
the POSIX basic flavour (1).

**Deferral answers.**

- *Pattern callouts*: **yes, defer.** 0 triples in every source.
- *Absent operator*: **yes, defer.** 2 VS Code triples (0.03%), in one
  grammar (C#, multi-line comments); none in jq or PHP.
- *Subexpression calls (recursion)*: **yes for the first subset, no for
  VS Code parity.** 120 VS Code triples (2.0%), none in jq or PHP, but
  they sit in 18 of 82 grammars, including C++, C#, Go, JSON, Markdown,
  PHP, Swift and YAML. A drop-in for VS Code needs them soon after the
  first subset; conditionals (2 triples, YAML) go with them.

**ReDoS policy input.** About 96.5% of real triples (97.3% by per-host
mean) are in the linear tier; the fuel tier is driven by subexpression
calls and backreferences, almost entirely from VS Code grammars.

## Open questions

- Is the `\p]` rejection in `log.tmLanguage.json` a fix or a regression
  between the Oniguruma in vscode-oniguruma 1.7.0 and `f95747b`? The spec
  must decide, since a shipped grammar depends on it.
- jq and PHP corpora are small and test-oriented (decision (a)); their
  shares carry large uncertainty and say little about real use.
- The VS Code tables use the compiled form with empty begin-capture
  substitution. The 381 dynamic-only VS Code triples (`\A`/`\G` variants
  and real begin-capture substitutions) all compile, and 39 of them (10%)
  are in the fuel tier, mostly through subexpression calls (38): the
  scanner variants multiply the patterns of the grammars that use calls.
  They are reported apart in `tables.md`, not mixed into the shares above.
