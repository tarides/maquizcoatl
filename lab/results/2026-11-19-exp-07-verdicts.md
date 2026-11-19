# Experiment #7, entry 6: provisional verdicts (criterion 6)

**What.** One verdict per tool: the Unicode property table as an
in-prover definition, or as unverified runtime data checked by the
generator or a separate check. Provisional, by Decision 1 (option b):
the table's check-plus-extraction cost must not exceed the build time of
the rest of the spec, `T_spec`, which experiment #6 (issue #1) will
measure.

**Why.** This is what experiment #7 decides (issue #11, "What it
decides", second bullet). The numbers below are those of entries 3-5;
when #6 reports, the verdicts are settled from them in a new entry,
without re-running unless the tool versions differ.

## Provenance

Entries 3, 4 and 5 (commit `2072e9c`, the bench host: AMD EPYC
7502P, Linux 6.8.0-100-generic; Rocq 9.3.0, Lean 4.36.0, Why3 1.9.0,
F\* 2026.11.15, OCaml 5.4.1, GCC 13.3.0), under a background load average
of about 42-45.

## Numbers the verdicts rest on

`T_table` = check + extraction + compilation of the table, median of
three runs (entry 4). Criteria: full table loaded (1), correct extracted
code (5), in-prover queries (3), sanity lemma (4).

| Tool | Target | T_table s | Peak RSS GB | Loads (1) | Sample (5) | Queries (3) | Lemma (4) |
|------|--------|----------:|------------:|-----------|------------|-------------|-----------|
| Rocq | OCaml | 86.0 | 5.0 | yes | 0 mismatches | < 0.02 s (vm) | proved, < 0.1 s |
| Lean | native (C) | 95.4 | 1.5 | yes | 0 mismatches | about 0.09 s | proved, 3.6 s (`decide +kernel`) |
| Why3 | OCaml | 24.5 | 0.7 | yes | 0 mismatches | about 2 min, 13.8 GB each | not proved (bounded attempt) |
| Why3 | C | 20.2 | 0.3 | yes (decision trees) | 0 mismatches | | |
| F\* | OCaml | 60.3 | 1.3 | yes | 0 mismatches | 1.3-2.3 s | proved, 6.0 s |
| F\* | KaRaMeL C, decision trees / Pulse arrays | 74.0 / 175.3 | 1.4 / 1.3 | yes | 0 mismatches | | |
| F\* | direct C, decision trees / Pulse arrays | 65.5 / 172.8 | 1.4 / 1.3 | yes | 0 mismatches | | |

## Provisional verdicts

The threshold is symbolic: **in-prover if T_table <= T_spec(#6)**, per tool
and per target.

- **Rocq:** in-prover definition, if `T_spec >= 86 s` (Rocq to OCaml).
  Loads, computes and proves the sanity lemma at negligible cost; the
  cost is mostly `ocamlopt` on the extracted literals (49 s, 5 GB).
- **Lean 4:** in-prover definition, if `T_spec >= 95 s` (native code via
  C). Loads, computes and proves the lemma (`decide +kernel`); cost is half
  elaboration, half C compilation of a 15 MB `Table.c`.
- **Why3:** in-prover definition for extraction, if `T_spec >= 24 s`
  (OCaml) or `>= 20 s` (C, decision trees). But Why3 cannot compute with
  the table (2 min and 14 GB per `execute`) or prove the sanity lemma by
  computation, so for anything stated over the table's contents the
  table behaves as unverified data whatever `T_spec` is; its correctness
  then rests on the generator check (entry 2) or a separate check.
- **F\*:** in-prover definition, if `T_spec >= 60 s` (OCaml), `>= 66-74 s`
  (C via decision trees) or `>= 173-175 s` (C via Pulse static arrays,
  the form that gives compact C close to upstream's). Loads, computes,
  and proves the lemma in seconds.

Whatever `T_spec` turns out to be, the generator check of entry 2
(upstream's generator on UCD 16.0.0 reproduces the 612 arrays and 886
names exactly) shows that the "unverified runtime data checked by the
generator" route is available too.

## Open questions

- `T_spec` from experiment #6.
- The timings were taken while experiment #3 loaded the host (load
  average about 42-45); an idle-host rerun would bound the effect.
- Why3: a structural (non-computational) proof of the lemma; Pulse: a
  binary search instead of the linear scan.
