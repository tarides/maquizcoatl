# Experiment #8, entry 5: ONIG_OPTION_FIND_LONGEST

**What.** The search-level FIND_LONGEST semantics of `SEMANTICS.md`
section 3 (fold over every start and every result in priority order,
keeping the first result of strictly greater length) in the four tools,
run on the 6 cases, with lemma L proved: if the first-match search
returns `(s1, e1)`, FIND_LONGEST returns some `(s2, e2)` with
`e2 - s2 >= e1 - s1`.

**Why.** Third feature of step 4.

## Provenance

Sources `lab/08-hard-features/{rocq/Longest.v, lean/Longest.lean,
fstar/Longest.fst, verus/longest.rs}` at commit `27eea1c`; timed runs
`timed-{1,2,3}`. Host, versions, cap and CPU set as in [entry 1](2026-11-19-exp-08-setup.md). Times: median of three sequential runs of `lab/08-hard-features/check.sh <tool> <Feature> <run>` (`timed.sh`), wall-clock of the whole file check including tool start-up; peak RSS is `/usr/bin/time -v`'s maximum resident set size of the largest single process (for Verus, `rust_verify`; Z3 runs in a separate process and is not included). Load average at the timed runs: 2.1-4.2 (experiment #5's install on other cores). Raw logs, `/usr/bin/time` output, load and assumption-check output per run: [raw/timed-1/](2026-11-19-exp-08-raw/timed-1/), `timed-2/`, `timed-3/`; line counts by `lab/08-hard-features/loc.py` ([raw/loc.tsv](2026-11-19-exp-08-raw/loc.tsv)). Native computation (`native_decide`, `native_compute`) is used nowhere, so no `Lean.ofReduceBool` axiom appears; every case and every main lemma is checked by the kernel (Rocq `vm_compute`, Lean `decide +kernel`), by F\*'s normaliser (`assert_norm`) or by Verus's interpreter (`by (compute_only)`). Fuel (1000 steps) is used by all four tools; it is computability help for Rocq and Lean, and is kept in F\* and Verus so that the four definitions are the same (SEMANTICS.md, "Common design").

## Raw data

| Tool | Spec / proof / cases lines | Check s (median) | Peak RSS MB | Cases (agree with C) | Lemma L | Assumption check |
|------|------|-----:|-----:|------|------|------|
| Rocq | 62 / 35 / 6 | 1.11 | 401 | 6/6, `vm_compute` | proved (for every fuel), kernel-checked | closed under the global context; grep: none |
| Lean | 50 / 51 / 6 | 0.72 | 504 | 6/6, `decide +kernel` | proved, kernel-checked | `propext`, `Quot.sound`; grep: none |
| F\* | 50 / 26 / 6 | 0.90 | 113 | 6/6, `assert_norm` | proved (SMT) | grep: none |
| Verus | 78 / 51 / 9 | 1.30 | 322 | 6/6, `by (compute_only)` | proved (SMT) | grep: none |

F\*: a negative control (lemma strengthened to `<`) is rejected.

## Automation failures and manual help

- **Rocq, automation failure** (`rocq/Longest.v:37-40`, `104-120`):
  `simpl` in the lemmas unfolded the 1000-step fuel of the matcher and
  stalled, and so did the kernel check at `Qed` of the final theorem
  (more than 60 s, killed twice). Fixed by writing both searches generic
  in the per-start result function and by stating the theorem for every
  fuel `f` (`search_f f`, `longest_f f`), `search` and `longest`
  being their instances at 1000. The statement is thus slightly stronger
  than in the other tools.
- **Lean**: none (one hypothesis-naming fix after `obtain ⟨rfl, rfl⟩`).
- **F\***, **Verus**: none; both verified at the first attempt, with
  four short lemmas whose bodies are the recursive calls.

## Analysis

Lemma L is the most "proof-like" of the four (four inductions over the
search folds), and the SMT tools did it with less text than the
interactive ones (F\* 26 lines, Lean 51). Rocq is the only tool where the
fuel constant leaked into conversion checking, here and in entry 4: an
interactive-prover cost of computing with a fuel-based definition in the
same development as proofs about it. Not covered: backward search, which
`doc/API:104` says FIND_LONGEST does not support properly.
