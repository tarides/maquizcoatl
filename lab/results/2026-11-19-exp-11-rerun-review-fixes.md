# exp-11 re-runs r2-r4: fixes from the review of the re-runs

## What

Corrections and additions to the r2-r4 entries
(`2026-11-19-exp-11-rerun-throughput.md`, `-rebuild.md`) and to the r1
corrections note, asked by the automated review of the re-runs on
issue #2. Results files are append-only, so this entry states the
corrected wording; where it differs from the earlier entries, this entry
wins. No new measurement was made: every figure below comes from files
already committed, from the build log added with this entry, or from a
read-only look at the bench directory.

New files:

- this entry;
- `2026-11-19-exp-11-rebuild-build.log`: the output of `build.sh` for the
  rebuild, with the bench directory written `<bench>` (as in r1's
  `2026-11-19-exp-11-builds.log`).

## Why

The review of the re-runs (issue #2) confirmed that the r2-r4 tables
reproduce from the raw files, and listed eight decision-free problems
(1-7 and 10) and two that need a decision (8 and 9). Problem 1 (post the
corrected table on the issue) is handled by a comment on issue #2, not
in a file. This entry handles problems 2-7 and 10. Problems 8 and 9 are
listed at the end for the maintainer.

## Provenance

- Repository: branch `exp/11-perf-baselines`, analysis of the files of
  `98047cc` with `spread.py` as committed and `awk` on the `T` lines.
- The build log was copied from the bench directory; the hash of the
  binaries was recomputed there, read-only, the same way as
  `provenance.sh` does.
- Written by Claude Code (Opus 5.5) in the experiment pipeline,
  2026-11-19.

## Problem 2: the between-run spread is a same-session figure

r2, r3 and r4 ran within 2.5 hours, on the same binaries, with a global
load average of 0.1-5.9 (above 2 only from the end of r3's rust-regex
column on). So
`b` in the r2-r4 tables measures run-to-run noise within one session. It
does not cover the variation between sessions. r1 is a fourth session
for the columns whose harness did not change, and it moves several
ratios by more than their r2-r4 spread:

| cell | r1 ratio | r2-r4 ratio, median (min-max) | r1 / r2-r4 median |
|---|---:|---:|---:|
| pcre2-interp vscode-subst | ×0.442 | ×0.415 (0.412-0.425) | 1.065 |
| pcre2-interp vscode | ×0.516 | ×0.498 (0.497-0.498) | 1.037 |
| pcre2-interp jq | ×1.035 | ×1.072 (1.057-1.083) | 0.966 |
| ocaml-re php | ×414 | ×427 (406-446) | 0.968 |

Over all the unchanged columns other than onig-switch (pcre2-interp,
pcre2-jit, ocaml-re), r1 / r2-r4 is 0.966-1.065. So ratios carry a
session-to-session uncertainty of about 3-7%, larger than most `b`
values. onig-switch jq moves by 16% (×0.79 in r1, ×0.94 in r2-r4); that
cell is affected by the compile-first effect (problem 8).

## Problem 3: two ratios near 1 are marginal

The rerun analysis says every ratio is distinguishable from 1. That
holds for the rule of `spread.py` over r2-r4, but two cells pass only
narrowly and should be read as marginal:

- onig-switch jq, ×0.94: |ln 0.944| = 0.058 against a bound of 0.055.
  Both of its cells (onig-switch jq and onig-threaded jq) are subject to
  the compile-first effect, which switches on and off between processes
  (25.4 µs then 29.4 µs in the `compile-first` check). Three processes
  per cell cannot bound a two-state effect.
- pcre2-interp jq, ×1.07: it was ×1.035 in r1, and the
  session-to-session variation above is 3-7%.

The next closest is onig-switch php-legacy, ×0.91 (0.098 against a
bound of 0.045). Its two cells are also subject to the compile-first
effect, but the ratio is the same without compile timing (×0.91 in the
`nocompile` check) and in r1 (×0.92), so it holds across sessions. All
the other ratios clear their bound by a factor of 4.5 or more and stay
on the same side of 1 in r1.

## Problem 4: the r1 to r2-r4 drift

Corrected sentence: of the 22 own cells whose harness did not change
(onig-threaded, onig-switch, pcre2-interp, pcre2-jit, ocaml-re), 21 run
faster in r2-r4 than in r1: 18 by 7.0-11.7%, then onig-threaded php
6.9%, ocaml-re php 5.0% and pcre2-interp vscode-subst 2.1%. One runs
slower: onig-threaded jq, by 5.2% (a cell subject to the compile-first
effect). The 20 Oniguruma subset cells (onig-threaded@engine) run
5.5-10.2% faster.

Candidate causes, none of them tested: the global load average, 26-50
during r1's timing (experiment 3's fuzzers on the other L3 complexes)
against 0.1-5.9 during r2-r4; the new bench directory and the rebuild;
the longer repetitions (at least 0.5 s since `5ea951c`); the CPU
frequency. The load is the most visible difference in the committed
provenance.

## Problem 5: uncertainty of the capture cost

The cost factor divides an r1 ratio by an r2-r4 ratio, so it carries the
session-to-session variation of problem 2. The control columns
(pcre2-interp, pcre2-jit, ocaml-re) move by 0.966-1.065 between the two
sessions. Dividing each cost factor by that band:

| engine | jq | php | vscode |
|---|---|---|---|
| re2 | 1.13, band 1.06-1.17 | 1.42, band 1.33-1.47 | 1.16, band 1.09-1.20 |
| rust-regex | 1.42, band 1.33-1.47 | 1.42, band 1.33-1.47 | 1.41, band 1.32-1.46 |

So extracting the groups costs RE2 roughly 5-20% on jq and vscode and
33-47% on php. For Rust `regex` the factor is 1.41-1.42 on all three
workloads; that consistency suggests a cost close to 41%, within the
same 33-47% band. A same-run measurement (the same binary with one
submatch against all of them) would settle the RE2 figures; it is listed
as a follow-up.

## Problem 6: commands of the check measurements

The three check measurements were run by a one-off shell loop that was
not kept. The commands below are equivalent: they are reconstructed from
the output names, the pattern lists, the provenance sample labels and
the file times in the bench directory, and checked against them (each
`rest` list is r4's own list without pattern 105, `single.txt` holds
`105`, the cells ran in the order below, and only the `compile` cells
have `C` lines).

Common part, run in `<bench>/out/<label>` (`php-share`, `compile-first`,
`nocompile`):

    . <repo>/experiments/11-perf-baselines/env.sh
    BIN=$BENCH/bin; WL=$BENCH/workloads/prepared; R4=$BENCH/out/r4/only
    mkdir -p only time
    cell() { # name engine workload only-file [env]
      n=$1 e=$2 w=$3 o=$4; shift 4
      env "$@" taskset -c 4 "$BIN/$e" time "$WL/$w" "$o" > "time/$n.txt" 2> "time/$n.err"
    }
    <repo>/experiments/11-perf-baselines/provenance.sh full start > provenance.txt

`php-share` (search only):

    echo 105 > only/single.txt
    for e in onig-threaded onig-switch pcre2-interp pcre2-jit re2 rust-regex ocaml-re; do
      grep -vx 105 "$R4/$e.php.txt" > "only/$e.rest.txt"
    done
    provenance.sh sample before-php-share >> provenance.txt
    cell onig-threaded.full   onig-threaded php "$R4/onig-threaded.php.txt" E11_NO_COMPILE=1
    cell onig-threaded.single onig-threaded php only/single.txt E11_NO_COMPILE=1
    cell onig-threaded.rest   onig-threaded php only/onig-threaded.rest.txt E11_NO_COMPILE=1
    for e in onig-switch pcre2-interp pcre2-jit re2 rust-regex ocaml-re; do
      cell "$e.single" "$e" php only/single.txt E11_NO_COMPILE=1
      cell "$e.rest"   "$e" php "only/$e.rest.txt" E11_NO_COMPILE=1
      case $e in onig-*) ;; *)
        cell "onig-threaded@$e.rest" onig-threaded php "only/$e.rest.txt" E11_NO_COMPILE=1 ;;
      esac
    done
    provenance.sh sample after-php-share >> provenance.txt

`compile-first` (jq, with compile timing and without):

    for i in 1 2; do for e in onig-threaded onig-switch; do
      cell "$e.compile.$i"   "$e" jq "$R4/$e.jq.txt"
      cell "$e.nocompile.$i" "$e" jq "$R4/$e.jq.txt" E11_NO_COMPILE=1
    done; done
    provenance.sh sample end >> provenance.txt

`nocompile` (every own cell of `run.sh`, search only):

    for e in onig-threaded onig-switch pcre2-interp pcre2-jit re2 rust-regex ocaml-re; do
      provenance.sh sample "before-$e" >> provenance.txt
      for w in jq php php-legacy vscode vscode-subst; do
        [ -s "$R4/$e.$w.txt" ] && cell "$e.$w" "$e" "$w" "$R4/$e.$w.txt" E11_NO_COMPILE=1
      done
    done
    provenance.sh sample end >> provenance.txt

Each label's `raw-times.tsv` holds the `C`, `W`, `T` and `S` lines of
every `time/*.txt`, prefixed by the label and the cell name, as
`keep_raw` in `run.sh` writes them.

Gate: `php-share` and every column of `nocompile` have a sample just
before timing, at 0-1% busy on CPUs 4-7 and 36-39. `compile-first` has
no labelled gate sample; its `start` and `end` samples (18:12:42 and
18:13:04 UTC) cover the whole measurement and show CPUs 5-7 and 36-39 at
0.0-0.3% busy over it (CPU 4 at 99.7%, the timed process).

## Problem 7: binaries of the rebuild

- Hash of the binaries, as `provenance.sh` computes it
  (`sha256sum` of every file of `<bench>/bin`, then `sha256sum` of that
  list): `9271570f623ba669c01d0bc44bc4fb42fc2529bff3a2af08f689de47cb8fdc1b`.
  This is the `bin_sha256` of every sample of r2, r3, r4 and of the
  checks. Recomputed on the bench host after the checks: same value.
  Every file of `<bench>/bin` has a modification time of
  15:18:23-15:19:38 UTC, inside the `build.sh` step of the rebuild
  (15:18:18-15:19:38 UTC), so the binaries timed in r2-r4 are those of
  the rebuild.
- Build log: `2026-11-19-exp-11-rebuild-build.log` (`build.sh` output,
  exit 0, ends with `build done`).

## Problem 10: small inaccuracies

- rust-regex php in r3: the median pass is 44.7 µs (44.725 µs), not
  44.5 µs.
- r3 conditions: "timing complex still 0-1% busy" is the 5 s gate before
  each column. Over the ocaml-re column (16:25:57-16:26:50 UTC), CPU 38
  was 6.0% busy (from the `/proc/stat` samples), the other neighbours
  0.1-0.7%; still under the 10% threshold.
- r1 corrections note, "Classes after the fix (103 patterns)": the
  reclassified CSV has 103 rows, one per engine and pattern. The table
  shows the pcre2 interpreter and JIT rows once (they are identical,
  5 rows each), so its counts sum to 98.
- Draft PR #17 carried `stage:plan`; it is relabelled with the issue's
  stage.

## Still open, needs a decision

- Problem 8, compile timing before the search: keep the protocol and
  state the bias, or time compilation in a separate process and run a
  new series. The dispatch figure for experiment 10 depends on it: on
  vscode, the only real throughput workload, the single `nocompile` run
  gives ×0.84 against ×0.80 (0.79-0.80) in r2-r4, because onig-threaded
  vscode is 3.4% slower there while its between-run spread is 0.1%.
- Problem 9, the 10% repeat rule: on IQR / median (as `run.sh` does) or
  on the range. No effect on r2-r4.
