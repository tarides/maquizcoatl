# Experiment #8 follow-up (issue #34), entry 3: corrections after the run-1 review

**What.** Corrections to entry 2
([2026-11-26-exp-08-lemmas-cases.md](2026-11-26-exp-08-lemmas-cases.md))
required by the independent review of run 1 on issue #34
([comment](https://github.com/tarides/maquizcoatl/issues/34#issuecomment-7194264066)),
problems 1-3. No new run: every fact below is already in entry 2's raw
data or in the git history of the branch. Entries 1 and 2 are left as
recorded; this entry supersedes the passages it names.

**Why.** The review confirmed run 1 (C Debug = C ASan = `m` = `md` on
the 29 cases, closed under the global context, figures recomputed from
the raw files), but found that the mutation check ran on fewer cases
than entry 2 says, that the session row of `effort.tsv` gives no end
time although the plan makes session time the cost measure, and that
the mutants carry a second, comment-only difference from the recorded
`Desugar.v`.

## Provenance

Text corrections only, on the data of entry 2 (branch commit
`f3fdf0f`). Two files of the experiment directory change:
`lab/08-discriminating-lemmas/LEMMAS.md` (one paragraph, prose only)
and `lab/08-discriminating-lemmas/effort.tsv` (the session row's note
gains its end time). No Rocq source changes; nothing was run on the
bench host.

## Corrections

### 1. The mutation check ran on 27 cases, not 29 (entry 2, `LEMMAS.md`)

Entry 2, section "Mutation check", says the eight mutants were "run on
the 29 cases". The drivers in the raw data
([`mutants/TM*.v`](2026-11-26-exp-08-lemmas-raw/mutants/)) list
ab01-ab27 only: none mentions ab28 or ab29, which `effort.tsv` records
as added after the mutation check. Read "run on the 27 cases ab01-ab27"
for "run on the 29 cases".

- The detections stand: a case that detects a removed restore on 27
  cases still detects it on 29, so the "First match differs" and "List
  of ends differs" entries of M1-M4, M7 and M8 are unchanged.
- The no-effect claims are qualified: "M5 changes no first match" and
  "M6 changes nothing" hold on ab01-ab27; they were not checked on the
  two loop cases ab28-ab29, and ab29 is the only case with the stopper
  inside a loop.
- `LEMMAS.md`'s paragraph on the mutation check (with the sentence
  "Dropping the atomic group of the general path changes no first
  match") now carries the same qualification.

Follow-up: run 2 reruns the eight mutants on the 29 cases (eight builds
of about 1.5 s each) and records the outcome in its own entry.

### 2. Session end time (`effort.tsv`)

The session row said "end at the run-1 notebook commit". That commit is
`f3fdf0f`, committed 2026-11-26T13:58:03Z, so the session ran from
13:45:22Z to 13:58:03Z: 12 min 41 s of wall clock. The row now carries
the timestamp and the duration.

### 3. The mutants were cut from a draft of `Desugar.v`

Each `mutants/DM*.v` differs from the recorded
`lab/08-discriminating-lemmas/rocq/Desugar.v` in two hunks: the mutation
named in entry 2's table, and one comment line, where the draft cites
`is_simple_one_char_repeat` as `regparse.c:3185-3240` and the recorded
file as `regparse.c:3184-3249`, a citation corrected before commit (the
re-check of upstream citations that `effort.tsv`'s `LEMMAS.md` row
records). The code of each mutant is
the recorded `Desugar.v` plus its one mutation; the comment hunk is not
a second change.

## Analysis

None of the three changes a result of run 1. Problem 1 narrows what the
two negative mutation results cover until run 2 reruns them on all 29
cases; problems 2 and 3 complete the record.
