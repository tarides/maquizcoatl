# Experiment #8 follow-up (issue #34), entry 4: Rocq proofs (run 2)

**What.** Run 2 of plan `plans/08-discriminating-lemmas.md`: the Rocq
proofs of both lemmas, the range clear, the decision-6 stretch, the
rerun of run 1's eight desugaring mutants on all 29 cases (run-1 review
fix), and experiment #9's measurements (`axioms.sh rocq`, `timed.sh
rocq`, `loc.py`, `lemmas.py`). Result: both main lemmas are closed under
the global context: `sharp_s_sym` (lemma F, F1 and F2) and
`absent_desugar_eq` (lemma 2, (2a) and (2b), for `AbsRep`, `AbsExp` on
both paths, the stopper and the range clear). The stretch `fold_lit` is
closed too. No admit, no axiom. Lemma 2 needed one hypothesis that run 1's
statement lacked, `i <= rr <= length s` (see "Statement change").

**Why.** Run 2's done-when: "`Print Assumptions` closed for both main
lemmas; measurement entry". Decision 1 makes experiment #9's units the
measure; decision 2 asks for the range clear proved or named out;
decision 6 asks for the stretch outcome either way; the run-1 review
(issue #34, problem 1) asked for the mutation check on 29 cases.

**Provenance.** [Entry 1](2026-11-26-exp-08-lemmas-provenance.md) for the
host, toolchain (Rocq 9.3.0, rocq-stdlib 9.2.0, OCaml 5.4.1, switch
`provers`) and CPU sets. Proofs at branch commit `c8b8840`; SHA-256 of
the sources in [`sha256.txt`](2026-11-26-exp-08-lemmas-rocq-raw/sha256.txt).
Session start 2026-11-26T14:11:22Z; proofs written interactively with
`rocq compile -R . S <file>.v` on the bench host (nice -n 10, taskset -c
8-11, one job), every invocation logged in
[`invocations.tsv`](2026-11-26-exp-08-lemmas-rocq-raw/invocations.tsv)
(UTC, rc, SHA-256 of the file and of all sources, first error line).
Commands of the measurements, on `<exp>/repo` at `c8b8840`:

    BENCH_WORKDIR=<bench-workdir> axioms.sh rocq r2                 # untimed, CPUs 8-11
    flock <exp>/timed.lock env CPUS=24-27,56-59 timed.sh rocq r2     # timed
    python3 -I loc.py Fold.v Absent.v Desugar.v FoldProof.v AbsentMono.v AbsentProof.v Cases.v
    python3 -I lemmas.py FoldProof.v AbsentMono.v AbsentProof.v
    mutants/run.sh                                                  # untimed, CPUs 8-11

All exit 0. Before the timed series, no thread was above 1% on CPUs
24-27,56-59 and the load average was 0.33 ([`precheck.txt`](2026-11-26-exp-08-lemmas-rocq-raw/rocq/precheck.txt));
the load rose to 2.9 during the second series (other work on the host,
not on the pinned CPUs); the three series agree within 0.02 s per file.
Raw data: [raw](2026-11-26-exp-08-lemmas-rocq-raw/).

## Lemmas closed

| Plan item | Rocq | File | Status |
|-----------|------|------|--------|
| Lemma F (F1, F2), fuel `7 + f` | `sharp_s_sym` | `FoldProof.v` | closed |
| Stretch (decision 6): one-level fold for every literal | `fold_lit` (+ `segs_m`) | `FoldProof.v` | closed |
| (b) monotonicity, determinism of `mb`, `cut`, `m` (both fuels), `md` | `mb_mono`, `cut_mono`, `m_mono`, `md_mono`, `*_det` | `AbsentMono.v` | closed |
| (a)/(c) absent-free stack + engine continuation; termination | `core_K`, `term_core`, `mb_term`, `attempt`, `attempt_inv` | `AbsentProof.v` | closed |
| (d) scan for a general step (`AnyO`, `Chr c`) | `scan_a`, `scan_b` | `AbsentProof.v` | closed |
| direct side: cut, `Ends`, `x*` | `scan_spec`, `scan_intro`, `m_ends_a/b`, `mstar_a/b`, `cut_term` | `AbsentProof.v` | closed |
| (e) `AbsExp` general path, (f) stopper, (h) range clear | cases of `sim_a`, `sim_b` | `AbsentProof.v` | closed |
| (g) main theorem | `sim_a` (2a), `sim_b` (2b), `absent_desugar_eq` | `AbsentProof.v` | closed |

**Range clear (decision 2): proved, in scope.** It is one case of the
induction in each direction (5 to 6 lines) plus four unfolding and
inversion lemmas of about 35 lines.

**Stretch (decision 6): closed.** `fold_lit`: for every `w`, `s`, `i`,
`e` and `f` with `cost (unravel w) <= f`, `In e (m s (S f) [R (ILit w)]
i)` iff `fold_rel s i (unravel w) e`. The induction is on the list of
segments and their alternatives (for any segment list), not on `w`
through `unr` as the plan suggested, so no lemma about `unr` is needed.
The fuel bound is the number of alternatives plus 2; for `[0xDF]` it is
7, the tight bound of (F1).

**Simple-path coverage (run-1 review follow-up).** Lemma (d) covers
`AbsExp a (Star (Chr c))` on the simple path. No corpus case
distinguishes the two paths (M6 below changes nothing), so that part of
lemma 2 rests on the reading of `is_simple_one_char_repeat`
(`upstream/src/regparse.c:3194-3236`) in `desugar`, not on a C case.

## Statement change: `i <= rr <= length s`

Run 1's `LEMMAS.md` stated lemma 2 for every register `rr`. It is false
for `rr > length s`: on the empty subject at `i = 0`, `rr = 2`, the
direct `m` on `AbsRep (Chr 7)` returns the ends `[2; 1; 0]` (the cut
scans to the register) while `md` on its desugaring returns `[0]` (the
engine's `\O` step stops at the subject end):
[`Rcheck.v`, `Rcheck.out`](2026-11-26-exp-08-lemmas-rocq-raw/mutants/).
The proved statement assumes `i <= rr <= length s`. Every start of a
search satisfies it (`rr = length s`) and both matchers preserve it, so
the theorem covers every pattern a search runs; the cases and the
search-level behaviour are unchanged. (2a) is also stronger than
written: `md` ends with the starting register (`Some (rs, rr)`), and
(2b) proves `x = rr`. `LEMMAS.md` records both (section "The
statement"). This is a correction of run 1's statement, not of a
maintainer decision.

## Axiom report (`axioms.sh rocq`)

[`axioms.txt`](2026-11-26-exp-08-lemmas-rocq-raw/rocq/axioms.txt):
clean build of `Fold FoldProof Absent Desugar AbsentMono AbsentProof`
and `Axioms.v`:

    Print Assumptions FoldProof.sharp_s_sym.        Closed under the global context
    Print Assumptions AbsentProof.absent_desugar_eq. Closed under the global context
    == scan (Admitted|admit|Axiom|Parameter|Conjecture|Hypothesis|Abort) ...
    == end of scan                                  (no hit)

`fold_lit` is also closed (its `Print Assumptions` in `FoldProof.v`).

## Check time (`timed.sh rocq`, CPUs 24-27,56-59, three clean checks)

| File | Wall clock (s), runs 1-3 | Median | Max RSS (MB) |
|------|--------------------------|--------|--------------|
| Fold.v | 0.88, 0.88, 0.89 | 0.88 | 389 |
| FoldProof.v | 2.14, 2.14, 2.15 | 2.14 | 424 |
| Absent.v | 1.18, 1.18, 1.19 | 1.18 | 411 |
| Desugar.v | 0.82, 0.82, 0.82 | 0.82 | 331 |
| AbsentMono.v | 2.55, 2.55, 2.55 | 2.55 | 443 |
| AbsentProof.v | 3.60, 3.62, 3.60 | 3.60 | 493 |
| **total** | 11.17, 11.19, 11.20 | **11.17** | |

User and system times in [`time.tsv`](2026-11-26-exp-08-lemmas-rocq-raw/rocq/time.tsv),
load before each check in `time.load`.

## Size (`loc.py`) and lemmas (`lemmas.py`)

| File | Origin | Spec | Proof | Cases |
|------|--------|------|-------|-------|
| Fold.v | experiment #8, unchanged | 64 | 6 | 11 |
| Absent.v | experiment #8 with C1-C6 | 85 | 27 | 0 |
| Desugar.v | new definitions (run 1) | 112 | 0 | 0 |
| FoldProof.v | run 2 | 10 | 90 | 0 |
| AbsentMono.v | run 2 | 12 | 76 | 0 |
| AbsentProof.v | run 2 | 62 | 1056 | 0 |
| Cases.v | run 1 | 28 | 0 | 58 |

Run 2's proofs: 1222 proof lines (lemma F and stretch 90, lemma 2 1132),
84 spec lines of auxiliary definitions (`core`, `in_scope`, `rel`, the
measure, `fold_rel`). `lemmas.py`: 105 lemmas (11 in `FoldProof.v`, 8 in
`AbsentMono.v`, 86 in `AbsentProof.v`), automatic share 0 (no proof is a
single automation tactic), 0 admitted. The largest proofs are `sim_b`
(266 tactic sentences) and `sim_a` (247): [`lemmas.txt`](2026-11-26-exp-08-lemmas-rocq-raw/lemmas.txt).

## Effort

| Measure | Value |
|---------|-------|
| Session | start 14:11:22Z; first proof compile 14:21:57Z, last 15:16:31Z (54 min 34 s); end 2026-11-26T15:22:01Z at this entry's commit |
| Compile invocations | 43: 12 passing, 29 failing, 2 interrupted (a looping tactic, killed after 110-120 s) |
| Failing per file | `FoldProof.v` 1, `AbsentMono.v` 6 + 2 interrupted, `AbsentProof.v` 22 |
| Per-lemma attempts | `lab/08-discriminating-lemmas/effort.tsv`, run-2 rows |
| Human interventions | none |

Every failure was a proof-script error (argument inference, fuel names
after `destruct`, `simpl` unfolding `Nat.eqb (S q) q`, tactic order); no
lemma statement other than the register hypothesis above was changed
after a failed attempt. Two invocations used `Show` to read goals and are
counted as failing.

## Mutation check on 29 cases (run-1 review fix)

The eight mutants of run 1 (`DM1`-`DM8`, unchanged) with drivers
extended to ab28-ab29, plus a control on the recorded `Desugar.v`
([`mutants/`](2026-11-26-exp-08-lemmas-rocq-raw/mutants/), 19 s):

| Mutant | First match differs | List of ends differs |
|--------|---------------------|----------------------|
| control (`Desugar.v`) | none | none |
| M1 engine restore removed | ab13, ab14, ab15, **ab29** | ab13, ab14, ab15, ab29 |
| M2 tail re-install removed | ab20 | ab20 |
| M3 range-clear restore removed | ab23 | ab23 |
| M4 simple path final restore removed | ab16, ab26 | ab16, ab26 |
| M5 general path not atomic | none | ab05, ab07, ab09, ab20, ab21, ab22, ab27 |
| M6 no simple-path dispatch | none | none |
| M7 tail restore removed | ab21, ab22, ab25, ab27 | ab21, ab22, ab25, ab27 |
| M8 rewind removed | ab09, ab20, ab21, ab27 | ab05, ab07, ab09, ab20, ab21, ab22, ab27 |

Same as run 1 on ab01-ab27; on the two loop cases, ab29 (the stopper in
a loop) also detects M1, and nothing else changes. The two no-effect
statements that the run-1 review fixes qualified (M5 changes no first
match; M6 changes nothing) hold on all 29 cases.

## Analysis and limits

- In Rocq, lemma 2 took 1132 proof lines and about 55 minutes of
  proof writing; experiment #8's largest proof was 64 lines. The work
  is in the stack relation and the scan, not in the absent cases: once
  `scan_a`/`scan_b` hold for a general step and a continuation with a
  register function `h`, AbsRep, both AbsExp paths, the stopper and the
  range clear are cases of one induction. The design note "the explicit
  restores are implicit" became the invariant that `md` on a related
  stack ends with its starting register.
- Two facts were not in the plan's lemma list. The simple path needs the
  termination of the absent-free matcher `mb` (its scan can stop before
  the cut, so the direct side evaluates `occ` at positions the
  desugared side never visits); `term_core` gives it, by induction on
  `(rr - i, size)`. And the statement needs `rr <= length s`.
- What the theorem does not cover: faithfulness of `md` to the C
  library beyond the 29 first matches (decision 4); fuel adequacy (both
  directions are existential in the other side's fuel, decision 3);
  nested absent constructs; registers above the subject length.
- Verus (run 3) mirrors C1-C6 and must state the same register
  hypothesis; whether its SMT automation handles the stack relation
  and the two scans is the experiment's question.
