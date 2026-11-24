# exp-11 compile timing in its own process

## What

The protocol change asked by the maintainer before the r5-r7 series,
in the harnesses and scripts of experiment 11, and the rebuild of every
column on the bench host with it. The dispatch probe and an untimed
smoke test of all seven columns on the jq workload, in `check`,
`compile` and `time` modes, pass. Nothing was timed.

## Why

Maintainer decisions on issue #2
([comment](https://github.com/tarides/maquizcoatl/issues/2#issuecomment-7019817702)),
after the review of the r2-r4 re-runs:

1. Compilation is timed in a separate process from the search. The
   `compile-first` measurements showed that timing the compilation just
   before the search, in the same process, slowed Oniguruma's search by
   20% on jq and 9% on php-legacy (`2026-11-19-exp-11-rerun-throughput.md`).
   A new series of three runs (r5, r6, r7) uses this protocol.
2. The 10% repeat rule is on the range ((max - min) / median of the
   repetition times), not on the IQR, which understates the noise.

Both are now decisions 4 and 5 of the plan, and step 7 describes the
new protocol.

## Changes

Branch `exp/11-perf-baselines`, four commits on top of `21dc0c8`:

- `18ec4dc` time compilation in its own process. The harnesses (C and
  C++ through `driver.h`, Rust, OCaml) get a `compile` mode that prints
  only the `C` lines; `time` prints only `W`, `T` and `S` and times no
  compilation. Both modes compile every pattern once, untimed, to know
  which ones the engine accepts, and both read the only-file.
  `E11_NO_COMPILE` is removed. In the time phase, `run.sh` runs the
  `compile` process of each own cell right after its search, on the
  same timing CPU, into `compile/<cell>.txt`; the
  `onig-threaded@<engine>` cells are search only. `raw-times.tsv` keeps
  the `C` lines under the cell name, as before, so `spread.py
  --compile` reads them unchanged. `summarise.py` takes the compile
  times from `compile/` when it exists, else from the time file (r4 and
  earlier).
- `695b77a` repeat on the range. `spread.py` decides the repeat and
  prints it as a fifth field (`yes`, `no`, or `failed` for a time file
  with fewer than two repetitions, which `run.sh` now logs as a
  WARNING instead of comparing the string `nan`). A cell with no subject
  byte times an empty pass, whose range is noise (148% for
  onig-threaded@re2 vscode-subst in r2-r4): it is never repeated and
  always valid. `summarise.py` judges validity with the same rule and
  adds a `range` column; the `spread` (IQR / median) column stays.
- `e653120` `run.sh` logs a WARNING line when a harness process exits
  with an error, instead of silently keeping a truncated file.
- `ccd2620` `build.sh` installs the ocaml-re binary with `install`:
  dune leaves its output read-only, so the first rebuild below failed
  to copy over the existing binary.

A context-free code review of the first three commits found no
correctness problem. The findings of the earlier review of the
uncommitted change are all addressed by these commits or by this note.

## Provenance

- Repository: the bench clone fast-forwarded to `ccd2620`, `upstream/`
  submodule at `f95747b`.
- Machine: the same bench host and bench directory as r2-r4.
- Commands, under `nice -n 10`, builds pinned with
  `taskset -c 16-19` (`BUILD_CPUS`), at most 4 jobs:
  - `build.sh` at `e653120`, 19:56:23-19:56:29 UTC, exit 1: every
    column rebuilt except the copy of ocaml-re (permission denied on
    the read-only binary of the previous build). Fixed by `ccd2620`;
  - `build.sh` at `ccd2620`, 20:01:03-20:01:07 UTC, exit 0. It is
    incremental: the Oniguruma, PCRE2, Abseil and RE2 libraries are
    unchanged, only the harnesses are relinked.
- Load average about 5 during the builds; other accounts' processes
  were running on part of CPUs 16-19. Nothing was timed, so this does
  not matter here, but r5 should check the gate log as usual.
- Run by Claude Code (Opus 5.5) in the experiment pipeline, 2026-11-19.

## Parameters and raw data

Build checks:

- The `regexec.c.o` objects have the same sha256 as in r1 and in the
  rebuild for r2-r4 (`2026-11-19-exp-11-rebuild.md`), and differ between
  the two builds:

      3afcff457c275bef64a1abde7048739dfc9e11a86a7627211c782a363d5fa976  onig-threaded/.../regexec.c.o
      2e758094206da60dacd96c96b891aaa243d84824b035f27599f7d99d106dbb17  onig-switch/.../regexec.c.o

- Dispatch probe (built by `build.sh`, run again after the build):

      probe-threaded: USE_DIRECT_THREADED_CODE defined: direct-threaded dispatch
      probe-switch:   USE_DIRECT_THREADED_CODE undefined: switch dispatch

- sha256 of the binaries for r5 (all harnesses differ from r2-r4, as
  expected; the probes are unchanged):

      6b5fadc8a565bf4a9a0045f3ee1d619a6a6907c17e52ca130860b5f19ccc71f9  ocaml-re
      8fecf3ae68cfa1936ee04c5368f21f727396bc38bec7610a832815846fc3772b  onig-switch
      aaf54b427c179fdc1725d4679f4a4e82ff62b933027b9d7f3d5e6990dfd3b9d7  onig-threaded
      0db505063503acb1cf69299c52de914adb2cd6b437b6a5948184ccc2bf000520  pcre2-interp
      d058e5a24af0bb0f7aa5dc50a6043e3cd5bc998d988a689dedfd4371bdf51e96  pcre2-jit
      1f9d0afb4603e76db08bd5d202c0ae503e045056fd60f2844271e99272383d89  probe-switch
      daaaffe4f4c4db168d1c92bf6e85141e50738a731385238bdcbf49d9837ada66  probe-threaded
      83d7e067d49b5fe3cf8951350408022a10bbb5546f548adb483c19dc831cc5a0  re2
      d04ba15761f2abec3e0ace66bd7d9d60c9cd1579702024ae033e8532b8db1503  rust-regex

Smoke test, untimed: for each column, on `<bench>/workloads/prepared/jq`,
under `nice -n 10 taskset -c 16-19`, with `E11_REPS=2 E11_REP_MIN=0
E11_COMPILE_N=1 E11_COMPILE_MIN=0`: `check`; `compile` and `time`
without an only-file; `compile` and `time` with the r4 only-file of the
column (`out/r4/only/<column>.jq.txt`). Every call exits 0 with an
empty stderr:

| Column | `check` same as r4 | Compiled | `compile`: C lines, other lines | `time`: W, T, S, C lines | Only-file lines | `compile` / `time` with it |
|---|---|---|---|---|---|---|
| onig-threaded | yes | 44 | 44, 0 | 1, 2, 1, 0 | 44 | 44 / 44 |
| onig-switch | yes | 44 | 44, 0 | 1, 2, 1, 0 | 44 | 44 / 44 |
| pcre2-interp | yes | 44 | 44, 0 | 1, 2, 1, 0 | 44 | 44 / 44 |
| pcre2-jit | yes | 44 | 44, 0 | 1, 2, 1, 0 | 44 | 44 / 44 |
| re2 | yes | 39 | 39, 0 | 1, 2, 1, 0 | 38 | 38 / 38 |
| rust-regex | yes | 41 | 41, 0 | 1, 2, 1, 0 | 41 | 41 / 41 |
| ocaml-re | yes | 39 | 39, 0 | 1, 2, 1, 0 | 37 | 37 / 37 |

"`check` same as r4": the output, apart from the `PASS` duration line,
is identical to `out/r4/check/<column>.jq.txt`. "Compiled" is the
number of `ok` patterns of `check`; `time` without an only-file reports
the same number as `included_patterns`. With the only-file, the `C`
line count of `compile` and `included_patterns` of `time` both equal
the only-file's line count.

A bad mode exits 2 in every harness tried (onig-threaded, pcre2-jit,
re2, rust-regex, ocaml-re). A missing only-file exits 2, except in
rust-regex, which panics with exit 101 (the `unwrap` was already there
for `time`); `run.sh` now logs either as a WARNING.

Before the host run, `run.sh` was also run locally on a scratch copy
(two columns built against the system Oniguruma and PCRE2, jq only,
gate and provenance stubbed): `time/`, `compile/` and `raw-times.tsv`
as described; `E11_REP_MIN=0` takes the repeat path; a fake harness
exiting 3 after one `T` line gives a WARNING line for each of its two
processes and one for the missing repetitions, and no repeat;
starting the same label again stops with "already has timing outputs".

Old runs under the new scripts: `spread.py --runs` and `--compile` over
the committed r2-r4 `raw-times.tsv` give byte-identical output before
(`21dc0c8`) and after (`ccd2620`). `summarise.py` on the r2, r3 and r4
run directories gives the same verdicts before and after (30 own cells
each, all valid, all from the first run) and identical `-compile.csv`.

## Analysis and open questions

- Every column builds and passes the smoke test, so the bench directory
  is ready for r5-r7 (`run.sh r5 all`, and so on).
- In the timed phase each own cell now starts one more process, which
  loads the workload and compiles every pattern once, untimed, before
  its compile loop. The projection printed by `run.sh` does not count
  this start-up (not measured here) and now says so.
- The compile process runs after the search of its cell. Running it
  before would also keep the two apart; the maintainer may prefer that
  order before r5.
- The commands recorded in `2026-11-19-exp-11-rerun-review-fixes.md`
  for the `php-share`, `compile-first` and `nocompile` measurements set
  `E11_NO_COMPILE`, which the harnesses now ignore. They reproduce only
  with the harnesses of `21dc0c8` or earlier: with the new ones,
  `compile-first` would time two identical search-only series.
- Re-summarising a run made before r5 judges it on the range. For
  r2-r4 this changes nothing (above); r1 was not re-checked.
