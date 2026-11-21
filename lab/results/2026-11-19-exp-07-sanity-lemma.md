# Experiment #7, entry 5: sanity lemma over the table (criterion 4)

**What.** In every `CR_*` array, `lo <= hi` and `hi_i + 1 < lo_(i+1)`
(sorted, disjoint, non-adjacent; the precondition of
`onig_is_in_code_range`, `upstream/src/regcomp.c:7840`), proved for the
whole table in each prover by computation: a boolean checker shown to
evaluate to `true`, plus a once-for-all proof that the checker is sound
(true implies the propositional statement).

**Why.** Criterion 4: can the prover state and prove a property of the
table, or only evaluate it? A bounded attempt (2 h engineering, 30 min
check per tool). The statement is true (entry 2: 0 violations).

## Provenance

Checker and statement: `lab/07-large-tables/{rocq/Mem.v, lean/Mem.lean,
lean/Sound.lean, why3/mem.mlw, fstar/Mem.fst, fstar/Sound.fst}`, commit
`2072e9c`. The reflection steps ran in timed run 1 of each tool (entry 3
provenance; one run each, 30-minute cap); the soundness proofs of Lean
and F\* and the Why3 attempts ran as exploratory runs on other cores
(Lean `lean -R . Sound.lean`; F\* `fstar.exe --cache_checked_modules
--z3version 5.3.0 Sound.fst`; Why3 commands below). Logs:
[raw/timed/](2026-11-19-exp-07-raw/timed/) (`*-S*.1.log`) and
[raw/explore/](2026-11-19-exp-07-raw/explore/).

## Raw data

Times are the wall-clock of the file containing only the import and the
lemma; the import alone costs Rocq 0.82 s, Lean 0.36 s, F\* 0.54 s.

| Tool | Method | Wall s | Peak RSS MB | Outcome |
|------|--------|-------:|------------:|---------|
| Rocq | `Lemma table_ok_true : table_ok = true. Proof. vm_compute. reflexivity. Qed.` | 0.87 | 306 | **proved** |
| Rocq | same with `native_compute` | 1.32 | 363 | **proved** |
| Rocq | soundness `ok_list_sound`, `table_ok_sound` (induction, `Mem.v`) | (part of `Mem.v`) | | **proved** |
| Lean | `theorem : tableOk = true := by decide` | 0.37 | 464 | fails: "maximum recursion depth has been reached" |
| Lean | same under `set_option maxRecDepth 100000` | 0.45 | 468 | fails: "`decide` failed to reduce ... to `true` or `false`", stuck at `Array.anyM.loop` (well-founded recursion) |
| Lean | `by decide +kernel` (on the `Array` checker) | 38.05 | 4,005 | **proved** |
| Lean | `by decide +kernel` on `tableOkL` (`codeRanges.toList.all`, structural) | 3.58 | 865 | **proved** |
| Lean | `by native_decide` | 0.47 | 481 | proved, but trusts the compiler (recorded separately, as planned) |
| Lean | soundness `okList_sound`, `tableOkL_sound` (`Sound.lean`, exploratory) | 0.45 | | **proved** |
| F\* | `let _ = assert_norm (table_ok = true)` | 5.97 | 254 | **proved** |
| F\* | soundness `ok_list_sound`, `table_ok_sound` (SMT with induction, `Sound.fst`, exploratory) | 49.3 (includes loading `Table`) | | **proved** |
| Why3 | `why3 prove -a compute_in_goal -P alt-ergo -t 5`, goals `table_ok = True`, `all_ok_from 0 = True`, and `ok_list cr_Lu = True` (one array), `meta "compute_max_steps" 1000000000` | 19.07 | 312 | **fails**: all three goals reach Alt-Ergo unreduced and time out; on `ok_list cr_Lu`: "term reduction aborted (term size blows up from 5 to 5233, after 3913 steps)" |
| Why3 | `-a compute` (non-legacy transformation) | 2.2 | | fails: `anomaly: File "src/core/trans.ml", line 503, characters 29-35: Assertion failed` |
| Why3 | `-a simplify_computations` then Alt-Ergo | 19.6 | | fails: Timeout on the three goals |

Why3 engineering time: about 25 minutes (`rewrite_def` metas,
`compute_max_steps`, three transformations); the size guard of Why3's
reduction engine, which is not a configurable meta (the only compute
metas are `compute_max_steps` and `compute_max_domain_size`), stops even
one array (`CR_Lu`, 651 ranges). In timed run 1 the Why3 lemma step itself failed on
an argument-order error (`-T` before the file); the attempt above is the
corrected command, run once on other cores
([raw/explore/why3-S1.s.log](2026-11-19-exp-07-raw/explore/why3-S1.s.log)).

## Analysis

- **Rocq, Lean and F\* prove the lemma for the full table in seconds**,
  with a kernel-checked computation and a short soundness proof of the
  checker. Rocq's `vm_compute` is the fastest (well under a second).
- **Lean's plain `decide` fails** because it reduces with the elaborator's
  `whnf`, which does not unfold `Array.all`'s well-founded loop;
  `decide +kernel` works, ten times faster on a structural `List` checker
  than on the `Array` one (3.6 s vs 38 s, 0.9 vs 4.0 GB).
- **Why3 fails** within the bounded attempt: its `compute_in_goal` gives
  up on term-size growth before it can unfold a single array, and SMT
  provers cannot do the 24k-step evaluation within the time limit. A
  structural route (a lemma per array discharged by SMT, or ghost code)
  is follow-up, outside the milestone.
