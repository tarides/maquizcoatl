# Experiment #8, entry 7: per-feature comparison of the four tools

**What.** The comparison of step 6 of the plan, from entries 3-6: for
each feature, the four tools side by side, interactive (Rocq, Lean 4)
against SMT-based (F\* with Pulse, Verus), and within each kind.

**Why.** Done-criterion "a short comparison of the four tools per
feature"; it feeds the choice of stack, it does not make it. Experiment
#5 had not reported when this ran (maintainer decision to run first); if
it eliminates a stack, the column of that tool concerns an eliminated
stack.

## Provenance

Entries [3](2026-11-19-exp-08-calls.md), [4](2026-11-19-exp-08-absent.md),
[5](2026-11-19-exp-08-find-longest.md), [6](2026-11-19-exp-08-iso-fold.md);
commits `27eea1c` (absent, FIND_LONGEST, folding) and `d66233b` (calls).
Whole run: about 1 h 05 min of wall-clock, of which under 10 minutes of
machine time on the bench host.

## Raw data

Lines are spec + proof (cases apart, see the entries); time is the
median check of the whole file; "help" counts the places listed under
automation failures and manual help (F = a failure that needed a
workaround, H = a hint or restructuring, C = computability help beyond
the shared fuel).

| Feature | Rocq | Lean 4 | F\* | Verus |
|---------|------|--------|-----|-------|
| Calls (lemma C) | 65+18, 1.20 s, H×2 | 56+47, 1.47 s, none | 59+29, 1.92 s, H×1 | 94+64, 3.30 s, H×1 |
| Absent (lemma A) | 80+25, 1.22 s, F×1 | 72+37, 0.84 s, none | 73+12, 1.21 s, none | 117+31, 1.38 s, H×1 |
| FIND_LONGEST (lemma L) | 62+35, 1.11 s, F×1 | 50+51, 0.72 s, none | 50+26, 0.90 s, none | 78+51, 1.30 s, none |
| ISO-8859-1 fold (lemma F) | 64+6, 0.91 s, none | 50+4, 0.63 s, C×1 | 55+2, 3.41 s, H×1 | 96+5, 1.21 s, none |
| Cases run / agree with C | 42/42 | 42/42 | 42/42 | 42/42 |
| Main lemmas kernel-checked | 4/4 (no native) | 4/4 (no native) | n/a (SMT, normaliser) | n/a (SMT, interpreter) |

Every semantics is free of admits and assumptions (per-tool assumption
checks in entries 3-6); no tool needed native computation.

## Analysis

- **All four tools can express all four features** with the same
  first-order design, run every case, and prove every main lemma, each
  file checking in under 3.5 s. None of the four hard features is a
  blocker for any of the four stacks, at this scale.
- **Interactive vs SMT.** On the two lemmas with real induction (C and
  L), F\* needed the fewest proof lines (29 and 26) and no failure; Verus
  needed about as many lines as Lean because its lemmas restate every
  branch, but it never failed on L. The interactive tools needed
  hand-written case analyses (Lean) or tactic loops (Rocq). The SMT
  tools' manual help is local and cheap (`reveal_with_fuel`, a
  `decreases` clause, `move_requires`).
- **Within the interactive kind.** Lean was smoother: no automation
  failure on any lemma, `decide +kernel` ran every case, its one
  problem was computability (a definition compiled by well-founded
  recursion is irreducible, so kernel evaluation stalls, as experiment
  #7 also found). Rocq had the two real failures of the experiment:
  `simpl` and kernel conversion unfolding the 1000-step fuel when the
  fuel-based matcher appears in a lemma's statement (absent, FIND_LONGEST),
  fixed by abstracting the matcher out of the lemmas. Rocq's proofs are
  the shortest where a tactic loop applies (calls: 18 lines).
- **Within the SMT kind.** F\* was the most economical (smallest files,
  fewest hints, lowest memory, about 120 MB). Verus needs an own list
  type for its interpreter to run cases and an explicit
  membership-in-append lemma, so its encodings are the largest (78-117
  spec lines), and its interpreter is the slowest on a long subject
  (ca06: +1.6 s).
- **Per feature.** Calls with a nest-limit parameter and the absent
  operator's right-range register are ordinary state in every tool;
  FIND_LONGEST is a fold at search level and its lemma is the only one
  where proof effort differs much (26 to 51 lines); ISO-8859-1 folding is
  pure data and its lemma is computation.
- **Limits of the probe.** Small cases, a fuel-based matcher, no
  captures, absent patterns absent-free, forward search only, lemma F
  stated on concrete subjects. The kernel/SMT costs measured here are
  those of small definitions; experiment #7 measured large tables.

## Deviation-log candidates

- D-08-1: `upstream/doc/API:1020` gives 24 as the default nest limit;
  the code (`upstream/src/regint.h:115`) and case ca06 give 20.
- Confirmed behaviour: `doc/RE:367`'s equivalence of `(?~absent)` and
  `(?~|(?:absent)|\O*)` holds on the corpus although the two take
  different code paths in `make_absent_tree`.
