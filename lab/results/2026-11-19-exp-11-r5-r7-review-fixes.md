# exp-11 r5-r7: fixes from the review of the r5-r7 analysis

## What

Corrections and additions to `2026-11-19-exp-11-r5-r7-throughput.md`
and `2026-11-19-exp-11-compile-separate.md`, asked by the automated
review of r5-r7 on issue #2. Results files are append-only, so this
entry states the corrected wording; where it differs from the earlier
entries, this entry wins.

One short measurement was made for problem 1 (the vscode subset check
below). Every other figure comes from files already committed or from
the build logs added with this entry.

New files:

- this entry;
- `2026-11-19-exp-11-vscode-subset-check-raw-times.tsv` and
  `-vscode-subset-check-provenance.txt`: the check of problem 1, in the
  format of a run's `raw-times.tsv` and `provenance.txt`;
- `2026-11-19-exp-11-compile-separate-build-1.log` and
  `-compile-separate-build-2.log`: the output of the two `build.sh` calls
  of the r5-r7 rebuild (exit 1, then exit 0), with the bench directory
  written `<bench>` and a first line giving start, exit status and end.

## Why

The review of r5-r7 confirmed that both maintainer decisions are
implemented and that the tables reproduce from the raw files. It listed
six decision-free problems (1-6) and two that need a decision (7 and 8).
Problems 2 (post the r5-r7 table) and 3 (fold the decisions into the
issue body) are handled on issue #2, not in a file. This entry handles
problems 1, 4, 5 and 6 and two follow-ups. Problems 7 and 8 are listed at
the end for the maintainer.

## Provenance

- Repository: bench clone at `1d1fa5f`, clean; the check records repo
  commit `1d1fa5f` and bin_sha256 `29bcfd83…a52e` in every sample, the
  same binaries as r5-r7.
- Machine: the same bench host and bench directory as r5-r7. The check
  ran at 22:03:56-22:04:33 UTC, load average 3.0-3.5 (another account's
  process on another L3 complex). Over the whole check, from the
  `/proc/stat` samples, CPU 4 was 99.4% busy, its SMT sibling 0.0% and
  the other L3 neighbours at most 0.7%.
- Run by Claude Code (Opus 5.5) in the experiment pipeline, 2026-11-19.

## Problem 1: the vscode own cell against its subset

The r5-r7 entry says the compile-timing bias is gone. It shows this on
jq, where the own cell and the pcre2 subset cells time the same 44
patterns. On vscode there is no identical subset: the pcre2 lists hold
3,823 of Oniguruma's 3,856 patterns (99.6% of the bytes). There, the own
cell is 2.0-3.4% slower than the subset cells in r5-r7 (own / @pcre2-interp
1.020, 1.021, 1.029; own / @pcre2-jit 1.029, 1.034, 1.030), while in
r2-r4 the two agreed (0.997-1.004). Either the 33 extra patterns cost
about 3% of the pass, or the search-only own cell carries an effect of
its own.

Check: Oniguruma threaded, search only, on three lists taken from r7's
`only/` files: `full` (its own 3,856 patterns), `pcre2` (the 3,823 of
the pcre2 lists) and `extra` (the 33 patterns of `full` missing from
`pcre2`, 14,030 bytes per pass). The lists were timed back to back in
three rounds with the order rotated, with onig-switch on `full` in each
round. One process per cell, `taskset -c 4`, 5 repetitions of at least
0.5 s after a warm-up, as in `run.sh`. Median pass per cell:

| cell | round 1 | round 2 | round 3 |
|---|---:|---:|---:|
| onig-threaded `full` | 104.52 ms | 107.36 ms | 105.17 ms |
| onig-threaded `pcre2` | 101.41 ms | 101.68 ms | 101.41 ms |
| onig-threaded `extra` | 0.377 ms | 0.380 ms | 0.378 ms |
| onig-switch `full` | 121.71 ms | 122.03 ms | 122.79 ms |
| `full` / (`pcre2` + `extra`) | 1.027 | 1.052 | 1.033 |

Within-cell ranges are 0.14-0.69%.

- The 33 extra patterns cost 0.37% of the pass, at the same time per
  byte as the rest (26.9 against 26.7 ns per byte). They do not explain
  the gap.
- The `full` process runs the same work 2.7-5.2% slower than the
  `pcre2` and `extra` processes together, in every round. In r5-r7 the
  gap was 1.6-3.0% after removing the 0.37%.
- `full` also varies more between processes than `pcre2`: 2.7% over the
  three rounds (104.52 to 107.36 ms), against 0.3% for `pcre2` and 0.9%
  for onig-switch `full`.

So the second reading holds: the search-only own cell on vscode carries
an effect of a few percent that is not work. The cause is not
identified. A candidate, not tested, is the memory layout that the
pattern list sets up (addresses and alignment of the compiled patterns
and subjects), which changes with the list and with what the process
did before the search. The compile loop of r2-r4 is one such earlier
action, and there the own cell matched its work.

Corrected claims:

- "The compile-timing bias is gone" is shown on jq only. On vscode, the
  own cell of Oniguruma threaded has a process-state uncertainty of
  about 3-5%. Neither protocol is free of it: compile-first and
  search-only give two process states.
- Dispatch for experiment 10 on vscode: **0.85**, with an uncertainty
  of about ±4% from process state. With the same Oniguruma libraries, it
  was 0.80 under compile-first (r2-r4), 0.84 in the `nocompile` check,
  0.85 (0.848-0.861) in r5-r7 and 0.86 (0.857-0.880) in this check. The
  r5-r7 range only covers same-protocol noise. Read it as "the switch
  build runs at 0.80-0.88 of direct-threaded speed on vscode".
- The other vscode ratios against Oniguruma carry the same ±4%. None is
  close to 1: the closest is ocaml-re at ×1.24 (|ln| = 0.21).

Commands, run in `<bench>/out/vscode-subset-check` with `BENCH=<bench>`
(the script `check.sh` lives there, outside the repository):

    . "$BENCH/repo/experiments/11-perf-baselines/env.sh"
    BIN=$BENCH/bin; WL=$BENCH/workloads/prepared; R7=$BENCH/out/r7/only
    P=$BENCH/repo/experiments/11-perf-baselines/provenance.sh
    cp "$R7/onig-threaded.vscode.txt" only/full.txt
    cp "$R7/pcre2-interp.vscode.txt" only/pcre2.txt
    grep -vxF -f only/pcre2.txt only/full.txt > only/extra.txt
    cell() { # name engine only-file
      taskset -c 4 "$BIN/$2" time "$WL/vscode" "$3" > "time/$1.txt" 2> "time/$1.err"
      awk -v p="vscode-subset-check\t$1\t" '/^(C|W|T|S)\t/ { print p $0 }' "time/$1.txt" >> raw-times.tsv
    }
    "$P" full start > provenance.txt
    "$P" sample before-round-1 >> provenance.txt
    cell threaded.full.1 onig-threaded only/full.txt
    cell threaded.pcre2.1 onig-threaded only/pcre2.txt
    cell threaded.extra.1 onig-threaded only/extra.txt
    cell switch.full.1 onig-switch only/full.txt
    "$P" sample before-round-2 >> provenance.txt
    cell threaded.pcre2.2 onig-threaded only/pcre2.txt
    cell threaded.extra.2 onig-threaded only/extra.txt
    cell switch.full.2 onig-switch only/full.txt
    cell threaded.full.2 onig-threaded only/full.txt
    "$P" sample before-round-3 >> provenance.txt
    cell threaded.extra.3 onig-threaded only/extra.txt
    cell switch.full.3 onig-switch only/full.txt
    cell threaded.full.3 onig-threaded only/full.txt
    cell threaded.pcre2.3 onig-threaded only/pcre2.txt
    "$P" sample end >> provenance.txt

The pcre2-interp and pcre2-jit vscode lists are identical, and the r5,
r6 and r7 lists are identical. Every `.err` file is empty.

## Problem 4: the notebook line of the r5-r7 analysis

Corrected wording (a new notebook row; the old one is left as is):

- "Every ratio still distinguishable from 1" has no reserve for two
  cells. onig-switch jq passes by 0.025 against a bound of 0.017, and
  two search-only measurements of it differ by 3.7% (0.976 in r5-r7,
  0.939 in the `nocompile` check): read it as "at most a few percent
  slower". pcre2-interp jq passes by 0.059 against 0.027.
- "The compile-timing bias is gone" holds on jq; on vscode see
  problem 1.

## Problem 5: the process-to-process floor

Identical work in two processes of the same run differs by more than
`b` suggests. On vscode, the two pcre2 subset cells time the same list:
102.40 against 101.46 ms in r5 (0.9%), 103.00 against 101.71 ms in r6
(1.3%), 101.55 against 101.48 ms in r7 (0.1%), each with a within-run
range of 0.1-0.8%. In the check of problem 1, three processes on the
`full` list within 40 s differ by 2.7%.

So a single cell on vscode has a floor of about 1-3% from process state,
whatever its `r` and `b`. Several `b` values in the r5-r7 table are
smaller (re2 vscode 0.1%, pcre2-jit vscode 0.4%): they show that one
process state repeats well between runs, not that the cell is known to
that precision. No conclusion of the r5-r7 entry depends on a difference
that small, except the four "moved" ratios of its comparison with r2-r4,
which were already within the 3-7% between-session variation.

## Problem 6: build log of the r5-r7 rebuild

The two `build.sh` calls listed in `2026-11-19-exp-11-compile-separate.md`
are now committed:

- `2026-11-19-exp-11-compile-separate-build-1.log`: `build.sh` at
  `e653120`, 19:56:23-19:56:29 UTC, exit 1. It ends with
  `cp: cannot create regular file '<bench>/bin/ocaml-re': Permission denied`,
  the failure fixed by `ccd2620`.
- `2026-11-19-exp-11-compile-separate-build-2.log`: `build.sh` at
  `ccd2620`, 20:01:03-20:01:07 UTC, exit 0, ending with `build done`.
  Its Rust `Finished` line shows nothing recompiled: the first call had
  already built the Rust harness.

Both logs show the two `regexec.c.o` hashes and the dispatch probe
lines. The binary hashes are those of the compile-separate entry.

## Follow-ups noted, not acted on

- The switch build compiles faster than the threaded build in both
  series: by 6% on vscode (3.56 against 3.78 µs) and 9% on jq (0.78
  against 0.85 µs) in r5-r7, and 3-6% in r2-r4. This is plausible from
  the sources: under `USE_DIRECT_THREADED_CODE`, compilation keeps a
  second opcode array, `reg->ocs`, allocated and written next to the
  instructions (`upstream/src/regcomp.c:65-72`,
  `upstream/src/regcomp.c:99-104`, `upstream/src/regcomp.c:881-885`).
  It corrects r1's "Compile times are identical"
  (`2026-11-19-exp-11-throughput.md`) and "Compile time is unchanged"
  (first results comment on issue #2), and is an input for
  experiment 10.
- The commands of the `php-share`, `compile-first` and `nocompile`
  checks in `2026-11-19-exp-11-rerun-review-fixes.md` set
  `E11_NO_COMPILE=1`. Since `18ec4dc` the harnesses ignore that
  variable and `time` never compiles in a timed loop, so those commands
  now time search only in every case, and `compile-first` can no longer
  be reproduced with the current binaries. Use the binaries of the
  r2-r4 rebuild for that.
- rust-regex php sits near the 10% limit in every run (ranges 4.1%,
  10.3% then 9.6%, 8.8%); a second repeat or longer repetitions would
  make it less dependent on chance.
- Still open: the cause of the 4% Oniguruma jq drift between r2-r4 and
  r5-r7 (relink or session; a run of both sets of binaries in one
  session would separate them), the cause of the vscode process-state
  effect above, PCRE2 with `PCRE2_NO_UTF_CHECK`, the complete VS Code
  set, a regset row, RE2's capture cost in a single run, a check mode
  that compares capture group contents, why php pattern 105 alone is 9%
  faster than in the pass, and the n × 10,000,000 sentence in the
  state-of-the-art report.

## For the maintainer

1. The output archives of r2, r3 and r4, committed with `98047cc`,
   record an account name as the owner of every entry (tar headers).
   Rewrite them with numeric owner 0, as done for r6 and r7, or leave
   them since results are append-only? And should the host name removed
   by `21dc0c8` also leave the git history of the branch?
2. Compile order: the `compile` process runs after the search of its
   cell, so just before the next cell's search process. Keep that order,
   or run compile first? Compile medians are within ±2.8% of r2-r4, so
   nothing suggests a problem.
