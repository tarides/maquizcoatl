# Experiment #9, entry 15: run-7 review fixes (correction 6)

**What.** Three decision-free fixes from the independent review of run 7
([issue #4 comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7166160868)),
all about the evidence behind the F\* M2 effort figures. Entries 13 and
14 ([F\* M2](2026-11-25-exp-09-fstar-m2.md),
[measurements](2026-11-25-exp-09-fstar-measure.md)) are not edited; this
entry corrects and completes them. The proof, the statement and the
measurements are unchanged; the only thing run is one untimed Verus
recheck (fix 2).

**Why.** The attempt figures feed the M4 comparison table, which must
compare like with like and recompute from the committed records.

## Fix 1: failing invocations beside failed checks

Rocq's 19 failed checks (entry 10) are all its failing invocations
(23 - 4 clean). F\*'s 7 (entry 13) leave out 6 failing invocations that
the session classified as reruns of an unchanged file to read a
truncated error; `invocations.tsv` has no content digest, so that
classification rests on the session record, not on the raw file. Entry
14's comparison table, completed:

| Figure | Unit | Rocq M2 (run 4) | F\* M2 (run 7) |
|---|---|---:|---:|
| failing invocations | a proof-file compile with a non-zero exit code (raw: `invocations.tsv` for F\*) | 19 | 13 |
| failed checks | a failing invocation that led to an edit | 19 | 7 (session record: 6 of the 13 were reruns of an unchanged file) |
| compile invocations of the proof files | one compile call of the edit loop | 23 | 21 |
| per-item attempts (`effort.tsv`) | a clean compile counts once per item it contains | 67 (48 lemmas) | 68 (43 lemmas, 17 proof functions, 1 definition) |

The comparable figure recomputable from raw files on both sides is
failing invocations (19 vs 13). The plan's M4 step now asks the table
to give both rows, and its effort-recording section asks each M2 run
from run 10 on to add the SHA-256 of the compiled source to every line
of `invocations.tsv`, so that reruns are identifiable from the raw file.

## Fix 2: raw record of the Verus statement recheck

Entry 13's "57 verified, 0 errors" for the Verus crate with decision 5's
statement (14:29:14Z) was printed to the session only; no file kept it.
That figure stays a session figure. To give it a raw record, the same
check was rerun untimed at 15:01:40Z-15:01:43Z on the bench host
(`nice -n 10 taskset -c 4-7 verus --crate-type=lib lib.rs`, Verus
0.2026.11.02.8bf68ee) from a copy of the run-7 check directory, whose
six source files have the same SHA-256 as the branch's
`verus/{lib,syntax,sem,compile,vm,statement}.rs`: "57 verified,
0 errors", exit code 0. Raw:
[verus/statement-recheck.txt](2026-11-25-exp-09-correction-6-raw/verus/statement-recheck.txt)
(digests and output). Run 10's checks re-establish it again with the
Verus proof.

## Fix 3: `effort.tsv` rows split by kind

The run-7 row `ProofA.code_at (definition), code_at_app, code_at_shift
| lemma | 2` gave one attempts figure for a definition and two lemmas.
It is split into `ProofA.code_at | definition | 2` and
`ProofA.code_at_app, code_at_shift | lemma | 1`, as entry 14 read it.
For the same reason, the row `ProofSem.ct_mono, ..., clen0_fm; fuel_of
(function) | lemma | 1` is split into the six lemmas (`lemma`, 1) and
`ProofSem.fuel_of | function | 1`. Figures unchanged. From
`effort.tsv` alone, run-7 rows, attempts times the number of items per
row: lemmas 43 items, 45 attempts; functions 17 items, 21 attempts;
definition 1 item (`code_at`), 2 attempts; 68 in all, as entry 14.

## Provenance

Branch `exp/09-representative-proof` at `1283360` plus this commit.
Files changed: `plans/09-representative-proof.md` (M4 step, effort
recording), `lab/09-representative-proof/effort.tsv` (two run-7 rows
split, rows `7-fix`). Bench host: the Verus recheck of fix 2 only,
untimed, CPUs 4-7, outside the timing complex.

## Effort

[effort.tsv](../09-representative-proof/effort.tsv), rows `7-fix`.
Human interventions: 0.

## Open

No decision pending.
