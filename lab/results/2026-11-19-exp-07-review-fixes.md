# Experiment #7, entry 7: corrections after the results review

**What.** Corrections to entries 2, 4, 5 and 6 required by the automated
results review on issue #11
([comment](https://github.com/tarides/maquizcoatl/issues/11#issuecomment-7012722290)),
plus the logs that the review found missing where they still existed on
the bench host. No new run: every number below is already in entries
1-6 or in their raw data. Entries 1-6 are left as recorded, except the
redaction noted at the end.

**Why.** The review confirmed the six done-criteria and every number,
but found that the Why3 verdict claims more than the data support, that
the comparability of `T_table` with experiment #6 depends on a load
condition that entry 6 lists only as an open question, and a few
reproducibility and path slips.

## Provenance

Text corrections only, on the data of entries 1-6 (commit `2072e9c`).
Logs added: [raw/timed/rocq/mem.1.log, mem.2.log, mem.3.log](2026-11-19-exp-07-raw/timed/rocq/),
copied unchanged from `<exp>/out/timed/rocq/` on the bench host.

## Corrections

### Entry 6 (verdicts): Why3 verdict narrowed

Entry 6 says that for anything stated over the table's contents, Why3's
table "behaves as unverified data whatever `T_spec` is". The data
support less: the sanity lemma was not proved *by computation* within a
25-minute attempt (entry 5; the plan's engineering budget is 2 hours),
through three transformations, and `why3 execute` costs about 2 minutes
and 14 GB per query (entry 3). Entry 5 itself names a structural route
(a lemma per array discharged by SMT, or ghost code) as follow-up.

Corrected verdict for Why3: **in-prover definition for extraction, if
`T_spec >= 24 s` (OCaml) or `>= 20 s` (C, decision trees); for anything
stated over the table's contents, provisional on `T_spec` and on the
structural-proof follow-up.** Until that follow-up is done, Why3's
in-prover table cannot be computed with or reasoned about in practice,
and its correctness rests on the generator check (entry 2).

### Entry 6 (verdicts): comparability with experiment #6

The plan allowed no timed run above a load average of 8; every timed
run of entries 3 and 4 ran at 42-45 (recorded per run in
`raw/timed/*/times.tsv`). Decision 1 compares `T_table` with `T_spec`
from experiment #6, so the comparison holds only if **experiment #6 is
timed under comparable load on the same host, or both experiments are
rerun on an idle host**. The verdicts of entry 6 are conditional on
this, not only on the value of `T_spec`.

### Entry 4 (extraction): what `T_table` excludes

`T_table` = check + extract + compile of the table. It excludes the
separate, untimed steps that compile or check the hand-written `Mem`
modules (membership function, name lookup, checker and its soundness
lemmas): Rocq `rocq compile Mem.v`, Lean `lean -R . Mem.lean` plus
`leanc` (and the `Main.lean` driver), F\* `fstar.exe ... Mem.fst`. They
are small next to the table but not zero. Why3 has no such step:
`why3 extract` reads `mem.mlw` without proving its goals.

### Entry 5 (sanity lemma): logs

- Rocq: `Mem.v`, where `ok_list_sound` and `table_ok_sound` are
  checked, is compiled in every timed run with its output in
  `mem.$RUN.log`. The three logs are now committed under
  `raw/timed/rocq/`. They are empty: `rocq compile` prints nothing on
  success, and `Extract.v`, which requires `Mem.vo`, then succeeded in
  each run. `rocq.sh` does not record that step's exit status.
- F\*: `raw/timed/fstar/mem.1.log` ("All verification conditions
  discharged successfully") was already committed; runs 2 and 3 have
  byte-identical logs on the bench host and are not added.
- Lean `Sound.lean` (0.45 s) and F\* `Sound.fst` (49.3 s): these
  exploratory runs printed to the terminal and **their output was not
  kept**. Only the sources remain on the bench host, byte-identical
  (sha256) to `lab/07-large-tables/lean/Sound.lean` and
  `fstar/Sound.fst`. The two times in entry 5 have no log or
  `times.tsv` row behind them.

### Entry 2 (fidelity): command path

The command is `lab/07-large-tables/fidelity.sh`, not `lab/fidelity.sh`.

### Plan

The plan named a `run.sh` for the timed runs; the branch has `timed.sh`
(three clean runs per tool, serialised by a lock) and `tm.sh` (the
timing helper). The plan is updated in place (it is not part of the
notebook).

## Follow-ups (no run in this entry)

- Settle the verdicts in a new entry when experiment #6 reports, with
  the load condition above stated.
- Why3: spend the remaining engineering budget (about 95 minutes) on
  the structural proof of the sanity lemma before the Why3 verdict is
  final.
- Why3 1.9.0 bugs worth reporting upstream, each to be reproduced on a
  tiny module first: `why3 execute` "Type mismatch between
  list.List.list (int, int) and (int, int)" on a list constant built
  from list constants (entry 3), and `-a compute` dying with
  `anomaly: File "src/core/trans.ml", line 503 ... Assertion failed`
  (entry 5). Not reported yet; the issue links go in a later entry.
- The 13 code points below U+0100 (`Cntrl`, `Print`, `Word`) where
  `onigenc_unicode_is_code_ctype` answers from the ISO-8859-1 table and
  disagrees with the `CR_*` tables (entry 2) stay an **open question**:
  the maintainer has not decided whether this is a deviation, so it is
  not in the deviation log.
- For experiments #13 and #5, which reuse `<cache>`: the F\* release's
  `fstar.lib` is built with OCaml 5.3.0, so anything beyond `Prims`
  needs a 5.3.0 switch or a source build of `fstar.lib` (entry 1).
- Optional: an idle-host rerun to bound the load effect; a binary
  search in place of the Pulse linear scan.

## Redaction

Entries 1 and 6, the notebook index and the plan named the bench host;
the name was replaced by "the bench host" and its directory layout by
`<bench-workdir>`. The scripts now read `<bench-workdir>` from
`BENCH_WORKDIR`. This is a redaction, not a change of results.
