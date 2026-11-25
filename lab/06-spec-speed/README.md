# Experiment #6: executable spec speed (milestone 1)

Scripts and semantics for experiment #6 (issue #1, plan
`plans/06-spec-speed.md`). Results: `lab/results/2026-11-20-exp-06-*.md`
and `lab/results/2026-11-20-exp-07-verdicts-settled.md`.

- `cases/extract.py` extracts the 4,565 cases of the seven upstream
  suites; `cases/gen.py` writes the per-prover case modules (not
  committed) from the in-subset cases and the C oracle's verdicts.
- `g/g.ml` stack G: parser and subset classifier (narrowed from
  experiment #12's VM), the reference interpreter, timing driver;
  `g/g.sh` builds the C library, the oracle and stack G.
- `oracle/oracle.c` C reference (verdicts and throughput).
- `rocq/`, `lean/`, `why3/`, `fstar/`, `verus/`, `isabelle/`: the
  semantics (`Spec.*`, `spec.*`), the extraction or build files, the
  driver, and `<tool>.sh <phase> <run-id>` (phases `tspec`, `full`,
  `thr`, `inp`; see `common.sh`).
- `tm.sh` (from experiment #7), `series.sh` (the timed series, plus
  experiment #7's idle rerun with `e07`: its scripts are expected in
  `<bench-workdir>/exp/06-spec-speed/e07src`, a copy of
  `lab/07-large-tables` from `main`), `series2.sh` (Verus, Isabelle),
  `series3.sh` and `series4.sh` (reruns, see the throughput entry),
  `reps.env` (passes per run), `provenance.sh`, `summarise.py`.

On the bench host: `<bench-workdir>/exp/06-spec-speed/` holds a
read-only copy of `upstream/`, `in.tsv`, `gen/` (generated modules),
`src/` (this directory), `build/` and `out/`. Every script takes
`BENCH_WORKDIR` from the environment and prints no host-identifying
detail.

Upstream test cases quoted in the case files derive from Oniguruma:
Copyright (c) 2002-2025 K.Kosako, BSD-2-Clause (see `upstream/COPYING`).

## Milestone 2 (S2, issue #28, plan `plans/06-spec-speed-m2.md`)

Milestone 1's files are unchanged, so they keep reproducing milestone
1's figures; milestone 2 adds files next to them:

- `g/tables/gen_tables.py` emits the case-fold map and the property
  ranges from upstream's data files (`tables.txt`, not committed; size
  and sha256 in the notebook).
- `g/g2.ml` stack G on S2 (parser and S2 classifier for the Oniguruma,
  Perl_NG and Ruby syntaxes, interpreter, timing driver); `g/g2.sh`
  builds it with `oracle/oracle2.c` (the C oracle with the syntax and
  options columns) and runs `classify`, `full`, `gen` and `thr`.
- `cases/gen2.py` writes the Why3 and F* case modules and the table
  modules (restricted to the ctypes the cases use, or full, for the spot
  check); `cases/decode2.py` and `cases/agree2.py` compute criterion 2;
  `cases/deviations-s2.tsv` lists the cases where the spec follows a
  decided deviation (DEV-003, DEV-004).
- `why3/spec2.mlw`, `fstar/Spec2.fst`: the S2 semantics; `main2.ml`
  drivers; `why3_2.sh`, `fstar2.sh` (phases `tspec`, `full`, `thr`,
  `cal`, `inp`, `spot`).
- `series-m2-1a.sh` (C and stack G), `series-m2-1b.sh` (Why3, F*, spot
  check), `series-m2-1d.sh` (milestone 1's Isabelle and Lean folds rerun
  with more passes), `reps-m2.env`.

On the bench host, milestone 2 lives in `<bench-workdir>/exp/06-spec-speed/m2/`
(`src/`, `gen/`, `build/`, `out/<run-id>/`); the C library build of
milestone 1 is reused read only.
