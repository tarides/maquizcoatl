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
