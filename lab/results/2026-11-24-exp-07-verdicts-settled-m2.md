# Experiment #7, verdicts settled against experiment #6's milestone 2 `T_spec`

**What.** Experiment #7's nine open table verdicts ("in-prover"
definition of the Unicode property table when `T_table <= T_spec`),
settled against experiment #6's **milestone 2** `T_spec`, the S2
semantics of run 2. `T_spec` is read as a lower bound on the full
spec's build time (Decision 5 of experiment #6's plan, option (c)). This
entry follows the [milestone 1 settling
entry](2026-11-20-exp-07-verdicts-settled.md) and does not edit it.

**Why.** Question 2 of issue #28: does a larger semantics settle any
target? Verdicts already settled are not revisited. Milestone 1 settled
none.

## Provenance

- `T_spec`: experiment #6 milestone 2, run 2
  ([T_spec entry](2026-11-24-exp-06-m2-run2-t-spec.md)). Rocq, Lean 4,
  Why3 and F\* were measured in one series on the bench host, scripts at
  `e293368`, pinned to CPUs 28-31,60-63, with a 1-minute load of
  1.00-1.35.
- `T_table`: experiment #7's idle rerun, runs 11-13, from the milestone
  1 settling entry (1-minute load 1.06-2.94). Plan step 9 reuses it when
  milestone 2's `T_spec` series runs at a comparable load (1-minute load
  at most 8). Here it did (1.00-1.35), so experiment #7's `timed.sh` was
  not rerun. Same host, CPU set, lock, tool versions and toolchain
  cache.
- For experiment #7's C targets the comparison basis is the same
  tool's spec check plus its OCaml target, as in milestone 1 (the
  semantics use lists and unbounded integers and have no C extraction).
  Lean's basis is its C target (`lean -c` and `leanc`).

## Settled verdicts

| Target | T_table idle s | T_spec s (milestone 2) | T_table / T_spec (milestone 2) | Milestone 1 ratio | Ratio shrank by | Verdict |
|--------|------:|------:|------:|------:|------:|------|
| Rocq -> OCaml | 58.53 | 3.86 | 15.2 | 39 | 2.6x | open (#7's provisional verdict stands) |
| Lean -> C -> native | 60.88 | 2.02 | 30.1 | 54 | 1.8x | open (#7's provisional verdict stands) |
| Why3 -> OCaml | 15.46 | 1.52 | 10.2 | 33 | 3.2x | open (#7's provisional verdict stands) |
| Why3 -> C (decision trees) | 12.47 | 1.52 | 8.2 | 27 | 3.3x | open (#7's provisional verdict stands) |
| F\* -> OCaml | 40.05 | 7.86 | 5.1 | 32 | 6.3x | open (#7's provisional verdict stands) |
| F\* -> KaRaMeL C (decision trees) | 50.32 | 7.86 | 6.4 | 40 | 6.2x | open (#7's provisional verdict stands) |
| F\* -> direct C (decision trees) | 44.71 | 7.86 | 5.7 | 35 | 6.2x | open (#7's provisional verdict stands) |
| F\*/Pulse -> KaRaMeL C (static arrays) | 127.91 | 7.86 | 16.3 | 101 | 6.2x | open (#7's provisional verdict stands) |
| F\*/Pulse -> direct C (static arrays) | 125.17 | 7.86 | 15.9 | 99 | 6.2x | open (#7's provisional verdict stands) |

## Verdicts

- **Settled "in-prover" (for good): none.** No table builds in less
  than milestone 2's `T_spec`, and every target still needs a spec
  5.1-30 times slower to build than S2's.
- **Open, experiment #7's provisional verdict stands:** all nine
  targets, now with the smaller factors above. The closest are F\*'s
  decision-tree targets (5.1-6.4); the farthest are Lean (30) and the
  F\*/Pulse static arrays (16).
- The S2 semantics is about twice milestone 1's in lines (1.9-2.0x for
  Rocq, Lean, Why3 and F\*), and its `T_spec` grew 1.8x (Lean) to 6.2x
  (F\*). If the full spec keeps that relation, F\*'s targets are the
  likeliest to settle "in-prover" first. That is an extrapolation, not
  a verdict.
- These `T_spec` figures include some table handling (loading the
  table module, and for F\* its extracted code), so they overstate the
  semantics' own cost. That works in favour of settling, and still no
  target settles.
- Verus and Isabelle/HOL have no experiment #7 table. Their `T_spec`
  comes in run 3.
