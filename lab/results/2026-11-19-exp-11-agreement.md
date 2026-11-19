# exp-11 agreement: match results of six engine columns against Oniguruma

## What

Every engine column ran the `check` mode of its harness on the five
workloads converted from #1, and `agree.py` compared each column with
Oniguruma threaded (`f95747b`, the reference): compile status per
pattern, and the list of non-overlapping group-0 matches per (pattern,
subject) pair, enumerated with the same loop in every harness. Raw data:
`2026-11-19-exp-11-agreement.csv` (counts per engine and workload) and
`2026-11-19-exp-11-disagreements.csv` (one row per disagreeing pattern,
first differing subject, both match lists).

## Why

Criteria 2 (rejected and unsupported counts) and 3 (agreement with
Oniguruma, every disagreement listed and explained, disagreeing patterns
excluded from timing) of issue #2. The patterns each engine may be timed
on (`only/<engine>.<workload>.txt` in the run directory) come from here.

## Provenance

- Repository: branch `exp/11-perf-baselines` at `2551342` (harnesses as
  built in the builds entry; `agree.py` classification refined in
  `9ae515a` and re-run on the same raw check outputs).
- Workloads: #1's `experiments/01-pattern-inventory/workloads/data/` at
  `f64aa5feb6c3246cc614be1d329adadbb636779a` (branch
  `exp/01-pattern-inventory`, draft PR #15), the committed sample (VS Code:
  first 20 searches per scanner), converted by `prep_workloads.py`.
- Machine and toolchains: as in `2026-11-19-exp-11-builds.md` (blocksci
  bench host, AMD EPYC 7502P, Linux 6.8.0-100-generic). Check runs: 4 in
  parallel on CPUs 16-19 (nothing timed).
- Command: `run.sh r1 check` (2026-11-19 about 12:13 UTC), exit 0, 4 s.
- Oniguruma cross-check of #1's expected results (`onig_bench replay`,
  the original calls with their start, range and match parameters, VS Code
  scanners as leftmost-first over members): jq 217/217, php 269/269,
  php-legacy 152/152, vscode 9525/9525, vscode-subst 1738/1738 agree (run
  on the workstation build of the same harness; #1 records no region for
  the 4 `onig_match` calls, so only their return value is compared).

## Parameters

- Workloads (distinct pattern triples / subjects / (pattern, subject)
  pairs / subject bytes per pass): jq 44/45/64/450; php (UTF-8, Ruby
  syntax) 106/63/134/2,993; php-legacy (EUC-JP, Shift_JIS, ISO-8859-1,
  one POSIX_BASIC; Oniguruma-only by construction) 83/19/86/737; vscode
  3,861/2,397/106,636/3,819,249; vscode-subst (members whose pattern
  contains vscode-textmate's U+FFFF `\A`/`\G` substitution) 1,544/647/8,523/288,411.
  The vscode-subst pattern table also lists the 1,184 co-members of the
  substituted scanners; they have no pair there (their pairs are in vscode).
- All php and php-legacy calls carry PHP's match parameters (retry limit
  1,000,000, stack limit 100,000); `check` and the timed runs use each
  engine's defaults (Oniguruma retry limit 10,000,000), `replay` uses the
  recorded ones. No call has non-zero search options.
- Option translation (same for PCRE2, RE2, Rust, ocaml-re): IGNORECASE →
  caseless; EXTEND → extended (PCRE2, Rust; unsupported in RE2 and
  ocaml-re); Oniguruma MULTILINE → dot-all; effective SINGLELINE (option,
  or PERL_NG syntax default) → no multi-line, otherwise `^`/`$` at lines;
  FIND_NOT_EMPTY → `PCRE2_NOTEMPTY` (unsupported elsewhere). PCRE2 uses
  `PCRE2_UTF | PCRE2_UCP | PCRE2_MATCH_INVALID_UTF`; RE2 default options
  (max_mem 8 MiB, default); Rust `regex::bytes` with default size limits;
  ocaml-re `Re.Perl` on bytes.

## Raw data (counts)

Columns: accepted / unsupported syntax or feature (Oniguruma accepts) /
unsupported option, syntax or encoding / resource-limited / rejected like
the reference / disagreeing patterns / timed patterns.

| engine | jq | php | php-legacy | vscode | vscode-subst |
|---|---|---|---|---|---|
| onig-threaded | 44/0/0/0/0/–/44 | 106/0/0/0/0/–/106 | 83/0/0/0/0/–/83 | 3856/0/0/0/5/–/3856 | 1544/0/0/0/0/–/1544 |
| onig-switch | 44/0/0/0/0/0/44 | 106/0/0/0/0/0/106 | 83/0/0/0/0/0/83 | 3856/0/0/0/5/0/3856 | 1544/0/0/0/0/0/1544 |
| pcre2-interp | 44/0/0/0/0/0/44 | 104/2/0/0/0/2/102 | 0/0/83/0/0/0/0 | 3826/30/0/0/5/3/3823 | 1525/19/0/0/0/0/1525 |
| pcre2-jit | 44/0/0/0/0/0/44 | 104/2/0/0/0/2/102 | 0/0/83/0/0/0/0 | 3826/30/0/0/5/3/3823 | 1525/19/0/0/0/0/1525 |
| re2 | 39/1/4/0/0/1/38 | 99/4/3/0/0/20/79 | 0/0/83/0/0/0/0 | 1696/2160/0/0/5/12/1684 | 422/1122/0/0/0/0/422 |
| rust-regex | 41/1/2/0/0/0/41 | 100/6/0/0/0/8/92 | 0/0/83/0/0/0/0 | 1812/2044/0/0/5/14/1798 | 429/1115/0/0/0/0/429 |
| ocaml-re | 39/1/4/0/0/2/37 | 99/4/3/0/0/22/77 | 0/0/83/0/0/0/0 | 1481/2375/0/0/5/12/1469 | 440/1104/0/0/0/2/438 |

The 5 vscode patterns rejected by the reference are the `log.tmLanguage.json`
patterns with `\p]` that #1 found (`ONIGERR_INVALID_CHAR_PROPERTY_NAME`);
every other engine rejects them too.

No pattern was rejected by a resource limit (RE2 `max_mem`, Rust
`size_limit`, PCRE2 pattern size or JIT memory), all at their defaults.
Main rejection reasons (all workloads): RE2 `ErrorBadPerlOp` 2,697
(look-around, atomic groups, `\G`, …), `ErrorBadEscape` 394,
`ErrorRepeatOp` 187 (possessive quantifiers); Rust `regex` syntax errors
3,171; ocaml-re `Parse_error` 3,481; PCRE2 41 compile errors (codes 125,
108, 147, 150, 146, 167: Oniguruma-only escapes and constructs).

Disagreements (103 patterns; classes from `agree.py`'s heuristic, see
analysis):

| engine | class | patterns |
|---|---|---:|
| pcre2 (interp and JIT, identical) | syntax: character-class intersection `&&` is Oniguruma-only | 2 |
| pcre2 | syntax: `\h` is a hex digit in Oniguruma, horizontal space elsewhere | 1 |
| pcre2 | semantic: POSIX class definitions differ (`[[:xdigit:]]` under `PCRE2_UCP` matches more than Oniguruma) | 1 |
| pcre2 | semantic: subject is not valid UTF-8 | 1 |
| re2 | semantic: `\w \b \d \s` and POSIX classes are ASCII-only | 21 |
| re2 | semantic: end anchor before a final newline | 5 |
| re2 | semantic: `^` after a final newline (Oniguruma does not match there) | 4 (+1) |
| re2 | syntax: `\10` is a backreference in Oniguruma, an octal escape in RE2 | 1 |
| re2 | semantic: subject is not valid UTF-8 | 1 |
| rust-regex | semantic: POSIX class definitions differ (ASCII-only in Rust) | 7 |
| rust-regex | syntax: `\<` `\>` are word anchors in Rust, literals in Oniguruma syntax | 5 |
| rust-regex | semantic: end anchor before a final newline | 4 |
| rust-regex | semantic: `^` after a final newline | 4 (+1) |
| rust-regex | semantic: subject is not valid UTF-8 | 1 |
| ocaml-re | semantic: matches bytes, not code points | 29 |
| ocaml-re | semantic: end anchor before a final newline | 4 |
| ocaml-re | semantic: `^` after a final newline | 4 (+1) |

(+1): the pattern labelled "alternation or longest-match order" in the
CSV (`…|^|…`, vscode pid 1205) was checked by hand: the reference has no
match at the end of a subject that ends in `\n`, the engines match `^`
there; it belongs to the `^`-after-final-newline class.

## Analysis and open questions

- Criterion 3 is met for this milestone: every disagreement is listed and
  falls in a syntax or semantic class; none is unexplained. Disagreeing
  patterns are excluded from that engine's timing. The switch build agrees
  exactly with the threaded build (statuses and all matches).
- The classification is a heuristic on the pattern text and the first
  differing subject; the CSV keeps both match lists so a row can be
  re-checked. Hand checks: the `^`, `\<`, `&&`, `\10` and invalid-UTF-8
  rows.
- Coverage of the comparison is very uneven: on vscode, PCRE2 runs 99% of
  the patterns, RE2 44%, Rust 47%, ocaml-re 38%; on vscode-subst RE2 and
  Rust run none of the substituted patterns (escaped U+FFFF is rejected),
  so their vscode-subst columns contain only patterns without pairs. Speed
  ratios must therefore be taken on each engine's own subset (the timed
  runs also time Oniguruma on each subset).
- Spec questions raised: Oniguruma's `^` does not match after a final
  newline at the end of the subject, and `\<`/`\>` are literals in
  `ONIG_SYNTAX_ONIGURUMA`; both are confirmed behaviours to record.
