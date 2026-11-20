# Experiment #7, verdicts settled against experiment #6's milestone 1 `T_spec`

**What.** The new notebook entry that experiment #6's criterion 5
requires: experiment #7's provisional verdicts (in-prover definition of
the Unicode property table if `T_table <= T_spec`) settled against
experiment #6's **milestone 1** `T_spec`, read as a lower bound on the
full spec's build time (Decision 5 of experiment #6's plan, option (c)
in the maintainer's
[comment](https://github.com/tarides/maquizcoatl/issues/1#issuecomment-7022660635)).
With it, experiment #7's tables rerun at idle, which answers its open
question on loaded versus idle figures.

**Why.** Experiment #7 (issue #11) could only give verdicts conditional
on `T_spec`, and its timings were taken at a load average of 42-45;
its review asked for `T_spec` and `T_table` under comparable load, or
both at idle. The bench host was idle for this run, so both are idle
here (plan step 10, preferred branch).

## Provenance

- `T_spec`: experiment #6, [entry 5](2026-11-20-exp-06-t-spec.md)
  (milestone 1: experiment #9's subset; load average 1.1-1.2 for the
  four provers below).
- `T_table` idle rerun: experiment #7's own per-tool scripts from `main`
  (`lab/07-large-tables/`, last changed at `2db5715`), copied to the
  bench host and run by experiment #6's `series.sh m1 e07` right after
  experiment #6's `T_spec`, same session, same lock and pinning
  (`taskset -c 28-31,60-63`), same tool versions and cache as experiment
  #7 ([entry 1](2026-11-20-exp-06-provenance.md)), on experiment #7's
  emitted tables and query sample (linked, not regenerated). Runs
  numbered 11-13 so that the scripts skip their query and sanity-lemma
  parts (which only run for `RUN=1`); outputs in a separate directory,
  experiment #7's own outputs untouched. Every extracted program
  answered the 85,772-query sample (and the 886 names for the OCaml
  targets) with 0 mismatches in every run.
- `T_table` as experiment #7 defined it (its entry 4): check + extract +
  compile per target; Lean: elaboration with C emission + `leanc` +
  link; Why3: type check + extraction + compile.
- Raw data: [2026-11-20-exp-06-raw/e07/](2026-11-20-exp-06-raw/e07/)
  (`times.tsv` and sample comparisons per tool), per-step medians in
  [summary.md](2026-11-20-exp-06-raw/summary.md).

## Idle rerun and settled verdicts


| Target | T_table loaded s (#7) | T_table idle s (runs 11-13) | Idle / loaded | Load (1 min) idle runs | T_spec s (milestone 1) | T_table idle / T_spec | Verdict |
|--------|------:|------:|------:|------|------:|------:|------|
| Rocq -> OCaml | 85.97 | 58.53 | 0.68 | 1.06-1.25 | 1.49 | 39 | open (#7's provisional verdict stands) |
| Lean -> C -> native | 95.38 | 60.88 | 0.64 | 1.11-1.50 | 1.12 | 54 | open (#7's provisional verdict stands) |
| Why3 -> OCaml | 24.45 | 15.46 | 0.63 | 1.13-2.94 | 0.47 | 33 | open (#7's provisional verdict stands) |
| Why3 -> C (decision trees) | 20.19 | 12.47 | 0.62 | 1.13-2.78 | 0.47 | 27 | open (#7's provisional verdict stands) |
| F* -> OCaml | 60.32 | 40.05 | 0.66 | 1.11-2.17 | 1.27 | 32 | open (#7's provisional verdict stands) |
| F* -> KaRaMeL C (decision trees) | 73.99 | 50.32 | 0.68 | 1.09-1.91 | 1.27 | 40 | open (#7's provisional verdict stands) |
| F* -> direct C (decision trees) | 65.49 | 44.71 | 0.68 | 1.09-1.91 | 1.27 | 35 | open (#7's provisional verdict stands) |
| F*/Pulse -> KaRaMeL C (static arrays) | 175.31 | 127.91 | 0.73 | 1.06-1.47 | 1.27 | 101 | open (#7's provisional verdict stands) |
| F*/Pulse -> direct C (static arrays) | 172.78 | 125.17 | 0.72 | 1.12-1.47 | 1.27 | 99 | open (#7's provisional verdict stands) |

Experiment #6's semantics have no C extraction (they use lists and
unbounded integers), so for experiment #7's C targets the comparison
basis is the same tool's spec check plus its OCaml target (plan step 9).

## Verdicts

- **Settled "in-prover" (for good): none.** No table builds in less
  than milestone 1's `T_spec`.
- **Open, experiment #7's provisional verdict stands:** all nine
  targets. A larger spec (milestone 2, or the full spec) settles a
  target "in-prover" once its `T_spec` reaches the idle `T_table` above,
  that is once the spec's build time grows by the factor in the
  "T_table idle / T_spec" column over milestone 1's: 27x (Why3 to C) to
  54x (Lean), and about 100x for F\*/Pulse's static arrays.
- `T_spec` here is milestone 1's, a 120-220 line fragment; the factors
  above are what the full semantics must add, not a prediction that it
  will not.

## Loaded versus idle (experiment #7's open question)

Idle `T_table` is 0.62-0.73 of the figure taken at load 42-45: the load
cost experiment #7 30-38% on every target, uniformly enough that its
ranking and its conclusions (Rocq's cost is mostly `ocamlopt` on the
extracted literals, Lean's half elaboration and half C compilation,
Pulse arrays the slowest to check) are unchanged. Comparisons with
`T_spec` should use the idle column.
