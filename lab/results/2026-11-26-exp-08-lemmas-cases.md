# Experiment #8 follow-up (issue #34), entry 2: absent cases and the desugared model (run 1)

**What.** Run 1 of plan `plans/08-discriminating-lemmas.md`: the shared
design (`lab/08-discriminating-lemmas/LEMMAS.md`), 18 new absent cases
(ab12-ab29, `cases/absent-restore.tsv`) run on both C builds, the Rocq
definitions (experiment #8's `Absent.v` with option results and fuel
parameters; `Desugar.v` with the desugaring and the state-threaded
matcher `md`) and the agreement check `Cases.v`. Result: C, the direct
semantics `m` and the desugared model `md` agree on all 29 cases (11 of
experiment #8, 18 new); `m` and `md` also give the same complete list of
ends at every start of every case. No proof was attempted (run 2).

**Why.** Decision 4 of issue #34: lemma 2 relates experiment #8's direct
semantics to a new model of the C desugaring, and that model must agree
with the C library on the 11 absent cases plus new cases exercising the
restores before any proof, so that the proof is not about a wrong model.
Run 1's done-when: "C, `m` and `md` agree on all 11 + new cases in Rocq;
case count reported".

**Provenance.** [Entry 1](2026-11-26-exp-08-lemmas-provenance.md); clone
at `50295c4`; commands:

    run-cases.sh <exp>/out/r1/cases <onig-debug> <onig-asan> \
      lab/08-hard-features/cases/absent.tsv lab/08-discriminating-lemmas/cases/absent-restore.tsv
    rocq compile -R . S {Fold,Absent,Desugar,Cases}.v     # nice -n 10, taskset -c 8-11

All exit 0. Raw data: [raw](2026-11-26-exp-08-lemmas-raw/) (`cases/`
harness outputs and joins, `rocq.txt` with the build log, wall clock and
peak RSS per file, `sha256.txt` of the compiled sources, `mutants/`,
`Kcheck.v`/`Kcheck.out`).

## Cases and agreement

29 cases, all on the Oniguruma syntax, UTF-8, no option. C: Debug and
ASan/UBSan identical on every case, no sanitizer report. `m`: `search G F`
of `Absent.v`; `md`: `dsearch F` of `Desugar.v` on `fst (desugar p 0)`;
`G = F = 1000`; each `Cases.v` lemma states that both equal the C
result and that the lists of ends of `m` and `md` are equal at every
start, proved by `vm_compute` and checked at `Qed` (`Print Assumptions`
on ab11 and ab29: closed under the global context). No case ran out of
fuel (an out-of-fuel result is `OutOfFuel`, not `Match`).

| Id | Pattern | Subject | C Debug | C ASan | `m` | `md` | lists `m` = `md` |
|----|---------|---------|---------|--------|-----|------|------|
| ab01 | `(?~ab)` | `abc` | M 0-0 | M 0-0 | M 0-0 | M 0-0 | yes |
| ab02 | `(?~abc)` | `abc` | M 0-0 | M 0-0 | M 0-0 | M 0-0 | yes |
| ab03 | `(?~abc\|ab)` | `abc` | M 0-0 | M 0-0 | M 0-0 | M 0-0 | yes |
| ab04 | `aaaaa(?~)` | `aaaaaaaaaa` | M 0-5 | M 0-5 | M 0-5 | M 0-5 | yes |
| ab05 | `(?~\|abc\|\O*)` | `abc` | M 0-0 | M 0-0 | M 0-0 | M 0-0 | yes |
| ab06 | `(?~abc)` | `xabcx` | M 0-1 | M 0-1 | M 0-1 | M 0-1 | yes |
| ab07 | `(?~\|abc\|\O*)` | `xabcx` | M 0-1 | M 0-1 | M 0-1 | M 0-1 | yes |
| ab08 | `(?~abc)z` | `xabz` | M 0-4 | M 0-4 | M 0-4 | M 0-4 | yes |
| ab09 | `(?~\|abc\|\O*)z` | `xabz` | M 0-4 | M 0-4 | M 0-4 | M 0-4 | yes |
| ab10 | `(?~\|abc).*` | `xxabcyy` | M 0-2 | M 0-2 | M 0-2 | M 0-2 | yes |
| ab11 | `(?~\|abc)(?~\|).*` | `xxabcyy` | M 0-7 | M 0-7 | M 0-7 | M 0-7 | yes |
| ab12 | `(?:(?~abc)z\|.*)` | `xabcyy` | M 0-6 | M 0-6 | M 0-6 | M 0-6 | yes |
| ab13 | `(?:(?~\|abc\|\O*)z\|.*)` | `xabcyy` | M 0-6 | M 0-6 | M 0-6 | M 0-6 | yes |
| ab14 | `(?:(?~\|abc)z\|.*)` | `xabcyy` | M 0-6 | M 0-6 | M 0-6 | M 0-6 | yes |
| ab15 | `(?:(?~\|abc)\O*z\|\O*)` | `xabcz` | M 0-5 | M 0-5 | M 0-5 | M 0-5 | yes |
| ab16 | `(?~abc)\O*` | `xabcy` | M 0-5 | M 0-5 | M 0-5 | M 0-5 | yes |
| ab17 | `(?~\|abc\|x*)a` | `xxxabcy` | M 0-4 | M 0-4 | M 0-4 | M 0-4 | yes |
| ab18 | `(?:(?~\|abc\|x*)z\|\O*)` | `xxabcz` | M 0-6 | M 0-6 | M 0-6 | M 0-6 | yes |
| ab19 | `(?~\|abc\|x*)y` | `xxxabcy` | M 6-7 | M 6-7 | M 6-7 | M 6-7 | yes |
| ab20 | `(?~\|abc\|(?:x\|\O\O\O\O))q` | `xabcqqq` | M 2-7 | M 2-7 | M 2-7 | M 2-7 | yes |
| ab21 | `(?~\|abc\|(?:xx\|x)*)xa` | `xxxabc` | M 0-4 | M 0-4 | M 0-4 | M 0-4 | yes |
| ab22 | `(?~\|abc\|(?:x\|y)*)\O*` | `xyabcxy` | M 0-7 | M 0-7 | M 0-7 | M 0-7 | yes |
| ab23 | `(?~\|abc)(?:(?~\|)\O*z\|\O*)` | `xxabcyy` | M 0-2 | M 0-2 | M 0-2 | M 0-2 | yes |
| ab24 | `(?~\|(?:a\|)\|(?:x\|y)*)` | `xya` | M 0-0 | M 0-0 | M 0-0 | M 0-0 | yes |
| ab25 | `(?~\|(?:)\|\O*)z` | `z` | M 0-1 | M 0-1 | M 0-1 | M 0-1 | yes |
| ab26 | `(?~)z` | `xz` | M 1-2 | M 1-2 | M 1-2 | M 1-2 | yes |
| ab27 | `(?~\|ab\|\O*)(?~\|cd\|\O*)z` | `xxcdabz` | M 0-7 | M 0-7 | M 0-7 | M 0-7 | yes |
| ab28 | `(?:(?~ab)c)*` | `xcxcabc` | M 0-4 | M 0-4 | M 0-4 | M 0-4 | yes |
| ab29 | `(?:(?~\|ab)c)*\O*` | `xcabcc` | M 0-6 | M 0-6 | M 0-6 | M 0-6 | yes |

Rocq build of the recorded run (untimed, not a measurement): Fold.v
0.87 s, Absent.v 1.16 s, Desugar.v 0.82 s, Cases.v 1.37 s.

The 11 cases of experiment #8 give the same results as in experiment #8
after changes C1-C6 to `Absent.v` (`LEMMAS.md`, last section).

## Mutation check: do the new cases see each restore?

Scratch, not part of the development ([raw](2026-11-26-exp-08-lemmas-raw/mutants/)):
eight copies of `Desugar.v`, each with one part of the desugaring
removed, run on the 29 cases (first match against C, and list of ends
against `m`).

| Mutant | Removed | First match differs | List of ends differs |
|--------|---------|---------------------|----------------------|
| M1 | engine restore `UpdRRFromStack id; Fail` (alternative becomes `Fail`) | ab13, ab14, ab15 | ab13, ab14, ab15 |
| M2 | tail re-install through `id3` | ab20 | ab20 |
| M3 | range clear restore | ab23 | ab23 |
| M4 | simple path's final `UpdRRFromStack id1` | ab16, ab26 | ab16, ab26 |
| M5 | atomic group of the general path | none | ab05, ab07, ab09, ab20, ab21, ab22, ab27 |
| M6 | simple-path dispatch (every `AbsExp` general) | none | none |
| M7 | tail restore through `id1` | ab21, ab22, ab25, ab27 | same |
| M8 | rewind `UpdSFromStack id2` | ab09, ab20, ab21, ab27 | ab05, ab07, ab09, ab20, ab21, ab22, ab27 |

Every restore the plan lists is exercised by at least one case that
fails without it. M6 changes nothing: the simple and the general path
agree (CB-001). M5 changes no first match, only the lists (the
non-possessive scan repeats `e` under the same cut), so the list
comparison is what checks the atomic group. M1 is invisible on the
simple path (ab12, `AbsRep`): with the loop's lower bound 0, the
zero-iteration end always runs the final `UpdRRFromStack id1`, so the
engine restore is redundant there; it matters on the general path and
for the stopper.

## Lemma F bound

`unravel [223]` and `unravel [115;83]` are one segment of five
alternatives; `m [83;115] 6 [R (ILit [223])] 0 = []` and at fuel 7 it
is `[2]`, so the bound `f >= 7` of `LEMMAS.md` is tight for (F1)
([Kcheck](2026-11-26-exp-08-lemmas-raw/Kcheck.out)).

## Effort (run 1)

Failing invocations during development, all fixed before the recorded
run (also in `effort.tsv`): `Cases.v` 1 (a `*)` inside a pattern in a
comment closed the comment; patterns moved out of the comments);
mutation scratch files 2 (`String` imported after use; `length`
resolved to `String.length`). `Absent.v`, `Desugar.v`: first build
passed. No human intervention. Two SSH connection resets by the bench
host at the start; the run then used one multiplexed connection.

## Analysis and limits

- The state-threaded model reproduces the C library on every case,
  including those whose result depends on a restore (ab12-ab16, ab20,
  ab22, ab23, ab25), and `m` and `md` agree beyond the first match.
  Lemma 2 (run 2) can start on these definitions.
- The model's faithfulness to `match_at` is established only on this
  corpus of 29 cases (first match only, since the C harness reports
  one match); patterns outside it, in particular other loops around an
  absent construct than ab28 and ab29, are covered by the lemma (which
  relates `m` and `md`) but not by a comparison with C.
- No C/direct disagreement: no deviation-log candidate.
- Open for later runs: lemma F and lemma 2 proofs in Rocq (run 2),
  Verus (runs 3-4).
