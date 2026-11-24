# exp-01 review fixes: encoding names, long subjects, frequency profile

## What

Re-run of parts of experiment #1 after the automated review
(https://github.com/tarides/maquizcoatl/issues/5#issuecomment-7008480225)
and the maintainer's decisions
(https://github.com/tarides/maquizcoatl/issues/5#issuecomment-7008852226,
"apply all of them"). Three things were run:

1. Reclassification with Oniguruma's own encoding names (`Shift_JIS`
   instead of `SJIS`, also `US-ASCII`, `Big5`), then `inventory.py`,
   `dynamic_only.py` and `tables.py` again.
2. A new PHP capture of the calls with subjects over 4 KiB
   (`workloads/shim_long.c`), packaged as a capped sample for #12.
3. A new VS Code replay that counts repeated searches
   (`workloads/freq_vscode.js`), for #11.

This entry supersedes two counts of the
[workloads entry](2026-11-19-exp-01-workloads.md) and one row of the
[compile-and-classify entry](2026-11-19-exp-01-compile-and-classify.md);
those files are left as recorded.

## Why

- Review problem 1: the shim logs `enc->name` (`Shift_JIS`,
  `upstream/src/sjis.c:292`) but `classify.c` only knew `SJIS`, so the 6
  Shift_JIS dynamic-only PHP triples were never compiled (`bad-input`) and
  `tables.md` read "131 triples, 125 compile".
- Review problem 2: two counts in the workloads entry describe the full
  PHP capture, not the committed files.
- Review problem 3: the plan promised the number of patterns changed by
  vscode-textmate's `\z` rewrite next to the VS Code table.
- Follow-ups: #12 wants few searches over large subjects, which the 4 KiB
  cap of the main PHP capture drops; #11 wants real frequencies, which the
  deduplicating replay does not give.
- The `\p` decision (option c) is recorded as DEV-004 in
  `spec/deviations.md`; the valid one-letter property set it relies on
  was checked here (below).

## Provenance

- Repository: branch `exp/01-pattern-inventory`, parent commit `f64aa5f`,
  scripts as of the commit that adds this file. Experiment #11 had already
  started from the committed workloads, so no existing file under
  `workloads/` was changed; everything for the follow-ups is new
  (`shim_long.c`, `long_subjects.py`, `freq_vscode.js`, `freq_profile.py`,
  `build_followups.sh`, `package-lock.json`, `data/php.long-subjects.*`,
  `data/vscode.frequency*`).
- Same builds as the earlier entries: stock upstream `f95747b` (Release,
  shared, GCC 15.2.0), instrumented static copy, PHP 8.5.12 CLI with
  mbstring only, vscode-textmate 9.3.2 + vscode-oniguruma 1.7.0;
  Node.js 22.22.1, Python 3.14.4 (`-I`).
- Machine: 12th Gen Intel Core i7-1260P (16 threads), 15 GiB RAM,
  Ubuntu 26.04.1 LTS, Linux 7.0.0-43-generic. At most 4 parallel jobs.
- Run by Claude Code (Opus 5.5) in the experiment pipeline, 2026-11-19
  around 12:00-12:30 UTC.

Commands (from the experiment directory, `<workdir>` outside the repository):

    cc … classify.c …            # classify and classify-stock rebuilt
    python3 -I scripts/inventory.py patterns <bin>/classify <bin>/classify-stock <out>/{vscode,jq,php}.occ.jsonl > patterns/inventory-report.json
    python3 -I scripts/dynamic_only.py patterns <bin>/classify <out>/workloads-full
    python3 -I scripts/tables.py patterns tables > tables/summary.json
    WORKDIR=<workdir> sh workloads/build_followups.sh    # exit 0

`extract_php.py` re-run: occurrence file byte-identical (no Shift_JIS
pattern in the static corpus). The follow-up data were produced
by hand first, then by `build_followups.sh`: the files are byte-identical. PHP tests under
`shim_long.c`: 437 passed, 9 skipped, 0 failed of 446 (about 3 s).
VS Code frequency replay: 20 s, peak RSS 0.95 GB, exit 0.

## Data

### 1. Encoding names

| File | before | after |
|---|---|---|
| `patterns/php.dynamic-only.jsonl` | 6 Shift_JIS triples `bad-input` | all 131 `ok` |
| `tables.md`, dynamic-only PHP row | 131 triples, 125 compile, captures 21 | 131 triples, 131 compile, captures 27 |
| `patterns/{vscode,vscode-grammar-text,jq,php}.jsonl` | | unchanged (byte-identical) |
| `patterns/inventory-report.json` | | adds `vscode_z_rewrite`; 0 stock-vs-instrumented mismatches, as before |

The main tables (static corpus) are unchanged: the static corpus has no
Shift_JIS, US-ASCII or Big5 triple.

### 2. Corrections to the workloads entry (labels)

| Workloads entry says | Refers to | Committed `workloads/data/php.jsonl` |
|---|---|---|
| "194" distinct compiled triples (PHP row) | full capture, 15,424 logged calls | 189 distinct triples in the 421 committed calls |
| "four calls use other values" of the match limits | full capture | one call (retry limit 100,000); the other three (stack limits 10,000, 30,000, 30,001) have 30,000-byte subjects and are now in `php.long-subjects.jsonl` |
| "15,416 searches use retry limit 1,000,000 and stack limit 100,000" | full capture | the shim log gives 15,420 (15,424 calls minus the four above); 420 of the 421 committed calls |

### 3. `\z` rewrite

vscode-textmate's `\z` → `$(?!\n)(?<!\n)` rewrite changes 10 occurrences,
7 distinct patterns (`rewritten_z` in the VS Code occurrence file). Now
printed under the VS Code compiled-form table in `tables.md` and stored in
`inventory-report.json` / `summary.json`.

### 4. Long-subject PHP calls

| Test | long calls (> 4 KiB) | kept | subject | expected results |
|---|---:|---:|---|---|
| `mbregex_stack_limit.phpt` | 3 | 3 | 30,000 spaces | -15 (stack limit 10,000 and 30,000), match `[0, 30000)` (30,001) |
| `oom_mb_ereg_replace.phpt` | 2,097,153 | 5 | 2 MiB of `a` | matches `[k, k+1)` |
| `oom_mb_eregi_replace.phpt` | 2,097,153 | 5 | same subject | matches `[k, k+1)` |
| `oom_mb_split.phpt` | 65,537 | 5 | same subject | matches `[k, k+1)` |

18 calls, 2 distinct subjects (stored once, as `repeat` units: 2 bytes of
stored text), well under the caps (100 calls, 1 MiB). No other test has a
subject over 4 KiB. The main capture's "15,003 calls with subjects over
4 KiB" was the 5,000-call per-process cap applied to these four tests.

### 5. Frequency profile (VS Code)

1,486,388 `findNextMatchSync` calls for 473,134 distinct searches (the
same distinct set as the original replay: every line of the committed and
of the complete `vscode.jsonl` found its count).

| times issued | distinct searches | calls |
|---|---:|---:|
| 1 | 36,060 | 36,060 |
| 2 | 71,414 | 142,828 |
| 3-4 | 348,228 | 1,047,344 |
| 5-9 | 14,452 | 92,168 |
| 10-99 | 2,806 | 58,947 |
| 100-999 | 158 | 32,163 |
| 1000+ | 16 | 76,878 |

Maximum 10,201. The 11,263 committed searches account for 18,911 calls
(max 464). Top scanners by calls: 301 (311,910), 315 (273,591), 313
(153,891), 314 (114,025).

### 6. One-letter properties at `f95747b` (for DEV-004)

Compiling `\pX` for every printable ASCII `X` with the stock library,
Oniguruma syntax: UTF-8 accepts `C L M N P S Z` and their lower-case
forms (case-insensitive name table); US-ASCII, ISO-8859-1, EUC-JP and
Shift_JIS accept none. `[\s\d\p]` and `\p` are -223 under Oniguruma, Perl
and Perl_NG, and compile under Ruby, Java and Python (where `\p` is a
literal `p`: `^[\s\d\p]+$` matches `p` and `1 p`). Sources cited in
`spec/deviations.md`, DEV-004.

## Analysis and open questions

- The PHP test suite has no realistic long subjects: two synthetic
  repetitions. They are still useful for #12 (a stack-limit failure and a
  long run of one-character matches), but #11 and #12 must bring their own
  large, realistic subjects (for example whole source files through the
  VS Code scanners, or jq over large JSON).
- Most VS Code searches are issued 3-4 times: 70% of all calls come from
  searches repeated 3 or 4 times. Weighting by these counts changes the
  workload mix for #11 compared with the deduplicated set; why
  vscode-textmate repeats them (rule-stack handling, injections) was not
  investigated.
- The plist grammar `Regular Expressions (JavaScript).tmLanguage` stays
  outside the corpus (README sentence added).
