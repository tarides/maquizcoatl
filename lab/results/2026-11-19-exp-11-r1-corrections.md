# exp-11 run r1: corrections after the results review

## What

Corrections to the run r1 entries (throughput, agreement, worst case),
answering the results review on issue #2. The r1 result files are not
changed; this note replaces the statements listed below. New raw data:

- `2026-11-19-exp-11-r1-raw-times.tsv`: every W, T and S line of the 50
  timed cells of r1 (the five repetition times behind each median and
  spread). The C lines are already in `2026-11-19-exp-11-compile.csv`.
- `2026-11-19-exp-11-r1-reclassified-disagreements.csv`: the r1
  disagreements re-classified by the fixed `agree.py`.

## Why

The review found seven problems. Problems 2, 4, 6 and 7, and the
labelling part of problems 1 and 5, can be settled from the r1 data.
Problems 1 (RE2 and Rust timed with captures) and 3 (between-run noise)
need the re-runs r2, r3 and r4 with the fixed harness. Those re-runs have
not been made: the bench directory used for r1 belongs to another account
on the bench host and still holds the r1 harness, and choosing how to
deploy the fixed harness there needs a maintainer decision. This note
will be followed by the re-run entries.

## Provenance

- Repository: branch `exp/11-perf-baselines` at `2d0d32f` (fixes
  `465850a`, `5ea951c`, `dd041de`, `2d0d32f`), plus `spread.py --runs`
  as committed with this note.
- Data: the r1 `check` and `time` outputs, copied read-only from the r1
  run directory on the bench host. Check: running r1's `summarise.py`
  (`b616f0c`) on the copied `time` outputs gives back
  `2026-11-19-exp-11-throughput.csv` and `2026-11-19-exp-11-compile.csv`
  byte for byte.
- Commands (run on the workstation, nothing timed):
  `python3 -I -S agree.py <copy-of-r1> <prepared-workloads>` (fixed
  classifier, `dd041de`) and
  `python3 -I -S spread.py --runs 2026-11-19-exp-11-r1-raw-times.tsv`.

## Corrections

### Problem 2: four disagreement rows were wrongly explained (in fact 13)

`classify()` tested `$` before the class tests. With the fixed order the
re-run gives the same counts, the same disagreeing patterns and the same
`only/` lists (so the r1 timing subsets are unchanged), but 23 of the 103
rows change class. Every one of the 13 rows labelled "end anchor before a
final newline" was wrong; that class is now empty.

The four rows the review named, checked by hand on the subjects:

| engine | pid | pattern | old class | new class | check |
|---|---:|---|---|---|---|
| re2 | 175 | `[_$[:alpha:]][_$[:alnum:]]*` | end anchor before a final newline | RE2 `\w \b \d \s` and POSIX classes are ASCII-only | subject 471 has 4 CJK characters at bytes 28-40; Oniguruma matches them, RE2 does not |
| rust-regex | 175 | same | end anchor before a final newline | Rust regex POSIX classes are ASCII-only | same subject, same missing 28-40 |
| re2 | 3383 | `` `_{,2}\|^\s*$ `` | end anchor before a final newline | syntax: `{,n}` is literal text in RE2, `{0,n}` in Oniguruma | reference matches 2-3 and 15-17 (backtick and underscores), RE2 never matches the first branch |
| ocaml-re | 2770 | `((^\|\G)([ ]{2,4}\|\t))\|(^[ \t]*$)` | end anchor before a final newline | `^` after a final newline | subject 19 is `"\n"`; ocaml-re adds an empty match at 1 |

The other nine "end anchor" rows (vscode pids 3376, 3377, 3378 for re2,
rust-regex and ocaml-re: `\*|^\s*$`, ``` ``|^\s*$ ```, ...) are also
`^` after a final newline: subject 1659 is 34 bytes ending in `\n`, and
each engine adds an empty match at 34. Pid 1205 (`…|^|…`), counted by
hand as `^` in the agreement entry, is now classified so by the script.
The seven rust-regex php rows with POSIX classes moved from "property or
POSIX class definitions differ" to the more precise "Rust regex POSIX
classes are ASCII-only".

Classes after the fix (103 patterns):

| engine | class | patterns |
|---|---|---:|
| pcre2 (interp and JIT, identical) | syntax: `&&` class intersection | 2 |
| pcre2 | syntax: `\h` | 1 |
| pcre2 | semantic: `[[:xdigit:]]` under `PCRE2_UCP` | 1 |
| pcre2 | semantic: subject is not valid UTF-8 | 1 |
| re2 | semantic: `\w \b \d \s` and POSIX classes are ASCII-only | 22 |
| re2 | semantic: `^` after a final newline | 8 |
| re2 | syntax: `{,n}` is literal text in RE2 | 1 |
| re2 | syntax: `\10` | 1 |
| re2 | semantic: subject is not valid UTF-8 | 1 |
| rust-regex | semantic: POSIX classes are ASCII-only | 8 |
| rust-regex | semantic: `^` after a final newline | 8 |
| rust-regex | syntax: `\<` `\>` | 5 |
| rust-regex | semantic: subject is not valid UTF-8 | 1 |
| ocaml-re | semantic: matches bytes, not code points | 29 |
| ocaml-re | semantic: `^` after a final newline | 9 |

Criterion 3 still holds: no row is unexplained. Spec question added:
`{,n}` means `{0,n}` in `ONIG_SYNTAX_ONIGURUMA`, `RUBY` and `PYTHON`
(`ONIG_SYN_ALLOW_INTERVAL_LOW_ABBREV`, `upstream/src/regparse.c:4670-4677`);
a confirmed behaviour to record, like `^` not matching after a final
newline.

### Problem 4: repetitions shorter than 0.5 s (fixed in `5ea951c`)

In r1, `npass` was sized from the warm-up pass. From the raw times, 160 of
the 250 repetitions lasted less than 0.5 s, and the shortest were much
shorter than the review's examples: rust-regex php 7 ms, ocaml-re php
13 ms, re2 php 14 ms, rust-regex jq 16 ms, re2 and rust-regex vscode
about 53 ms. This is a deviation of r1 from step 7 of the plan. Since
`5ea951c` every repetition repeats whole passes until 0.5 s have elapsed;
r1's figures stay as recorded, with this deviation.

### Problem 3: noise, interim figures from r1 only

The between-run figures need r2-r4. Until then, r1 contains a few cells
that time exactly the same work twice or three times (same build, same
pattern subset; equal `included_patterns`, `bytes_per_pass` and
`matches_per_pass`), at different moments of the run:

| work | cells (median pass) | difference (max - min) / median |
|---|---|---:|
| onig-threaded jq, 44 patterns | own 27.75 µs, @pcre2-interp 26.61 µs, @pcre2-jit 26.94 µs | 4.2% |
| onig-threaded php, 102 patterns | @pcre2-interp 9.77 ms, @pcre2-jit 9.98 ms | 2.2% |
| onig-threaded vscode-subst, 1525 patterns | @pcre2-interp 115.6 ms, @pcre2-jit 117.1 ms | 1.3% |
| onig-threaded vscode, 3823 patterns | @pcre2-interp 112.1 ms, @pcre2-jit 111.6 ms | 0.5% |

The within-run spread of the r1 tables (IQR / median, under 2% for every
cell) hides the extremes: (max - min) / median over the 5 repetitions
reaches 14.4% for onig-switch php-legacy, 8.6% for onig-threaded@rust-regex
jq and 32% for onig-threaded@re2 vscode-subst (a cell with no subject
byte, which times only the loop). `spread.py --runs` on the raw file
gives both figures per cell (`within_spread_max`, `within_range_max`).

Consequence for r1's ratios: a difference of 4% shows between identical
measurements, so ratios within about ±5% of 1 are not distinguishable from
noise. pcre2-interp jq (×1.04) is in that band. onig-switch php-legacy
(×0.92) is outside it, but php-legacy has no repeated measurement in r1
and its switch cell has a 14% outlier, so it stays provisional until the
between-run figures. All other r1 ratios are 20% or more away from 1.

### Problem 1: RE2 and Rust columns are bounds only in r1

In r1, `re2_bench.cc` asked for the overall match only and
`rust_bench` used `find_at`. The r1 RE2 and Rust `regex` throughput cells
are therefore "bounds only (group 0)" figures: RE2 ×1.42 / ×403 / ×2.58
and Rust ×2.44 / ×299 / ×3.95 on jq / php / vscode. The harnesses extract
every capture group since `465850a`; the re-run will give the comparable
figures and the cost of capture extraction. ocaml-re (`Re.exec_opt`)
computed groups in r1, so its column is comparable.

### Problem 5: jq and php are micro-workloads

A jq pass is 450 bytes in 64 calls and a php pass 2,993 bytes in 134
calls: on jq, 16 MB/s is about 0.43 µs per search call, which measures
call overhead, not matching speed. Only vscode (3,819,249 bytes in
106,636 calls per pass) and, to a lesser extent, vscode-subst measure
throughput; the jq and php columns must be read as per-call costs. The
php single-pattern share (`A(B|C+)+D|AC+X`, about 70% of the pass) was
measured on the workstation only; a measurement on the bench host is part
of the re-run and is not yet recorded.

### Problem 6: retry limit, n × 10,000,000 claim

The issue body said that one search may spend n × 10,000,000 retries
before returning −17. That is wrong: `MATCH_AND_RETURN_CHECK`
(`upstream/src/regexec.c:5720-5727`) leaves the search on the first error,
so a catastrophic search costs about one limit (0.095-0.15 s in r1, flat
from n = 32 to 4096). n × 10,000,000 is reached only if every attempt
fails just under the limit. The issue body is corrected; the same claim in
the state-of-the-art report is left to its maintainer.

### Problem 7: worst-case n = 16 and discarded samples

- onig-threaded jq `(a+)+$` at n = 16 is 2.0 ms (0.001992 s in
  `2026-11-19-exp-11-worst-case.csv`), not 2.9 ms. The 2.9 ms
  (0.002921 s) is from the discarded first worst-case attempt.
- Samples in `2026-11-19-exp-11-provenance.txt` that belong to discarded
  attempts (same labels as the kept ones):
  - `before-onig-threaded` at 12:14:21Z: the first time phase, under the
    old gate, stopped after three cells. The kept time phase starts with
    the `before-onig-threaded` sample at 12:16:30Z.
  - `before-worst` 12:40:42Z, `after-worst` 12:40:53Z and `end`
    12:40:53Z: the first worst-case attempt (broken `|` separator). The
    kept worst-case phase is `before-worst` 12:41:32Z to `end` 12:41:47Z.
  - `end` at 12:13:34Z closes the check phase, `end` at 12:40:37Z the kept
    time phase.

## Analysis and open questions

- Settled from r1: problems 2, 4, 6 and 7, and the labels of problems 1
  and 5. None of them changes the dispatch or PCRE2 conclusions.
- Open until r2-r4 are run with the fixed harness: RE2 and Rust with
  captures (problem 1), between-run noise and the distinguishable ratios
  (problem 3), the php single-pattern share on the bench host (problem 5).
  Blocked on a maintainer decision about the bench directory.
