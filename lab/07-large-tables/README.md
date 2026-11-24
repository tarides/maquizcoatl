# Experiment #7: large tables in the prover

Scripts and hand-written per-tool parts for experiment #7 (issue #11,
plan `plans/07-large-tables.md`). Generated table sources are not
committed; `emit.py` regenerates them from
`upstream/src/unicode_property_data.c` (sizes and sha256 are in the
notebook entries).

- `setup.sh` toolchains on the bench host (`<cache>` =
  `<bench-workdir>/cache`; every script reads `<bench-workdir>` from
  `BENCH_WORKDIR`), `pins.json` versions and checksums.
- `emit.py` parser and per-tool emitters; `fidelity.py`, `fidelity.sh`
  fidelity check against the generator on UCD 16.0.0; `oracle.c`,
  `latin1diff.c` C oracle; `sample.py` query sample and comparison.
- `tm.sh` timing helper (`/usr/bin/time -v`, `taskset`, limits),
  `timed.sh` three clean runs per tool, serialised across tools.
- `lean/`, `rocq/`, `why3/`, `fstar/`: membership function, name lookup,
  sanity checker, per-tool run script; `main_ml.ml` and
  `fstar/driver_c.c` drivers for the extracted OCaml and C code.
- `provenance.sh` CPU model, kernel and tool versions.

Code derived from Oniguruma (the generated tables) keeps its copyright:
Copyright (c) 2016-2024 K.Kosako, BSD-2-Clause.
