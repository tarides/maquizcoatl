# Experiment #9, entry 20: run-13 review fixes (correction 8)

**What.** Two decision-free fixes from the independent review of run 13
([issue #4 comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7168916617)),
both about the `failing` column that `brittle.sh` writes into
`modules.tsv` and `checks.tsv`. Entry 19
([F\* M3](2026-11-25-exp-09-fstar-m3.md)) and its raw files are not
edited; this entry corrects them. Nothing was re-run: the corrected
tables are re-derived from run 13's own logs (`logs.tar.xz`) with the
amended parser. The proof, the matrix and its verdicts are unchanged.

**Why.** The M4 comparison reads the brittleness matrix from these
tables; a failure must be identifiable from the table alone, without
opening the logs.

## Fix 1: a module after a failed one is marked

`brittle.sh`'s header said that a module checked after a failed one
"may then fail on the missing .checked file of a failed dependency".
That is wrong: in both failing cells (4.15.3/4 and its replication
`rep1`), `Proof.fst` reports Warning 241 (cannot load
`cache/ProofSim.fst.checked`, will recheck `ProofSim.fst`), rechecks
`ProofSim` without sending its queries to the solver (83 queries in
`Proof.log` in all 34 rows, none from a `ProofSim` definition), checks
its own queries, reports Warning 247 (`cache/Proof.fst.checked` not
written, because `ProofSim`'s does not exist) and exits 0. Entry 19
says so in prose, but `modules.tsv` showed `Proof` as exit 0 with an
empty `failing` cell.

`fail_items` now reports these two warnings: `dep-missing:<Dep>(Warning241)`
(the module named in the Warning 241 header) and
`not-written:<Module>(Warning247)` (only when its reason is a missing
`.checked` file). Since the `failing` cell is no longer empty, the
module also appears in the `checks.tsv` `failing` column. The header
comment now describes what F\* does.

## Fix 2: the `failing` column keeps the query key

The column named a failed query by its definition only
(`failed:ProofSim.case_star_null x1`); goal 29 was only in the log and
entry 19. Items are now keyed by the full `Query-stats` key
(definition, index, goal), with the number of failed attempts for that
key: `failed:ProofSim.case_star_null,2,goal29 x1`. A query that
failed and then succeeded on F\*'s own fuel/ifuel retry is
`recovered:<definition>,<index>,goal<n> xK` (none in run 13; checked
on a two-line synthetic log). The header documents the item syntax.

## Corrected tables

[rederive.sh](2026-11-25-exp-09-correction-8-raw/rederive.sh) extracts
entry 19's `logs.tar.xz`, takes `fail_items` from the amended
`brittle.sh`, and rewrites only the `failing` column of
`modules.tsv` and `checks.tsv`; every other column is copied.
Output: [fstar/modules.tsv](2026-11-25-exp-09-correction-8-raw/fstar/modules.tsv),
[fstar/checks.tsv](2026-11-25-exp-09-correction-8-raw/fstar/checks.tsv).
Against entry 19's tables, columns 1-12 of `modules.tsv` and every
column of `checks.tsv` except `failing` are identical; the only rows
that change are the four `ProofSim`/`Proof` rows of 4.15.3/4 and `rep1`
and their two `checks.tsv` rows:

| table | row | failing (entry 19) | failing (corrected) |
|---|---|---|---|
| `modules.tsv` | 4.15.3/4, `ProofSim` | `Error19@ProofSim.fst(466,78-466,99); failed:ProofSim.case_star_null x1` | `Error19@ProofSim.fst(466,78-466,99); failed:ProofSim.case_star_null,2,goal29 x1` |
| `modules.tsv` | 4.15.3/4, `Proof` | (empty) | `dep-missing:ProofSim(Warning241); not-written:Proof(Warning247)` |
| `checks.tsv` | 4.15.3/4 | `ProofSim: Error19@...; failed:ProofSim.case_star_null x1` | `ProofSim: Error19@...; failed:ProofSim.case_star_null,2,goal29 x1; Proof: dep-missing:ProofSim(Warning241); not-written:Proof(Warning247)` |

The `rep1` rows change identically. The other 32 cells still have an
empty `failing` cell for every module (`-` in `checks.tsv`).

The amended `fail_items` was also run, untimed, on the bench host's
own copies of the 35 cell directories (GNU Awk 5.2.1 there, 5.3.2
locally): the same four non-empty results.

## Provenance

- Local worktree at `431a790` plus this entry's changes; GNU Awk 5.3.2,
  bash. Bench host: GNU Awk 5.2.1, one untimed pass of `fail_items`
  over `<bench-workdir>/exp/09-representative-proof/out/r13/`, under
  `nice -n 10`, no CPU pinning (a text parse, not a measurement).
- Inputs: entry 19's `fstar/logs.tar.xz`, `modules.tsv`, `checks.tsv`
  (unchanged).

## Effort

[effort.tsv](../09-representative-proof/effort.tsv), `13-fix` rows:
session from 17:03:36Z to 17:05:51Z (taken just before the commit); `fail_items` right at
the second attempt (the first read the warning header's fields with
the tab separator and matched nothing; caught by the test on the
run-13 logs before anything was recorded); 0 human interventions.

## Open

- Maintainer decision (not acted on): whether to harden
  `ProofSim.case_star_null` goal 29 (an explicit `assert (pc' == pcB)`
  or a local rlimit) and possibly `case_chk_null` goal 20, or to leave
  the proof as written and let M4 report it as checked; if hardened,
  whether M3 is re-run on the new sources before M4, since the matrix
  is tied to source digest `952aade9…`.
- Verus M3 (run 14).
