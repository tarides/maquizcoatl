# Experiment #9, entry 24: run-15 review fixes (correction 10)

**What.** The decision-free fixes to [entry 23](2026-11-25-exp-09-m4-comparison.md)
(M4 comparison, run 15) from the independent review of run 15
([issue #4 comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7172181191)),
which accepted the comparison. Entry 23 is not edited; this entry
corrects it. The draft done-criterion-5 comment, which is not posted,
is edited with fixes 1, 2 and 4. No prover was run; the figures below
are read from entry 23's sources or recomputed on the workstation with
the branch's `lemmas.py`. Every other figure of entry 23 stands.

**Why.** One sentence of entry 23's F\* verdict is false, the closing
paragraph overstates done-criterion 4, one table row mixes units, and
one count is off by one. The draft must be right before the maintainer
reviews it for posting (plan step 8).

## Fix 1: F\* does not have the fewest failed checks

Entry 23 section 9 (F\* verdict) says F\* has "the fewest failed checks
on the session record (7; 13 failing invocations)". This is withdrawn:
Verus has fewer on both units (6 failed checks, 6 failing invocations;
entry 16, `invocations.tsv`), as section 1's own table shows. The
sentence is a carry-over from entry 14's two-tool comparison. It reads:
F\* has **fewer failed checks than Rocq (7, resting on the session
record; 13 failing invocations against Rocq's 19), but not fewer than
Verus (6 on both units)**. The draft's F\* "Result" bullet is changed
the same way.

## Fix 2: done-criterion 4 does not apply to Rocq

Entry 23's closing paragraph ("Across the three") says done-criteria
1-4 are met for the three tools; section 7 marks criterion 4 not
applicable to Rocq. It reads: **done-criteria 1-3 are met for all
three; done-criterion 4 for F\* (32 of 33 cells, every failure recorded)
and Verus (33 of 33); it does not apply to Rocq**. Each tool still
needed one M2 run of the three planned. The draft's closing paragraph
is changed the same way.

## Fix 3: the "largest item" row, in one unit

Entry 23 section 4's "largest item" row compared `sim` in tactic
sentences, a module (`ProofSim.fst`, 503 SMT queries, not an item) and
`case_group` in lines. In one unit, non-blank lines of the item after
stripping comments (the declaration through its proof; `lemmas.py`'s
column 4 for F\* and Verus, the same rule from `Lemma` to `Qed.` for
Rocq):

| | Rocq | F\* | Verus |
|---|---:|---:|---:|
| largest proof item | `sim`, 298 lines (`ProofSim.v`) | `case_group`, 35 lines (a proof function; next `sim`, 32) | `case_group`, 77 lines |

The row stays a description, not a comparison: Rocq's `sim` is one
lemma covering every case, while F\* and Verus split the simulation
into one item per case (`case_*`), so the largest item measures how
each proof is cut, not its effort. Section 4's lemma counts and
automatic shares are unchanged.

## Fix 4: Rocq's session total has no M3

The draft's single "all recorded sessions" row gave Rocq 45 min 18 s
beside F\*'s 57 min 03 s and Verus's 58 min 22 s, which include 25 min
11 s and 16 min 00 s of M3. The draft's Rocq cell now says "no M3
session" and its session-time note says the totals are not comparable
effort. Entry 23's section 1 table already lists the M3 row; it is
unchanged.

## Fix 5: 17 `human interventions` rows

Entry 23 section 1 says `effort.tsv` has "16 rows `human
interventions`, all 0". With run 15's own row there were 17, all 0
(run 15-fix adds an 18th, also 0).

## Fix 6: `lemmas.py` measures the F\* admitted count

`lemmas.py`'s F\* branch printed `admitted 0` as a literal (correction
7, Open; entry 23, Open). It now counts, as the Verus branch does, the
items whose declaration uses `admit`, `assume` or `magic` (as words,
after stripping comments) and every top-level `assume val`; such an
item has kind `ADMITTED` and still counts as a lemma when its type is a
`Lemma`. `axioms.sh` stays the authoritative admit check. On the
branch's eleven `.fst` files the output is byte-identical to before
(43 lemmas, 3 automatic, admitted 0). On a scratch test file with an
`admit ()` lemma, an `assume val` lemma, a `magic ()` function, an
automatic lemma and an `admit` inside a comment, it reports admitted 3,
lemmas 4, automatic 1, as intended. The test file is not kept.

## Provenance

Workstation only, from the branch at `04d0481`
(`exp/09-representative-proof`); Python 3 for `lemmas.py` (`python3
-I`). No bench-host work, no prover.

## Effort (this run)

[effort.tsv](../09-representative-proof/effort.tsv), rows `15-fix`.

## Open

- Run 13's `logs.tar.xz` records a local username as tar owner of its
  682 entries (run 14's records 0/0). Re-packing it rewrites a recorded
  raw file; the maintainer decides before PR #32 leaves draft.
- Maintainer's review of the comparison (plan step 8); once accepted,
  the draft (with fixes 1, 2 and 4) is posted as the done-criterion-5
  comment.
