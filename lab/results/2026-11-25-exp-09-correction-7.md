# Experiment #9, entry 18: run-10 review fixes (correction 7)

**What.** Three decision-free fixes from the independent review of run 10
([issue #4 comment](https://github.com/tarides/maquizcoatl/issues/4#issuecomment-7167212731)),
all about the records behind the Verus M2 figures. Entries 16 and 17
([Verus M2](2026-11-25-exp-09-verus-m2.md),
[measurements](2026-11-25-exp-09-verus-measure.md)) are not edited; this
entry corrects and completes them. The proof, the statement and the
measurements are unchanged. The only thing run is one untimed
`axioms.sh verus` recheck with the amended script (fix 2), on the same
sources as run 10.

**Why.** The lemma table, the solver version and the invocation counts
feed the M4 comparison and run 14 (Verus M3, which varies the solver);
each figure must be a measurement read off a raw file.

## Fix 1: `lemmas.py` measures Verus admits

The Verus branch of `lemmas.py` printed `admitted 0` as a literal. It
now counts, per item, the `proof fn`s whose body calls `assume(` or
`admit(`, or whose attributes (the `#[...]` lines just above the item)
or head carry `external_body` or `verifier::external`. Such an item is
printed with kind `ADMITTED` and counted in the file and overall totals.
The docstring says this is a per-item count only, and that the
authoritative admit check for Verus is still `axioms.sh`'s
(`--no-cheating` and the source scan).

Check: on the run-10 proof files (`proof_a.rs proof_sem.rs proof_sim.rs
proof.rs`), the output is byte-identical to entry 16's `lemmas.txt`,
with `admitted 0` now measured. On a throwaway three-item file (one
`#[verifier::external_body]` item, one with `assume(false)` in its body,
one with an empty body), it prints `admitted 2` and `automatic 1`.

The F\* branch also prints `admitted 0` as a literal (its admit check is
`axioms.sh`'s `--admit_smt_queries false` check and scan). The review
did not raise it, so it is left unchanged here and listed under Open.

## Fix 2: raw record of the Z3 version Verus runs

Entry 16's "Z3 4.16.0" (and the notebook row's) rests on entry 1's
provenance, where the bundled Z3 was recorded; run 10's
`version.txt` is `verus --version` only, which does not name the solver.
That figure is entry 1's, not a run-10 measurement.

The verus cases of `axioms.sh` and `timed.sh`, and the `build` phase of
`verus/verus.sh`, now also run `z3 --version` on the solver Verus uses:
the `z3` binary bundled next to `verus` in the release directory, or
`$VERUS_Z3_PATH` when set (Verus's own lookup). `axioms.sh` prints it in
`axioms.txt`; `timed.sh` and `verus.sh` write it into `version.txt`. The
plan's M3 step now asks `brittle.sh` (not yet written; run 14) to record
it beside `verus --version` for each check.

Raw records, bench host, untimed:

- [verus/version.txt](2026-11-25-exp-09-correction-7-raw/verus/version.txt),
  15:41:38Z: `verus --version` (0.2026.11.02.8bf68ee, toolchain
  1.99.1), `z3 --version` of the bundled binary "Z3 version 4.16.0 -
  64 bit", its SHA-256 `e583c418…0b765`, `VERUS_Z3_PATH` unset.
- [verus/axioms.txt](2026-11-25-exp-09-correction-7-raw/verus/axioms.txt),
  15:42:34Z-15:42:45Z: the amended `axioms.sh verus` on the bench clone
  (`c260192` plus run 10's files and this commit's scripts), whose ten
  crate files concatenated in `lib.rs` order hash to `e70d8c41…`, the
  `sha256_all_sources` of run 10's last invocation and of the committed
  files: "Z3 version 4.16.0 - 64 bit (bundled with verus)", plain check
  and `--no-cheating` check both "135 verified, 0 errors", exit code 0,
  empty scan. Same result as entry 16's `axioms.txt`.

So run 10 ran Z3 4.16.0 (same binary, same environment script, no
`VERUS_Z3_PATH`), now with a raw record.

## Fix 3: out-of-loop invocations, one count

Entry 16 and the run-10 `effort.tsv` row said 4 `verus` invocations
outside the edit loop (three toy crates, one negative test).
`trigger-toy.txt` also records a first version of toy 2 rejected before
verification ("could not automatically infer triggers"). The count is
**5 invocations: 4 verified, 1 rejected at trigger inference**. The
`effort.tsv` row is corrected to 5 with that split and a note that it
was 4 before this correction.

The negative test's time ("15:25:xxZ" in `trigger-toy.txt`) was not
recorded, and its throwaway crate is not on the bench host. The bench
files bound it: after 15:25:17Z (the last edit-loop invocation's log,
`r10-dev/log.txt`) and before 15:26:50Z (`axioms.sh`'s start).

## Provenance

Branch `exp/09-representative-proof` at `3c96db9` plus this commit.
Files changed: `lab/09-representative-proof/lemmas.py` (fix 1),
`axioms.sh`, `timed.sh`, `verus/verus.sh` (fix 2),
`plans/09-representative-proof.md` (M3 step: `brittle.sh` records the
Z3 version), `effort.tsv` (fix 3, rows `10-fix`). Bench host: the
`version.txt` record and the `axioms.sh` recheck of fix 2 only, untimed,
CPUs 4-7 (outside the timing complex). `timed.sh`'s and `verus.sh`'s new
version line was checked with `bash -n` and not run: rerunning
them would duplicate run 10's deterministic results.

## Effort

[effort.tsv](../09-representative-proof/effort.tsv), rows `10-fix`.
Session: from no later than 15:41:15Z (first recorded timestamp) to
15:43:42Z (taken just before the commit). Human interventions: 0.

## Open

- Decision pending (the run's request, which the review supports):
  accept the trigger-only change to `verus/statement.rs`. If accepted,
  it becomes decision 6 in issue #4's body and in `FRAGMENT.md` 7.
- Follow-up, not fixed here: `lemmas.py`'s F\* branch also prints
  `admitted 0` as a literal.
