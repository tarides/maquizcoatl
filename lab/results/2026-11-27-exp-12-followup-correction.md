# Experiment #12 follow-up (issue #22), entry 8: corrections after the run 1 review

**What.** Corrections to entries 1 and 5 of run `x1` after the
independent review of run 1 (issue #22 comment of 2026-11-27, 13:55
UTC). No series was rerun. One context column of entry 5 was
recomputed from files already recorded, and entry 1's timeline was
checked against the file times on the bench host. Entries 1-7 are left
as recorded; this entry supersedes the parts named below.

**Why.** Entry 5 compared the hand-written VM with experiment #12 on
"the same patterns", but the comparison used other patterns. The review
also questioned entry 1's timeline, because it put setup, extraction and
the engines build after the commit `c6b6fe2`.

Provenance: [entry 1](2026-11-27-exp-12-followup-provenance.md); fix in
`lab/22-extracted-ocaml/summarise22.py` (this commit). Recomputation on
the workstation: `summarise22.py`'s `large()` on
`2026-11-27-exp-12-followup-raw/` and
`2026-11-19-exp-12-raw/summary/`. File times: read-only `find` and
`git reflog` in `<exp>` on the bench host. Effort: about 30 minutes,
Claude Code.

## 1. Entry 5: the experiment #12 context column (supersedes its table's last column and its third bullet)

`summarise22.py`'s `large()` took experiment #12's medians over every
pattern in `work/large.list`, which holds 14 log and 15 source patterns.
Run `x1` timed ranks 1-10 only. The context column therefore included
the alternation patterns, where experiment #12's VM runs at 16-24 MB/s.
`large()` now takes experiment #12's medians over the pattern ids
present in `large.csv`. `summary/large.md` is regenerated with the
corrected column; its git history keeps the earlier version.
`summary/large-patterns.csv` is regenerated too and is byte-identical,
because the context does not enter it. No figure of this run changes.

| Source | Size | c (run `x1`) | vm (run `x1`) | experiment #12 c / vm, same 10 patterns (corrected) | entry 5's column (14 or 15 patterns) |
|---|---|---:|---:|---|---|
| log | 1 MiB | 663.4 | 71.2 | 663.6 / 66.8 | 662.9 / 58.1 |
| log | 16 MiB | 664.5 | 71.2 | 664.3 / 66.9 | 664.2 / 58.2 |
| src | 1 MiB | 622.0 | 69.7 | 621.5 / 65.5 | 521.3 / 58.0 |
| src | 16 MiB | 569.4 | 69.9 | 568.9 / 65.7 | 448.7 / 57.9 |

The corrected context also aligns C: run `x1`'s C is within 0.1% of
experiment #12's on the same patterns, whereas entry 5's src C figures
had been 101-121 MB/s off.

Entry 5's bullet "The hand-written VM is faster than in experiment #12
(70-71 against 58 MB/s on the same patterns)" is replaced by:

- **The hand-written VM is 6-7% faster than in experiment #12 on the same
  10 patterns** (69.7-71.2 against 65.5-66.9 MB/s; 6.4-6.6% per cell).
  The cause was not investigated. The build is from this branch, where
  `bench/dune` adds a `select` and the executable links the extracted
  libraries. A difference of this size could come from link order or
  host conditions.

Entry 5's other figures (the run's six columns, the ratios and the
per-byte costs) do not use the context column and are unchanged. The
results draft and the run report's "not explained" item made the same
claim, and they are corrected in the same way.

## 2. Entry 1: the timeline (checked, unchanged)

The review called entry 1's timeline unverified. It supposed that steps
2-5 had run on the host before `c6b6fe2` (committed 10:47:10 UTC),
because `conv-start` is 10:49:32 UTC. The host's file times and git
reflog show that this is not the case. The clone of `c6b6fe2` is the
first host job, and every phase falls between it and the conversion:

| Phase | Start (UTC) | End (UTC) | Evidence |
|---|---|---|---|
| clone (`setup.sh clone`) | 10:47:25 | 10:47:27 | `<exp>/repo` reflog `clone` of `c6b6fe2`; `setup/clone.txt` |
| `ffi` switch: export, dry run, install of the 10 packages | 10:47:33 | 10:48:06 | `switch-ffi.before.export`, `opam-dry-run.txt`, `opam-install.txt`, `switch-ffi.after.export`; `<cache>/opam/ffi/lib/zarith` 10:47:47, `lib/ppxlib` 10:48:01 |
| libonig builds (release, noopt, dbgc) and `test_utf8` | 10:48:12 | 10:48:27 | `<exp>/build/onig-*`, `setup/make-*.log`, `test_utf8.txt` |
| subjects | 10:48:27 | 10:48:27 | `<exp>/subjects/`, `setup/subjects.txt` |
| extraction (Rocq, then F\* with `--cache_checked_modules`) | 10:48:32 | 10:48:39 | `<exp>/extract/rocq` 10:48:32-10:48:35, `extract/fstar` 10:48:35-10:48:39, `<exp>/gen/` 10:48:39 |
| engines build (`setup.sh engines`, dune) | 10:48:45 | 10:48:47 | `<exp>/src/_build`, `<exp>/bin/x22.exe`, `setup/select.txt` |
| `prepare`, `checks`, `agree` | 10:49:18 | 10:49:25 | `work12-check.txt`, `checks/`, `agree.txt` |
| conversion | 10:49:32 | 10:50:35 | `conditions.csv`, `conv-subject.txt` |
| pilot | 10:50:42 | 11:07:58 | `conditions.csv`, `pilot.json` |
| series | 13:06:18 | 13:43:01 | `conditions.csv`, `large.csv` |
| provenance | 13:43:23 | 13:43:25 | `optimizer.txt`, `provenance.txt` |

The opam install took 28 s and the extraction 7 s, so the setup is
much faster than the plan's 40-minute estimate for steps 2-5. Entry 1
stands as recorded: the host wall clock runs from 10:47:25 to 13:43:25,
which is 2 h 56 min. At 13:06:18, when the series started, 138.9 min of
the 4-hour cap had been used and 101.1 min remained, as entry 1's
"1 h 41 min" says. Nothing of entry 1 is superseded.

## Open

The review's problem 3 is left to the maintainer as a run 2 scope
question on issue #22: why ranks 1-10 were kept when the pilot's
per-rank costs allowed ranks 1-14 within the reserve, together with the
`cata-fuel` rows and the flambda row.
